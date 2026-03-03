"""
WebSocket Manager for Real-Time Communication
Handles:
- Booking requests broadcast to providers
- Fare negotiation between seeker and provider
- Live location sharing
- Booking status updates

Uses FastAPI's native WebSocket support - NO paid services
"""

from typing import Dict, List, Optional, Set, Any
from fastapi import WebSocket
from datetime import datetime
import json
import asyncio


class ConnectionManager:
    """
    Manages WebSocket connections for real-time features
    
    Connection Types:
    - User connections (by user_id)
    - Booking rooms (for active bookings - location sharing)
    - Service broadcast (for new booking requests)
    """
    
    def __init__(self):
        # Active connections by user_id
        self.active_connections: Dict[str, WebSocket] = {}
        
        # Booking rooms - users in an active booking can share location
        self.booking_rooms: Dict[str, Set[str]] = {}
        
        # Provider subscriptions by service category
        self.provider_subscriptions: Dict[str, Set[str]] = {}
        
        # All online providers (for broadcasting booking requests)
        self.online_providers: Set[str] = set()
    
    async def connect(self, websocket: WebSocket, user_id: str, user_role: str = "seeker"):
        """Accept and register a new WebSocket connection"""
        await websocket.accept()
        self.active_connections[user_id] = websocket
        
        if user_role == "provider":
            self.online_providers.add(user_id)
        
    
    def disconnect(self, user_id: str):
        """Remove a WebSocket connection"""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        
        # Remove from online providers
        self.online_providers.discard(user_id)
        
        # Remove from all booking rooms
        for room_users in self.booking_rooms.values():
            room_users.discard(user_id)
        
        # Remove from provider subscriptions
        for subscribers in self.provider_subscriptions.values():
            subscribers.discard(user_id)
    async def send_personal_message(self, user_id: str, message: Dict[str, Any]):
        """Send a message to a specific user"""
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_json(message)
                return True
            except Exception as e:
                self.disconnect(user_id)
        return False
    
    async def broadcast_to_providers(
        self, 
        message: Dict[str, Any], 
        category: Optional[str] = None,
        exclude_user: Optional[str] = None
    ):
        """
        Broadcast a message to all online providers
        Optionally filter by service category
        """
        target_providers = self.online_providers.copy()
        
        if category and category in self.provider_subscriptions:
            target_providers = target_providers.intersection(
                self.provider_subscriptions[category]
            )
        
        if exclude_user:
            target_providers.discard(exclude_user)
        
        disconnected = []
        for provider_id in target_providers:
            if provider_id in self.active_connections:
                try:
                    await self.active_connections[provider_id].send_json(message)
                except Exception as e:
                    disconnected.append(provider_id)
        
        # Cleanup disconnected
        for user_id in disconnected:
            self.disconnect(user_id)
    
    def join_booking_room(self, booking_id: str, user_id: str):
        """Add a user to a booking room for location sharing"""
        if booking_id not in self.booking_rooms:
            self.booking_rooms[booking_id] = set()
        self.booking_rooms[booking_id].add(user_id)
    def leave_booking_room(self, booking_id: str, user_id: str):
        """Remove a user from a booking room"""
        if booking_id in self.booking_rooms:
            self.booking_rooms[booking_id].discard(user_id)
            if not self.booking_rooms[booking_id]:
                del self.booking_rooms[booking_id]
    async def broadcast_to_booking_room(
        self, 
        booking_id: str, 
        message: Dict[str, Any],
        exclude_user: Optional[str] = None
    ):
        """Broadcast a message to all users in a booking room"""
        if booking_id not in self.booking_rooms:
            return
        
        disconnected = []
        for user_id in self.booking_rooms[booking_id]:
            if user_id != exclude_user and user_id in self.active_connections:
                try:
                    await self.active_connections[user_id].send_json(message)
                except Exception as e:
                    disconnected.append(user_id)
        
        for user_id in disconnected:
            self.disconnect(user_id)
    
    def subscribe_to_category(self, user_id: str, category: str):
        """Subscribe a provider to a service category"""
        if category not in self.provider_subscriptions:
            self.provider_subscriptions[category] = set()
        self.provider_subscriptions[category].add(user_id)
    
    def unsubscribe_from_category(self, user_id: str, category: str):
        """Unsubscribe a provider from a service category"""
        if category in self.provider_subscriptions:
            self.provider_subscriptions[category].discard(user_id)
    
    def is_online(self, user_id: str) -> bool:
        """Check if a user is currently connected"""
        return user_id in self.active_connections
    
    def get_online_providers_count(self) -> int:
        """Get count of online providers"""
        return len(self.online_providers)
    
    def get_booking_room_users(self, booking_id: str) -> Set[str]:
        """Get all users in a booking room"""
        return self.booking_rooms.get(booking_id, set())


# Singleton instance
manager = ConnectionManager()


# Message type definitions for WebSocket communication
class WSMessageType:
    """WebSocket message types for structured communication"""
    
    # Booking lifecycle
    NEW_BOOKING_REQUEST = "new_booking_request"
    BOOKING_STATUS_UPDATE = "booking_status_update"
    BOOKING_CANCELLED = "booking_cancelled"
    
    # Fare negotiation
    NEW_FARE_OFFER = "new_fare_offer"
    FARE_OFFER_ACCEPTED = "fare_offer_accepted"
    FARE_OFFER_REJECTED = "fare_offer_rejected"
    COUNTER_OFFER = "counter_offer"
    OFFER_UPDATED = "offer_updated"
    OFFER_WITHDRAWN = "offer_withdrawn"
    
    # Location tracking
    LOCATION_UPDATE = "location_update"
    REQUEST_LOCATION = "request_location"
    
    # Provider status
    PROVIDER_ONLINE = "provider_online"
    PROVIDER_OFFLINE = "provider_offline"
    PROVIDER_BUSY = "provider_busy"
    
    # Booking progress
    PROVIDER_ARRIVING = "provider_arriving"
    PROVIDER_ARRIVED = "provider_arrived"
    BOOKING_STARTED = "booking_started"
    BOOKING_COMPLETED = "booking_completed"
    
    # System
    PING = "ping"
    PONG = "pong"
    ERROR = "error"
    ACK = "ack"


def create_ws_message(
    message_type: str,
    data: Dict[str, Any],
    booking_id: Optional[str] = None,
    sender_id: Optional[str] = None
) -> Dict[str, Any]:
    """Create a standardized WebSocket message"""
    return {
        "type": message_type,
        "data": data,
        "bookingId": booking_id,
        "senderId": sender_id,
        "timestamp": datetime.now().isoformat()
    }

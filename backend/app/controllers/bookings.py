"""
Booking REST API Controller - Complete Booking Lifecycle
Handles: Request → Negotiation → Confirmation → Tracking → Completion

Booking Status Flow:
1. pending - Seeker creates booking request
2. bidding - Providers are making fare offers
3. accepted - Seeker accepted a fare offer
4. provider_arriving - Provider is on the way
5. provider_arrived - Provider reached pickup location
6. in_progress - Service has started
7. completed - Service completed successfully
8. cancelled - Booking was cancelled
"""

from fastapi import APIRouter, HTTPException, status, Query
from typing import Optional, List
from pydantic import BaseModel, Field
from ..schemas.booking_schema import BookingCreate, BookingUpdate, BookingResponse
from ..models.booking import Booking
from ..models.location import LocationUpdate
from ..services.websocket_manager import manager, WSMessageType, create_ws_message

router = APIRouter()


# Additional schemas for this controller
class BookingsListResponse(BaseModel):
    success: bool
    message: str
    bookings: List[dict] = []
    total: int = 0


class RatingRequest(BaseModel):
    rating: float = Field(..., ge=1, le=5, description="Rating from 1-5")
    review: Optional[str] = Field(None, description="Optional review text")


# ============================================
# SEEKER ENDPOINTS
# ============================================

@router.post("", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(booking: BookingCreate):
    """
    SEEKER: Create a new booking request
    This broadcasts to online providers who can make fare offers
    """
    try:
        booking_data = Booking.create(booking.dict())
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create booking"
            )
        
        # Broadcast new booking to all online providers
        await manager.broadcast_to_providers(
            create_ws_message(
                WSMessageType.NEW_BOOKING_REQUEST,
                {
                    'booking': booking_data,
                    'serviceType': booking.serviceType,
                    'pickupAddress': booking.pickupAddress,
                    'dropAddress': booking.dropAddress,
                    'estimatedPrice': booking.estimatedPrice,
                    'distanceInKm': booking.distanceInKm,
                },
                booking_id=booking_data['id'],
                sender_id=booking.seekerId
            ),
            category=booking.serviceType
        )
        
        return BookingResponse(
            success=True,
            message="Booking created successfully. Waiting for provider offers.",
            booking=booking_data
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create booking: {str(e)}"
        )


@router.get("/seeker/{seeker_id}", response_model=BookingsListResponse)
async def get_seeker_bookings(
    seeker_id: str,
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status")
):
    """SEEKER: Get all bookings for a seeker"""
    try:
        bookings = Booking.get_by_seeker(seeker_id, status_filter)
        
        return BookingsListResponse(
            success=True,
            message="Bookings retrieved successfully",
            bookings=bookings,
            total=len(bookings)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch bookings: {str(e)}"
        )


@router.get("/seeker/{seeker_id}/active", response_model=BookingResponse)
async def get_seeker_active_booking(seeker_id: str):
    """SEEKER: Get current active booking (if any)"""
    try:
        booking = Booking.get_active_booking(seeker_id, "seeker")
        
        return BookingResponse(
            success=True,
            message="Active booking retrieved" if booking else "No active booking",
            booking=booking
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch active booking: {str(e)}"
        )


# ============================================
# PROVIDER ENDPOINTS
# ============================================

@router.get("/provider/{provider_id}", response_model=BookingsListResponse)
async def get_provider_bookings(
    provider_id: str,
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status")
):
    """PROVIDER: Get all bookings assigned to a provider"""
    try:
        bookings = Booking.get_by_provider(provider_id, status_filter)
        
        return BookingsListResponse(
            success=True,
            message="Bookings retrieved successfully",
            bookings=bookings,
            total=len(bookings)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch bookings: {str(e)}"
        )


@router.get("/provider/{provider_id}/active", response_model=BookingResponse)
async def get_provider_active_booking(provider_id: str):
    """PROVIDER: Get current active booking (if any)"""
    try:
        booking = Booking.get_active_booking(provider_id, "provider")
        
        return BookingResponse(
            success=True,
            message="Active booking retrieved" if booking else "No active booking",
            booking=booking
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch active booking: {str(e)}"
        )


@router.get("/available", response_model=BookingsListResponse)
async def get_available_bookings(
    service_type: Optional[str] = Query(None, description="Filter by service type"),
    latitude: Optional[float] = Query(None, description="Provider's current latitude"),
    longitude: Optional[float] = Query(None, description="Provider's current longitude"),
    radius_km: float = Query(50.0, description="Search radius in kilometers")
):
    """PROVIDER: Get available booking requests to bid on"""
    try:
        bookings = Booking.get_available_bookings(
            service_type=service_type,
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km
        )
        
        return BookingsListResponse(
            success=True,
            message="Available bookings retrieved successfully",
            bookings=bookings,
            total=len(bookings)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch available bookings: {str(e)}"
        )


# ============================================
# BOOKING LIFECYCLE ENDPOINTS
# ============================================

@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(booking_id: str):
    """Get booking details by ID"""
    try:
        booking = Booking.get_by_id(booking_id)
        
        if not booking:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        return BookingResponse(
            success=True,
            message="Booking retrieved successfully",
            booking=booking
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch booking: {str(e)}"
        )


@router.put("/{booking_id}", response_model=BookingResponse)
async def update_booking(booking_id: str, booking_update: BookingUpdate):
    """Update booking details"""
    try:
        update_data = {k: v for k, v in booking_update.dict().items() if v is not None}
        booking_data = Booking.update(booking_id, update_data)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        return BookingResponse(
            success=True,
            message="Booking updated successfully",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update booking: {str(e)}"
        )


@router.put("/{booking_id}/arriving", response_model=BookingResponse)
async def provider_arriving(booking_id: str):
    """PROVIDER: Mark that provider is on the way to pickup"""
    try:
        booking_data = Booking.update_status(booking_id, "provider_arriving")
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        # Notify seeker
        await manager.send_personal_message(
            booking_data['seekerId'],
            create_ws_message(
                WSMessageType.PROVIDER_ARRIVING,
                booking_data,
                booking_id=booking_id
            )
        )
        
        # Join booking room for location sharing
        manager.join_booking_room(booking_id, booking_data['providerId'])
        
        return BookingResponse(
            success=True,
            message="Provider is arriving - seeker notified",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update booking: {str(e)}"
        )


@router.put("/{booking_id}/arrived", response_model=BookingResponse)
async def provider_arrived(booking_id: str):
    """PROVIDER: Mark that provider has arrived at pickup location"""
    try:
        booking_data = Booking.update_status(booking_id, "provider_arrived")
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        # Notify seeker
        await manager.send_personal_message(
            booking_data['seekerId'],
            create_ws_message(
                WSMessageType.PROVIDER_ARRIVED,
                booking_data,
                booking_id=booking_id
            )
        )
        
        return BookingResponse(
            success=True,
            message="Provider has arrived - seeker notified",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update booking: {str(e)}"
        )


@router.put("/{booking_id}/start", response_model=BookingResponse)
async def start_booking(booking_id: str):
    """PROVIDER: Start the service"""
    try:
        booking_data = Booking.start(booking_id)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        # Notify seeker and add to booking room
        await manager.send_personal_message(
            booking_data['seekerId'],
            create_ws_message(
                WSMessageType.BOOKING_STARTED,
                booking_data,
                booking_id=booking_id
            )
        )
        
        # Add seeker to booking room for location tracking
        manager.join_booking_room(booking_id, booking_data['seekerId'])
        
        return BookingResponse(
            success=True,
            message="Booking started - service in progress",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to start booking: {str(e)}"
        )


@router.put("/{booking_id}/complete", response_model=BookingResponse)
async def complete_booking(booking_id: str, final_price: Optional[float] = None):
    """PROVIDER: Complete the booking"""
    try:
        booking_data = Booking.complete(booking_id, final_price)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        # Notify seeker
        await manager.send_personal_message(
            booking_data['seekerId'],
            create_ws_message(
                WSMessageType.BOOKING_COMPLETED,
                booking_data,
                booking_id=booking_id
            )
        )
        
        # Clean up booking room and locations
        manager.leave_booking_room(booking_id, booking_data['seekerId'])
        manager.leave_booking_room(booking_id, booking_data['providerId'])
        LocationUpdate.delete_booking_locations(booking_id)
        
        return BookingResponse(
            success=True,
            message="Booking completed successfully",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to complete booking: {str(e)}"
        )


@router.put("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(booking_id: str, reason: Optional[str] = None, cancelled_by: Optional[str] = None):
    """Cancel a booking (can be called by seeker or provider)"""
    try:
        # Get booking first to know who to notify
        existing = Booking.get_by_id(booking_id)
        
        booking_data = Booking.cancel(booking_id, reason)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        # Notify the other party
        if existing:
            target_user = existing['seekerId'] if cancelled_by == existing.get('providerId') else existing.get('providerId')
            if target_user:
                await manager.send_personal_message(
                    target_user,
                    create_ws_message(
                        WSMessageType.BOOKING_CANCELLED,
                        {
                            'bookingId': booking_id,
                            'reason': reason,
                            'cancelledBy': cancelled_by
                        },
                        booking_id=booking_id
                    )
                )
        
        # Clean up
        if existing:
            manager.leave_booking_room(booking_id, existing.get('seekerId', ''))
            if existing.get('providerId'):
                manager.leave_booking_room(booking_id, existing['providerId'])
        LocationUpdate.delete_booking_locations(booking_id)
        
        return BookingResponse(
            success=True,
            message="Booking cancelled successfully",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to cancel booking: {str(e)}"
        )


@router.put("/{booking_id}/rate", response_model=BookingResponse)
async def rate_booking(booking_id: str, rating_req: RatingRequest):
    """SEEKER: Rate a completed booking"""
    try:
        booking_data = Booking.add_rating(booking_id, rating_req.rating, rating_req.review)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        return BookingResponse(
            success=True,
            message="Rating submitted successfully",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to submit rating: {str(e)}"
        )


# ============================================
# LEGACY ENDPOINTS (for backward compatibility)
# ============================================

@router.put("/{booking_id}/accept", response_model=BookingResponse)
async def accept_booking(booking_id: str, provider_id: str, vehicle_id: Optional[str] = None):
    """
    DEPRECATED: Use fare offers instead
    Provider directly accepts a booking (legacy flow)
    """
    try:
        booking_data = Booking.accept(booking_id, provider_id, vehicle_id)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        # Notify seeker
        await manager.send_personal_message(
            booking_data['seekerId'],
            create_ws_message(
                WSMessageType.BOOKING_STATUS_UPDATE,
                booking_data,
                booking_id=booking_id
            )
        )
        
        return BookingResponse(
            success=True,
            message="Booking accepted successfully",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to accept booking: {str(e)}"
        )


@router.put("/{booking_id}/reject", response_model=BookingResponse)
async def reject_booking(booking_id: str, provider_id: str, reason: Optional[str] = None):
    """Provider rejects a booking"""
    try:
        booking_data = Booking.reject(booking_id, provider_id, reason)
        
        if not booking_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )
        
        return BookingResponse(
            success=True,
            message="Booking rejected successfully",
            booking=booking_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to reject booking: {str(e)}"
        )

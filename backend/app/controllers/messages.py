"""
Messages Controller
Handles text messaging endpoints with Agora RTM integration
"""
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import Optional, List
import os
from ..models.message import Message

router = APIRouter(prefix="/messages", tags=["messages"])

# Agora RTM credentials (should be in environment variables)
AGORA_APP_ID = os.getenv("AGORA_APP_ID", "your_agora_app_id")


# Request Models
class SendMessageRequest(BaseModel):
    senderId: str
    receiverId: str
    bookingId: str
    messageText: str
    messageType: str = 'text'  # 'text', 'image', 'location'


class MarkAsReadRequest(BaseModel):
    messageId: Optional[str] = None
    receiverId: Optional[str] = None
    bookingId: Optional[str] = None


# Response Models
class MessageResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None


class MessagesListResponse(BaseModel):
    success: bool
    messages: List[dict]
    unreadCount: Optional[int] = None


class AgoraConfigResponse(BaseModel):
    success: bool
    agoraConfig: dict


@router.get("/agora-config")
async def get_agora_config():
    """Get Agora RTM configuration"""
    return AgoraConfigResponse(
        success=True,
        agoraConfig={
            "appId": AGORA_APP_ID,
        }
    )


@router.post("/send", response_model=MessageResponse)
async def send_message(request: SendMessageRequest):
    """Send a message"""
    try:
        if request.senderId == request.receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sender and receiver must be different users"
            )

        if not request.messageText.strip() and request.messageType == 'text':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Message text cannot be empty"
            )

        message_data = Message.create_message(
            sender_id=request.senderId,
            receiver_id=request.receiverId,
            booking_id=request.bookingId,
            message_text=request.messageText,
            message_type=request.messageType
        )
        
        if not message_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Failed to create message"
            )
        
        return MessageResponse(
            success=True,
            message="Message sent successfully",
            data=message_data
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send message: {str(e)}"
        )


@router.get("/booking/{booking_id}", response_model=MessagesListResponse)
async def get_messages_for_booking(booking_id: str, limit: int = 100):
    """Get all messages for a booking"""
    try:
        messages = Message.get_messages_for_booking(booking_id, limit)
        
        return MessagesListResponse(
            success=True,
            messages=messages
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch messages: {str(e)}"
        )


@router.get("/conversation/{user1_id}/{user2_id}/{booking_id}", response_model=MessagesListResponse)
async def get_conversation_messages(
    user1_id: str,
    user2_id: str,
    booking_id: str,
    limit: int = 100
):
    """Get conversation between two users for a specific booking"""
    try:
        messages = Message.get_conversation_messages(user1_id, user2_id, booking_id, limit)
        
        return MessagesListResponse(
            success=True,
            messages=messages
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch conversation: {str(e)}"
        )


@router.post("/mark-read", response_model=MessageResponse)
async def mark_message_as_read(request: MarkAsReadRequest):
    """Mark message(s) as read"""
    try:
        if request.messageId:
            # Mark a specific message as read
            success = Message.mark_as_read(request.messageId)
            
            if not success:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Message not found"
                )
            
            return MessageResponse(
                success=True,
                message="Message marked as read"
            )
        
        elif request.receiverId and request.bookingId:
            # Mark all messages for a receiver in a booking as read
            success = Message.mark_all_as_read(request.receiverId, request.bookingId)
            
            if not success:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="No messages found"
                )
            
            return MessageResponse(
                success=True,
                message="All messages marked as read"
            )
        
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Either messageId or (receiverId and bookingId) must be provided"
            )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to mark message as read: {str(e)}"
        )


@router.get("/unread/{user_id}", response_model=MessageResponse)
async def get_unread_count(user_id: str, booking_id: Optional[str] = None):
    """Get unread message count for a user"""
    try:
        count = Message.get_unread_count(user_id, booking_id)
        
        return MessageResponse(
            success=True,
            message="Unread count retrieved successfully",
            data={"unreadCount": count}
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch unread count: {str(e)}"
        )

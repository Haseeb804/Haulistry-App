"""
Messages Controller
Handles text messaging endpoints with Agora RTM integration
"""
from fastapi import APIRouter, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, List
import os
import time
from firebase_admin import storage
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


def _safe_filename(name: Optional[str], fallback: str) -> str:
    if not name:
        return fallback
    cleaned = os.path.basename(name).replace(' ', '_')
    return cleaned or fallback


def _detect_image_type(content: bytes) -> str:
    """Detect image type from file bytes (magic numbers)"""
    if content.startswith(b'\x89PNG'):
        return 'image/png'
    elif content.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    elif content.startswith(b'RIFF') and content[8:12] == b'WEBP':
        return 'image/webp'
    elif content.startswith(b'GIF8'):
        return 'image/gif'
    return 'image/jpeg'  # Default to JPEG


async def _upload_to_storage(
    file: UploadFile,
    folder: str,
    default_content_type: str,
) -> str:
    bucket = storage.bucket()
    safe_name = _safe_filename(file.filename, f"{folder}_file")
    filename = f"{folder}/{int(time.time() * 1000)}_{safe_name}"

    content = await file.read()
    blob = bucket.blob(filename)
    
    # Detect actual content type from file content if not provided
    content_type = file.content_type or default_content_type
    if default_content_type.startswith('image/') and not file.content_type:
        # For images, try to detect actual format from bytes
        content_type = _detect_image_type(content)
    elif default_content_type.startswith('audio/'):
        # For audio, be flexible with content type
        if not file.content_type or 'audio' not in file.content_type:
            content_type = default_content_type
    
    blob.upload_from_string(content, content_type=content_type)
    blob.make_public()
    return blob.public_url


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


@router.post("/upload-image", response_model=MessageResponse)
async def upload_image_message(
    image: UploadFile = File(...),
    senderId: str = Form(...),
    receiverId: str = Form(...),
    bookingId: str = Form(...),
):
    """Upload chat image to Firebase Storage and save as messageType=image."""
    try:
        if senderId == receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sender and receiver must be different users"
            )

        # Read file content for validation
        content = await image.read()
        
        # Validate it looks like an image (check magic numbers)
        is_valid_image = (
            content.startswith(b'\x89PNG') or  # PNG
            content.startswith(b'\xff\xd8\xff') or  # JPEG
            content.startswith(b'RIFF') and len(content) > 8 and content[8:12] == b'WEBP' or  # WebP
            content.startswith(b'GIF8') or  # GIF
            content.startswith(b'BM')  # BMP
        )
        
        # Also check MIME type if provided
        mime_type = (image.content_type or '').lower()
        is_valid_mime = (
            mime_type.startswith('image/') or
            mime_type == 'application/octet-stream'  # Browser often sends this for unknown types
        )
        
        if not is_valid_image and not is_valid_mime:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid image file"
            )

        image_url = await _upload_to_storage(
            file=image,
            folder=f"chat_images/{bookingId}",
            default_content_type='image/jpeg',
        )

        message_data = Message.create_message(
            sender_id=senderId,
            receiver_id=receiverId,
            booking_id=bookingId,
            message_text=image_url,
            message_type='image',
        )

        if not message_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Failed to create image message"
            )

        return MessageResponse(
            success=True,
            message="Image uploaded and sent successfully",
            data=message_data,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload image message: {str(e)}"
        )


@router.post("/upload-voice", response_model=MessageResponse)
async def upload_voice_message(
    audio: UploadFile = File(...),
    senderId: str = Form(...),
    receiverId: str = Form(...),
    bookingId: str = Form(...),
    duration: int = Form(...),
):
    """Upload chat voice note and save as messageType=voice."""
    try:
        if senderId == receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sender and receiver must be different users"
            )

        if duration <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Voice duration must be greater than zero"
            )
        
        if duration > 600:  # Max 10 minutes
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Voice message too long (max 10 minutes)"
            )

        # Read file content for validation
        content = await audio.read()
        
        # Validate file size (max 10MB for voice)
        if len(content) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Voice file too large (max 10MB)"
            )
        
        # Check MIME type or file content
        mime_type = (audio.content_type or '').lower()
        
        # More flexible audio validation - check for common audio formats
        is_valid_audio = (
            mime_type.startswith('audio/') or  # Any audio MIME type
            mime_type == 'application/octet-stream' or  # Browser fallback
            # Check magic bytes for common audio formats
            content.startswith(b'ID3') or  # MP3
            content.startswith(b'\xff\xfb') or  # MP3 without ID3
            content.startswith(b'\xff\xfa') or  # MP3
            content.startswith(b'\xff\xf3') or  # MP3
            content.startswith(b'\x23\x21\x41\x75') or  # Ogg Vorbis
            content.startswith(b'RIFF') and len(content) > 8 and content[8:12] == b'WAVE' or  # WAV
            content.startswith(b'ftyp') or  # M4A/AAC
            content.startswith(b'\x00\x00\x00\x20\x66\x74\x79\x70')  # M4A/AAC
        )
        
        if not is_valid_audio:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid audio file"
            )

        audio_url = await _upload_to_storage(
            file=audio,
            folder=f"voice_messages/{bookingId}",
            default_content_type='audio/m4a',
        )

        message_data = Message.create_message(
            sender_id=senderId,
            receiver_id=receiverId,
            booking_id=bookingId,
            message_text=audio_url,
            message_type='voice',
            media_duration=duration,
        )

        if not message_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Failed to create voice message"
            )

        return MessageResponse(
            success=True,
            message="Voice message uploaded and sent successfully",
            data=message_data,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload voice message: {str(e)}"
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

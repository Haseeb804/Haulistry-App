"""
Call Controller
Handles voice/video calling endpoints with Agora integration
"""
from fastapi import APIRouter, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, List
import os
import time
import uuid
import hashlib
from ..models.call import Call
from ..models.voice_message import VoiceMessage
from firebase_admin import storage, messaging
from ..constants import LIVE_COMMUNICATION_STATUSES

router = APIRouter(prefix="/calls", tags=["calls"])


# Agora credentials (should be in environment variables)
AGORA_APP_ID = os.getenv("AGORA_APP_ID", "your_agora_app_id")
AGORA_APP_CERTIFICATE = os.getenv("AGORA_APP_CERTIFICATE", "")


# Request Models
class InitiateCallRequest(BaseModel):
    callerId: str
    receiverId: str
    bookingId: str
    callType: str  # 'voice' or 'video'
    callerName: Optional[str] = None  # Caller's display name
    callerRole: Optional[str] = None  # Caller's role ('seeker' or 'provider')
ACTIVE_COMMUNICATION_STATUSES = LIVE_COMMUNICATION_STATUSES


class UpdateCallStatusRequest(BaseModel):
    callId: str
    status: str  # 'answered', 'ended', 'missed', 'rejected'
    duration: Optional[int] = None


class VoiceMessageRequest(BaseModel):
    senderId: str
    receiverId: str
    bookingId: str
    duration: int


# Response Models
class CallResponse(BaseModel):
    success: bool
    message: str
    call: Optional[dict] = None
    agoraConfig: Optional[dict] = None


class VoiceMessageResponse(BaseModel):
    success: bool
    message: str
    voiceMessage: Optional[dict] = None


class CallHistoryResponse(BaseModel):
    success: bool
    calls: List[dict]


def generate_agora_token(channel_name: str, uid: int, role: int = 1) -> Optional[str]:
    """
    Generate Agora RTC token
    role: 1 = publisher (can send/receive), 2 = subscriber (receive only)
    
    Note: For production, implement proper token generation with Agora AccessToken library
    For now, if no certificate is configured, Agora can work in testing mode without tokens
    """
    if not AGORA_APP_CERTIFICATE:
        return None  # Testing mode, no token needed
    
    # TODO: Implement actual Agora token generation
    # from agora_token_builder import RtcTokenBuilder
    # privilege_expired_ts = int(time.time()) + 3600  # 1 hour
    # return RtcTokenBuilder.buildTokenWithUid(
    #     AGORA_APP_ID, AGORA_APP_CERTIFICATE, 
    #     channel_name, uid, role, privilege_expired_ts
    # )
    
    return None


async def send_call_notification(
    fcm_token: str,
    call_id: str,
    caller_id: str,
    caller_name: str,
    caller_role: str,
    call_type: str,
    agora_config: dict
):
    """Send FCM notification for incoming call"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title='📞 Incoming Call' if call_type == 'voice' else '📹 Video Call',
                body=f'Incoming {call_type} call from {caller_name}',
            ),
            data={
                'type': 'call',
                'callId': call_id,
                'callerId': caller_id,
                'callerName': caller_name,
                'callerRole': caller_role,
                'callType': call_type,
                'agoraAppId': agora_config['appId'],
                'agoraChannel': agora_config['channel'],
                'agoraToken': agora_config['token'] or '',
                'agoraUid': str(agora_config['uid']),
            },
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='call_channel',
                    priority='max',
                    sound='call_ringtone',
                    tag=call_id,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='call_ringtone.caf',
                        badge=1,
                        category='CALL',
                        thread_id=call_id,
                    )
                )
            ),
            token=fcm_token,
        )
        
        messaging.send(message)
        return True
    except Exception:
        return False


@router.post("/initiate", response_model=CallResponse)
async def initiate_call(request: InitiateCallRequest):
    """Initiate a new call"""
    try:
        from ..models.user import User
        
        # Generate unique channel name using UUID (much better than timestamp-based)
        # Format: call_booking_uuid
        channel_name = f"call_{request.bookingId}_{uuid.uuid4().hex[:8]}"
        
        # Generate UIDs from hashing user IDs instead of timestamp
        # This ensures consistent UIDs for same users
        caller_uid = int(hashlib.md5(request.callerId.encode()).hexdigest()[:8], 16) % 100000
        receiver_uid = int(hashlib.md5(request.receiverId.encode()).hexdigest()[:8], 16) % 100000
        
        # Ensure UIDs are different to avoid collisions
        while receiver_uid == caller_uid:
            receiver_uid = (receiver_uid + 1) % 100000
        
        # Generate Agora token (optional for testing)
        agora_token = generate_agora_token(channel_name, caller_uid)
        
        # Fetch caller and receiver details including phone numbers
        caller_data = User.get_by_id(request.callerId)
        receiver_data = User.get_by_id(request.receiverId)
        
        if not caller_data or not receiver_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Caller or receiver not found"
            )

        if request.callerId == request.receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Caller and receiver must be different users"
            )
        
        # Create call record
        call_data = Call.create_call(
            caller_id=request.callerId,
            receiver_id=request.receiverId,
            booking_id=request.bookingId,
            call_type=request.callType,
            agora_channel=channel_name,
            agora_token=agora_token
        )
        
        if not call_data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Call not allowed. Communication requires an active service between booking participants."
            )
        
        # Add phone numbers and roles to call data
        call_data['callerPhone'] = caller_data.get('phone')
        call_data['receiverPhone'] = receiver_data.get('phone')
        call_data['callerRole'] = call_data.get('callerRole') or caller_data.get('role', 'user')
        call_data['receiverRole'] = call_data.get('receiverRole') or receiver_data.get('role', 'user')
        
        # Prepare Agora config with caller UID
        agora_config = {
            "appId": AGORA_APP_ID,
            "channel": channel_name,
            "token": agora_token,
            "uid": caller_uid  # Use caller UID from hash
        }
        
        # Send FCM notification to receiver if token provided
        # Send FCM notification to the intended receiver using server-side token lookup
        receiver_fcm_token = receiver_data.get('fcmToken')
        if receiver_fcm_token:
            caller_role = request.callerRole or caller_data.get('role', 'user')
            await send_call_notification(
                fcm_token=receiver_fcm_token,
                call_id=call_data['id'],
                caller_id=request.callerId,
                caller_name=request.callerName or caller_data.get('name', 'User'),
                caller_role=caller_role,
                call_type=request.callType,
                agora_config=agora_config
            )
        
        # Return call data with Agora config
        return CallResponse(
            success=True,
            message="Call initiated successfully",
            call=call_data,
            agoraConfig=agora_config
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to initiate call: {str(e)}"
        )


@router.post("/update-status", response_model=CallResponse)
async def update_call_status(request: UpdateCallStatusRequest):
    """Update call status"""
    try:
        success = Call.update_call_status(
            call_id=request.callId,
            status=request.status,
            duration=request.duration
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call not found"
            )
        
        return CallResponse(
            success=True,
            message=f"Call status updated to {request.status}"
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update call status: {str(e)}"
        )


@router.get("/history/{user_id}", response_model=CallHistoryResponse)
async def get_call_history(user_id: str, limit: int = 20):
    """Get call history for a user"""
    try:
        calls = Call.get_call_history(user_id, limit)
        
        return CallHistoryResponse(
            success=True,
            calls=calls
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch call history: {str(e)}"
        )


@router.get("/{call_id}", response_model=CallResponse)
async def get_call(call_id: str):
    """Get call details by ID"""
    try:
        call = Call.get_call_by_id(call_id)
        
        if not call:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call not found"
            )
        
        return CallResponse(
            success=True,
            message="Call retrieved successfully",
            call=call
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch call: {str(e)}"
        )


@router.post("/voice-message/upload", response_model=VoiceMessageResponse)
async def upload_voice_message(
    audio: UploadFile = File(...),
    senderId: str = Form(...),
    receiverId: str = Form(...),
    bookingId: str = Form(...),
    duration: int = Form(...)
):
    """Upload a voice message"""
    try:
        from ..models.booking import Booking

        if senderId == receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sender and receiver must be different users"
            )

        booking = Booking.get_by_id(bookingId)
        if not booking:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found"
            )

        status_value = str(booking.get('status') or '').lower()
        if status_value not in ACTIVE_COMMUNICATION_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Voice messaging is only available during active service"
            )

        seeker_id = booking.get('seekerId')
        provider_id = booking.get('providerId')
        participants_match = (
            (senderId == seeker_id and receiverId == provider_id) or
            (senderId == provider_id and receiverId == seeker_id)
        )
        if not participants_match:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Users are not valid participants for this booking"
            )

        # Generate unique filename
        timestamp = int(time.time())
        filename = f"voice_messages/{bookingId}/{senderId}_{timestamp}.m4a"
        
        # Upload to Firebase Storage
        bucket = storage.bucket()
        blob = bucket.blob(filename)
        
        # Read file content
        content = await audio.read()
        blob.upload_from_string(content, content_type='audio/m4a')
        
        # Make file publicly accessible
        blob.make_public()
        audio_url = blob.public_url
        
        # Create voice message record
        voice_message = VoiceMessage.create_voice_message(
            sender_id=senderId,
            receiver_id=receiverId,
            booking_id=bookingId,
            audio_url=audio_url,
            duration=duration
        )
        
        if not voice_message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Failed to create voice message"
            )
        
        return VoiceMessageResponse(
            success=True,
            message="Voice message uploaded successfully",
            voiceMessage=voice_message
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload voice message: {str(e)}"
        )


@router.get("/voice-messages/{booking_id}")
async def get_voice_messages(booking_id: str, limit: int = 50):
    """Get voice messages for a booking"""
    try:
        messages = VoiceMessage.get_voice_messages_for_booking(booking_id, limit)
        
        return {
            "success": True,
            "voiceMessages": messages
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch voice messages: {str(e)}"
        )


@router.post("/voice-messages/{message_id}/read")
async def mark_voice_message_read(message_id: str):
    """Mark a voice message as read"""
    try:
        success = VoiceMessage.mark_as_read(message_id)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Voice message not found"
            )
        
        return {
            "success": True,
            "message": "Voice message marked as read"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to mark voice message as read: {str(e)}"
        )


@router.get("/voice-messages/unread/{user_id}")
async def get_unread_count(user_id: str):
    """Get unread voice message count"""
    try:
        count = VoiceMessage.get_unread_count(user_id)
        
        return {
            "success": True,
            "unreadCount": count
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch unread count: {str(e)}"
        )

"""
Call Controller
Handles voice/video calling endpoints with Agora integration.

Signaling is intentionally REST + FCM only (no custom WebSocket server).
"""
from fastapi import APIRouter, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, List
import os
import uuid
import hashlib
import base64
import time
import logging
import importlib
from ..models.call import Call
from ..models.voice_message import VoiceMessage
from firebase_admin import messaging
from ..constants import LIVE_COMMUNICATION_STATUSES

router = APIRouter(prefix="/calls", tags=["calls"])
logger = logging.getLogger(__name__)


# Agora credentials (should be in environment variables)
AGORA_APP_ID = os.getenv("AGORA_APP_ID", "your_agora_app_id").strip()
AGORA_APP_CERTIFICATE = os.getenv("AGORA_APP_CERTIFICATE", "").strip()
try:
    AGORA_TOKEN_TTL_SECONDS = int((os.getenv("AGORA_TOKEN_TTL_SECONDS", "3600") or "3600").strip())
except ValueError:
    AGORA_TOKEN_TTL_SECONDS = 3600

_rtc_token_builder = None


def _is_placeholder_app_id(app_id: str) -> bool:
    return not app_id or app_id == "your_agora_app_id"


def _token_required() -> bool:
    return bool(AGORA_APP_CERTIFICATE) and not _is_placeholder_app_id(AGORA_APP_ID)


def _get_rtc_token_builder():
    global _rtc_token_builder
    if _rtc_token_builder is not None:
        return _rtc_token_builder

    try:
        module = importlib.import_module("agora_token_builder")
        _rtc_token_builder = getattr(module, "RtcTokenBuilder", None)
    except Exception:
        _rtc_token_builder = None

    return _rtc_token_builder


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
    userId: Optional[str] = None


class RefreshCallTokenRequest(BaseModel):
    callId: str
    userId: str


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


def _stable_agora_uid(user_id: str) -> int:
    """Generate stable, non-zero Agora UID for a user id."""
    # Keep deterministic mapping while guaranteeing uid > 0.
    return (int(hashlib.md5(user_id.encode()).hexdigest()[:8], 16) % 99999) + 1


def _to_data_url(content_type: str, content: bytes) -> str:
    encoded = base64.b64encode(content).decode("ascii")
    return f"data:{content_type};base64,{encoded}"


def _normalize_audio_content_type(uploaded: UploadFile, content: bytes) -> str:
    mime_type = (uploaded.content_type or '').lower().strip()
    if mime_type.startswith('audio/'):
        return mime_type

    if content.startswith(b'RIFF') and len(content) > 8 and content[8:12] == b'WAVE':
        return 'audio/wav'
    if content.startswith(b'ID3') or content.startswith((b'\xff\xfb', b'\xff\xfa', b'\xff\xf3')):
        return 'audio/mpeg'
    if b'ftyp' in content[:32]:
        return 'audio/m4a'
    if content.startswith(b'OggS'):
        return 'audio/ogg'

    return 'audio/m4a'


def generate_agora_token(channel_name: str, uid: int, role: int = 1) -> tuple[Optional[str], Optional[int]]:
    """
    Generate Agora RTC token
    role: 1 = publisher (can send/receive), 2 = subscriber (receive only)
    
    Note: For production, implement proper token generation with Agora AccessToken library
    For now, if no certificate is configured, Agora can work in testing mode without tokens
    """
    rtc_token_builder = _get_rtc_token_builder()

    if not _token_required() or rtc_token_builder is None:
        return None, None  # Testing mode, no token needed

    privilege_expired_ts = int(time.time()) + AGORA_TOKEN_TTL_SECONDS
    try:
        token = rtc_token_builder.buildTokenWithUid(
            AGORA_APP_ID,
            AGORA_APP_CERTIFICATE,
            channel_name,
            uid,
            role,
            privilege_expired_ts,
        )
        return token, privilege_expired_ts
    except Exception:
        logger.exception("Failed to generate Agora token")
        return None, None


async def send_call_notification(
    fcm_token: str,
    call_id: str,
    caller_id: str,
    caller_name: str,
    caller_role: str,
    call_type: str,
    agora_config: dict,
    caller_profile_image_url: Optional[str] = None,
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
                'callerRole': caller_role,                'callerProfileImageUrl': caller_profile_image_url or '',                'callType': call_type,
                # Pass ALL Agora config fields for proper channel/token/uid coordination
                'agoraAppId': agora_config.get('appId', ''),
                'agoraChannel': agora_config.get('channel', ''),
                'agoraToken': agora_config.get('token') or '',
                'agoraUid': str(agora_config.get('uid', 0)),
                'agoraCallerUid': str(agora_config.get('callerUid', 0)),
                'agoraReceiverUid': str(agora_config.get('receiverUid', 0)),
                'agoraTokenExpiresAt': str(agora_config.get('tokenExpiresAt', 0)),
                'agoraTokenExpiresIn': str(agora_config.get('tokenExpiresIn', 0)),
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


async def send_call_status_notification(
    fcm_token: str,
    *,
    call_id: str,
    status_value: str,
    call_type: str,
    other_user_name: str,
    other_user_role: str,
    duration: Optional[int] = None,
):
    """Send FCM notification about call status updates to the other participant."""
    try:
        message = messaging.Message(
            data={
                'type': 'call_status',
                'callId': call_id,
                'status': status_value,
                'callType': call_type,
                'otherUserName': other_user_name,
                'otherUserRole': other_user_role,
                'duration': str(duration or 0),
            },
            android=messaging.AndroidConfig(priority='high'),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(content_available=True)
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

        logger.info(
            "Call initiate requested: booking=%s token_required=%s token_builder_available=%s",
            request.bookingId,
            _token_required(),
            _get_rtc_token_builder() is not None,
        )
        
        # Generate unique channel name using UUID (much better than timestamp-based)
        # Format: call_booking_uuid
        channel_name = f"call_{request.bookingId}_{uuid.uuid4().hex[:8]}"
        
        # Generate UIDs from hashing user IDs instead of timestamp
        # This ensures consistent UIDs for same users
        caller_uid = _stable_agora_uid(request.callerId)
        receiver_uid = _stable_agora_uid(request.receiverId)
        
        # Ensure UIDs are different to avoid collisions
        while receiver_uid == caller_uid:
            receiver_uid = (receiver_uid % 99999) + 1
        
        # Generate Agora tokens (per-user token is required when certificate is enabled)
        caller_token, caller_token_expires_at = generate_agora_token(channel_name, caller_uid)
        receiver_token, receiver_token_expires_at = generate_agora_token(channel_name, receiver_uid)

        if _token_required() and (not caller_token or not receiver_token):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Agora token generation failed. Verify AGORA_APP_ID, AGORA_APP_CERTIFICATE, and server dependency setup."
            )
        
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
            agora_token=caller_token
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
        
        # Prepare Agora configs with role-specific UIDs
        caller_agora_config = {
            "appId": AGORA_APP_ID,
            "channel": channel_name,
            "token": caller_token,
            "uid": caller_uid,
            "callerUid": caller_uid,
            "receiverUid": receiver_uid,
            "tokenExpiresAt": caller_token_expires_at,
            "tokenExpiresIn": AGORA_TOKEN_TTL_SECONDS if caller_token_expires_at else None,
            "_debug": {
                "token_required": _token_required(),
                "token_builder_available": _get_rtc_token_builder() is not None,
                "token_generated": caller_token is not None,
                "app_id_set": not _is_placeholder_app_id(AGORA_APP_ID),
                "app_id_length": len(AGORA_APP_ID),
            },
        }

        receiver_agora_config = {
            "appId": AGORA_APP_ID,
            "channel": channel_name,
            "token": receiver_token,
            "uid": receiver_uid,
            "callerUid": caller_uid,
            "receiverUid": receiver_uid,
            "tokenExpiresAt": receiver_token_expires_at,
            "tokenExpiresIn": AGORA_TOKEN_TTL_SECONDS if receiver_token_expires_at else None,
            "_debug": {
                "token_required": _token_required(),
                "token_builder_available": _get_rtc_token_builder() is not None,
                "token_generated": receiver_token is not None,
                "app_id_set": not _is_placeholder_app_id(AGORA_APP_ID),
                "app_id_length": len(AGORA_APP_ID),
            },
        }
        
        # Send FCM notification to receiver if token provided
        # Send FCM notification to the intended receiver using server-side token lookup
        receiver_fcm_token = receiver_data.get('fcmToken')
        if receiver_fcm_token:
            # Always use database name as source of truth; frontend name might be 'User' fallback
            caller_name_actual = caller_data.get('name') or request.callerName or 'User'
            caller_role = request.callerRole or caller_data.get('role', 'user')
            caller_profile_image_url = caller_data.get('profile_image_url') or request.callerProfileImageUrl
            await send_call_notification(
                fcm_token=receiver_fcm_token,
                call_id=call_data['id'],
                caller_id=request.callerId,
                caller_name=caller_name_actual,
                caller_role=caller_role,
                caller_profile_image_url=caller_profile_image_url,
                call_type=request.callType,
                agora_config=receiver_agora_config
            )

        # Return call data with Agora config
        return CallResponse(
            success=True,
            message="Call initiated successfully",
            call=call_data,
            agoraConfig=caller_agora_config
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
        call_before = Call.get_call_by_id(request.callId)
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

        call_after = Call.get_call_by_id(request.callId) or call_before

        # Push counterpart real-time status updates via FCM.
        if call_after:
            from ..models.user import User

            caller_id = call_after.get('callerId')
            receiver_id = call_after.get('receiverId')
            actor_id = request.userId

            # Prefer explicit actor if provided; fallback by status semantics.
            if actor_id in {caller_id, receiver_id}:
                target_user_id = receiver_id if actor_id == caller_id else caller_id
            elif request.status == 'answered':
                target_user_id = caller_id
            else:
                target_user_id = receiver_id

            if target_user_id:
                target_user = User.get_by_id(target_user_id)
                target_token = (target_user or {}).get('fcmToken') if target_user else None
                if target_token:
                    if target_user_id == caller_id:
                        other_name = call_after.get('receiverName') or 'User'
                        other_role = call_after.get('receiverRole') or 'user'
                    else:
                        other_name = call_after.get('callerName') or 'User'
                        other_role = call_after.get('callerRole') or 'user'

                    await send_call_status_notification(
                        target_token,
                        call_id=request.callId,
                        status_value=request.status,
                        call_type=call_after.get('callType') or 'voice',
                        other_user_name=other_name,
                        other_user_role=other_role,
                        duration=request.duration,
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


@router.post("/token", response_model=CallResponse)
async def refresh_call_token(request: RefreshCallTokenRequest):
    """Refresh Agora token for an existing call participant (REST signaling)."""
    try:
        logger.info(
            "Call token refresh requested: callId=%s token_required=%s token_builder_available=%s",
            request.callId,
            _token_required(),
            _get_rtc_token_builder() is not None,
        )

        call = Call.get_call_by_id(request.callId)
        if not call:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call not found"
            )

        caller_id = call.get("callerId")
        receiver_id = call.get("receiverId")
        channel_name = call.get("agoraChannel")

        if request.userId not in {caller_id, receiver_id}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User is not a participant of this call"
            )

        if not channel_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Call channel not found"
            )

        uid = _stable_agora_uid(request.userId)
        token, token_expires_at = generate_agora_token(channel_name, uid)

        if _token_required() and not token:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Agora token refresh failed. Verify AGORA_APP_ID, AGORA_APP_CERTIFICATE, and server dependency setup."
            )

        agora_config = {
            "appId": AGORA_APP_ID,
            "channel": channel_name,
            "uid": uid,
            "token": token,
            "callerUid": _stable_agora_uid(str(caller_id)) if caller_id else None,
            "receiverUid": _stable_agora_uid(str(receiver_id)) if receiver_id else None,
            "tokenExpiresAt": token_expires_at,
            "tokenExpiresIn": AGORA_TOKEN_TTL_SECONDS if token_expires_at else None,
            "_debug": {
                "token_required": _token_required(),
                "token_builder_available": _get_rtc_token_builder() is not None,
                "token_generated": token is not None,
                "app_id_set": not _is_placeholder_app_id(AGORA_APP_ID),
                "app_id_length": len(AGORA_APP_ID),
            },
        }

        return CallResponse(
            success=True,
            message="Call token refreshed successfully",
            call=call,
            agoraConfig=agora_config,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to refresh call token: {str(e)}"
        )


@router.post("/voice-message/upload", response_model=VoiceMessageResponse)
async def upload_voice_message(
    audio: UploadFile = File(...),
    senderId: str = Form(...),
    receiverId: str = Form(...),
    bookingId: str = Form(...),
    duration: int = Form(...)
):
    """Upload a voice message and store as base64 data URL in Neo4j."""
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

        # Read file content
        content = await audio.read()

        if len(content) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Voice file too large (max 10MB)"
            )

        content_type = _normalize_audio_content_type(audio, content)
        audio_url = _to_data_url(content_type, content)
        
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


@router.get("/config-check")
async def check_config():
    """Diagnostic endpoint to verify Agora backend configuration (safe, no secrets)."""
    return {
        "success": True,
        "config": {
            "agora_app_id_set": not _is_placeholder_app_id(AGORA_APP_ID),
            "agora_certificate_set": bool(AGORA_APP_CERTIFICATE),
            "token_required": _token_required(),
            "token_builder_available": _get_rtc_token_builder() is not None,
            "token_ttl_seconds": AGORA_TOKEN_TTL_SECONDS,
            "app_id_length": len(AGORA_APP_ID),
            "certificate_length": len(AGORA_APP_CERTIFICATE),
        }
    }

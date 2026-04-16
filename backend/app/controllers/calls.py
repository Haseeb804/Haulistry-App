"""
Call Controller
WebRTC call lifecycle endpoints.

WebSocket (/ws/realtime) is used for signaling events (offer/answer/ICE + call events).
REST persists call history and call state.
"""
from __future__ import annotations

import logging
import uuid
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from firebase_admin import messaging

from ..constants import LIVE_COMMUNICATION_STATUSES
from ..models.call import Call
from ..models.voice_message import VoiceMessage
from ..realtime.websocket_gateway import manager, _event

router = APIRouter(prefix="/calls", tags=["calls"])
logger = logging.getLogger(__name__)
ACTIVE_COMMUNICATION_STATUSES = LIVE_COMMUNICATION_STATUSES


class InitiateCallRequest(BaseModel):
    callerId: str
    receiverId: str
    bookingId: str
    callType: str  # voice | video
    callerName: Optional[str] = None
    callerRole: Optional[str] = None
    callerProfileImageUrl: Optional[str] = None


class UpdateCallStatusRequest(BaseModel):
    callId: str
    status: str  # answered | ended | missed | rejected
    duration: Optional[int] = None
    userId: Optional[str] = None


class VoiceMessageRequest(BaseModel):
    senderId: str
    receiverId: str
    bookingId: str
    duration: int


class CallResponse(BaseModel):
    success: bool
    message: str
    call: Optional[dict] = None
    signalData: Optional[dict] = None


class VoiceMessageResponse(BaseModel):
    success: bool
    message: str
    voiceMessage: Optional[dict] = None


class CallHistoryResponse(BaseModel):
    success: bool
    calls: List[dict]


def _to_data_url(content_type: str, content: bytes) -> str:
    import base64

    encoded = base64.b64encode(content).decode("ascii")
    return f"data:{content_type};base64,{encoded}"


def _normalize_audio_content_type(uploaded: UploadFile, content: bytes) -> str:
    mime_type = (uploaded.content_type or "").lower().strip()
    if mime_type.startswith("audio/"):
        return mime_type

    if content.startswith(b"RIFF") and len(content) > 8 and content[8:12] == b"WAVE":
        return "audio/wav"
    if content.startswith(b"ID3") or content.startswith((b"\xff\xfb", b"\xff\xfa", b"\xff\xf3")):
        return "audio/mpeg"
    if b"ftyp" in content[:32]:
        return "audio/m4a"
    if content.startswith(b"OggS"):
        return "audio/ogg"

    return "audio/m4a"


async def _send_call_push(receiver_fcm_token: str, payload: Dict[str, Any]) -> bool:
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="📹 Incoming Video Call" if payload.get("callType") == "video" else "📞 Incoming Call",
                body=f"Incoming {payload.get('callType', 'voice')} call from {payload.get('callerName', 'User')}",
            ),
            data={
                "type": "call",
                **{k: str(v) if v is not None else "" for k, v in payload.items()},
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="call_channel",
                    priority="max",
                    tag=str(payload.get("callId") or "call"),
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="call_ringtone.caf", badge=1, category="CALL")
                )
            ),
            token=receiver_fcm_token,
        )
        messaging.send(message)
        return True
    except Exception:
        logger.exception("Failed to send offline call push")
        return False


@router.post("/initiate", response_model=CallResponse)
async def initiate_call(request: InitiateCallRequest):
    """Create call record + emit real-time incoming call event via WebSocket."""
    try:
        from ..models.user import User

        if request.callerId == request.receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Caller and receiver must be different users",
            )

        caller_data = User.get_by_id(request.callerId)
        receiver_data = User.get_by_id(request.receiverId)

        if not caller_data or not receiver_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Caller or receiver not found",
            )

        signaling_channel = f"call_{request.bookingId}_{uuid.uuid4().hex[:8]}"
        signaling_session_id = uuid.uuid4().hex

        call_data = Call.create_call(
            caller_id=request.callerId,
            receiver_id=request.receiverId,
            booking_id=request.bookingId,
            call_type=request.callType,
            signaling_channel=signaling_channel,
            signaling_session_id=signaling_session_id,
        )

        if not call_data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Call not allowed. Communication requires an active service between booking participants.",
            )

        caller_name_actual = caller_data.get("name") or request.callerName or "User"
        caller_role = request.callerRole or caller_data.get("role", "user")
        caller_profile_image_url = (
            caller_data.get("profileImageUrl")
            or caller_data.get("profile_image_url")
            or request.callerProfileImageUrl
        )

        signal_data = {
            "callId": call_data["id"],
            "bookingId": request.bookingId,
            "callType": request.callType,
            "signalingChannel": signaling_channel,
            "sessionId": signaling_session_id,
            "callerId": request.callerId,
            "receiverId": request.receiverId,
        }

        incoming_event_payload = {
            "callId": call_data["id"],
            "bookingId": request.bookingId,
            "callerId": request.callerId,
            "callerName": caller_name_actual,
            "callerRole": caller_role,
            "callerProfileImageUrl": caller_profile_image_url,
            "receiverId": request.receiverId,
            "callType": request.callType,
            "signalData": signal_data,
        }

        delivered = await manager.send_to_user(request.receiverId, _event("call_incoming", incoming_event_payload))

        if delivered == 0:
            receiver_fcm_token = receiver_data.get("fcmToken") or receiver_data.get("fcm_token")
            if receiver_fcm_token:
                await _send_call_push(receiver_fcm_token, incoming_event_payload)

        return CallResponse(
            success=True,
            message="Call initiated successfully",
            call=call_data,
            signalData=signal_data,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to initiate call")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to initiate call: {str(e)}",
        )


@router.post("/update-status", response_model=CallResponse)
async def update_call_status(request: UpdateCallStatusRequest):
    """Persist call state changes and notify both participants when online."""
    try:
        call_before = Call.get_call_by_id(request.callId)
        success = Call.update_call_status(
            call_id=request.callId,
            status=request.status,
            duration=request.duration,
        )

        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call not found",
            )

        call_after = Call.get_call_by_id(request.callId) or call_before or {}

        caller_id = call_after.get("callerId")
        receiver_id = call_after.get("receiverId")

        for target_user_id in [uid for uid in [caller_id, receiver_id] if uid]:
            await manager.send_to_user(
                str(target_user_id),
                _event(
                    "call_status",
                    {
                        "callId": request.callId,
                        "status": request.status,
                        "duration": request.duration or 0,
                        "callType": call_after.get("callType") or "voice",
                        "otherUserName": call_after.get("receiverName") if target_user_id == caller_id else call_after.get("callerName"),
                        "otherUserRole": call_after.get("receiverRole") if target_user_id == caller_id else call_after.get("callerRole"),
                        "otherUserProfileImageUrl": call_after.get("receiverProfileImageUrl") if target_user_id == caller_id else call_after.get("callerProfileImageUrl"),
                    },
                ),
            )

        return CallResponse(success=True, message=f"Call status updated to {request.status}")

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to update call status")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update call status: {str(e)}",
        )


@router.get("/history/{user_id}", response_model=CallHistoryResponse)
async def get_call_history(user_id: str, limit: int = 20):
    try:
        calls = Call.get_call_history(user_id, limit)
        return CallHistoryResponse(success=True, calls=calls)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch call history: {str(e)}",
        )


@router.get("/{call_id}", response_model=CallResponse)
async def get_call(call_id: str, user_id: Optional[str] = None):
    try:
        call = Call.get_call_by_id(call_id)
        if not call:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call not found",
            )

        signal_data = {
            "callId": call.get("id"),
            "bookingId": call.get("bookingId"),
            "callType": call.get("callType"),
            "signalingChannel": call.get("signalingChannel"),
            "sessionId": call.get("signalingSessionId"),
            "callerId": call.get("callerId"),
            "receiverId": call.get("receiverId"),
            "requestedBy": user_id,
        }

        return CallResponse(
            success=True,
            message="Call retrieved successfully",
            call=call,
            signalData=signal_data,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch call: {str(e)}",
        )


@router.post("/voice-message/upload", response_model=VoiceMessageResponse)
async def upload_voice_message(
    audio: UploadFile = File(...),
    senderId: str = Form(...),
    receiverId: str = Form(...),
    bookingId: str = Form(...),
    duration: int = Form(...),
):
    """Upload a voice message and store as base64 data URL in Neo4j."""
    try:
        from ..models.booking import Booking

        if senderId == receiverId:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sender and receiver must be different users",
            )

        booking = Booking.get_by_id(bookingId)
        if not booking:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found",
            )

        status_value = str(booking.get("status") or "").lower()
        if status_value not in ACTIVE_COMMUNICATION_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Voice messaging is only available during active service",
            )

        seeker_id = booking.get("seekerId")
        provider_id = booking.get("providerId")
        participants_match = (
            (senderId == seeker_id and receiverId == provider_id)
            or (senderId == provider_id and receiverId == seeker_id)
        )
        if not participants_match:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Users are not valid participants for this booking",
            )

        content = await audio.read()

        if len(content) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Voice file too large (max 10MB)",
            )

        content_type = _normalize_audio_content_type(audio, content)
        audio_url = _to_data_url(content_type, content)

        voice_message = VoiceMessage.create_voice_message(
            sender_id=senderId,
            receiver_id=receiverId,
            booking_id=bookingId,
            audio_url=audio_url,
            duration=duration,
        )

        if not voice_message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Failed to create voice message",
            )

        return VoiceMessageResponse(
            success=True,
            message="Voice message uploaded successfully",
            voiceMessage=voice_message,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload voice message: {str(e)}",
        )


@router.get("/voice-messages/{booking_id}")
async def get_voice_messages(booking_id: str, limit: int = 50):
    try:
        messages = VoiceMessage.get_voice_messages_for_booking(booking_id, limit)
        return {"success": True, "voiceMessages": messages}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch voice messages: {str(e)}",
        )


@router.post("/voice-messages/{message_id}/read")
async def mark_voice_message_read(message_id: str):
    try:
        success = VoiceMessage.mark_as_read(message_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Voice message not found",
            )
        return {"success": True, "message": "Voice message marked as read"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to mark voice message as read: {str(e)}",
        )


@router.get("/voice-messages/unread/{user_id}")
async def get_unread_count(user_id: str):
    try:
        count = VoiceMessage.get_unread_count(user_id)
        return {"success": True, "unreadCount": count}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch unread count: {str(e)}",
        )

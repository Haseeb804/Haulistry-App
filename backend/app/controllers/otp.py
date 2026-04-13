"""
Custom phone OTP API controller (no Firebase, no paid provider required).

Endpoints:
- POST /send-otp
- POST /verify-otp

By default OTP "sending" is simulated by printing OTP to server console.
"""

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..schemas.otp_schema import SendOtpRequest, VerifyOtpRequest, OtpApiResponse
from ..services.otp_service import (
    OtpService,
    OtpRateLimitError,
    OtpExpiredError,
    OtpInvalidError,
    OtpBruteForceBlockedError,
)


router = APIRouter(tags=["otp"])
otp_service = OtpService()


@router.post("/send-otp", response_model=OtpApiResponse)
async def send_otp(payload: SendOtpRequest):
    """
    Generate and "send" OTP for a phone number.

    Security controls:
    - max 3 requests per minute per phone number.
    """
    try:
        expires_in = otp_service.send_otp(payload.phone)
        return OtpApiResponse(
            success=True,
            message="OTP generated and sent successfully",
            expiresInSeconds=expires_in,
            data={
                "phone": otp_service.normalize_phone(payload.phone),
            },
        )
    except OtpRateLimitError as exc:
        return JSONResponse(
            status_code=429,
            content=OtpApiResponse(
                success=False,
                message=str(exc),
                retryAfterSeconds=exc.retry_after_seconds,
            ).model_dump(exclude_none=True),
        )
    except Exception:
        return JSONResponse(
            status_code=500,
            content=OtpApiResponse(
                success=False,
                message="Failed to generate OTP",
            ).model_dump(exclude_none=True),
        )


@router.post("/verify-otp", response_model=OtpApiResponse)
async def verify_otp(payload: VerifyOtpRequest):
    """
    Verify OTP for a phone number.

    Security controls:
    - OTP expires after 5 minutes.
    - max 5 wrong attempts within 5 minutes before temporary block.
    """
    try:
        otp_service.verify_otp(payload.phone, payload.otp)
        return OtpApiResponse(
            success=True,
            message="OTP verified successfully",
            data={
                "phone": otp_service.normalize_phone(payload.phone),
                "verified": True,
            },
        )
    except OtpExpiredError as exc:
        return JSONResponse(
            status_code=400,
            content=OtpApiResponse(success=False, message=str(exc)).model_dump(exclude_none=True),
        )
    except OtpInvalidError as exc:
        return JSONResponse(
            status_code=401,
            content=OtpApiResponse(success=False, message=str(exc)).model_dump(exclude_none=True),
        )
    except OtpBruteForceBlockedError as exc:
        return JSONResponse(
            status_code=429,
            content=OtpApiResponse(
                success=False,
                message=str(exc),
                retryAfterSeconds=exc.retry_after_seconds,
            ).model_dump(exclude_none=True),
        )
    except Exception:
        return JSONResponse(
            status_code=500,
            content=OtpApiResponse(
                success=False,
                message="Failed to verify OTP",
            ).model_dump(exclude_none=True),
        )

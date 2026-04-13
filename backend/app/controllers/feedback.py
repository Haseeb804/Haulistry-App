from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from ..models.feedback import Feedback

router = APIRouter(prefix="/feedback", tags=["Feedback"])


class FeedbackRequest(BaseModel):
    booking_id: str = Field(..., alias="bookingId")
    provider_id: str = Field(..., alias="providerId")
    seeker_id: str = Field(..., alias="seekerId")
    rating: float = Field(..., ge=1, le=5)
    comment: Optional[str] = None

    class Config:
        populate_by_name = True

    @field_validator('comment')
    @classmethod
    def validate_comment(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v.strip() == '':
            return v
        
        # Ensure minimum meaningful content
        if len(v.strip()) < 10:
            raise ValueError('Comment must be at least 10 characters long for meaningful feedback')
        
        return v.strip()


class FeedbackResponse(BaseModel):
    success: bool
    message: str
    feedback: Optional[dict] = None


@router.post("/provider", response_model=FeedbackResponse)
async def create_provider_feedback(request: FeedbackRequest):
    """Seeker gives feedback about provider"""
    try:
        # Check if feedback already exists for this booking
        if Feedback.check_feedback_exists(request.booking_id, 'seeker'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have already submitted a review for this service booking. Each completed booking can only be reviewed once."
            )
        
        feedback_data = Feedback.create_provider_feedback(
            booking_id=request.booking_id,
            provider_id=request.provider_id,
            seeker_id=request.seeker_id,
            rating=request.rating,
            comment=request.comment
        )
        
        if not feedback_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found or feedback creation failed"
            )
        
        return FeedbackResponse(
            success=True,
            message="Thank you! Your feedback has been submitted successfully.",
            feedback=feedback_data
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create feedback: {str(e)}"
        )


@router.post("/seeker", response_model=FeedbackResponse)
async def create_seeker_feedback(request: FeedbackRequest):
    """Provider gives feedback about seeker"""
    try:
        # Check if feedback already exists for this booking
        if Feedback.check_feedback_exists(request.booking_id, 'provider'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have already submitted a review for this service booking. Each completed booking can only be reviewed once."
            )
        
        feedback_data = Feedback.create_seeker_feedback(
            booking_id=request.booking_id,
            provider_id=request.provider_id,
            seeker_id=request.seeker_id,
            rating=request.rating,
            comment=request.comment
        )
        
        if not feedback_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Booking not found or feedback creation failed"
            )
        
        return FeedbackResponse(
            success=True,
            message="Thank you! Your feedback has been submitted successfully.",
            feedback=feedback_data
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create feedback: {str(e)}"
        )


@router.get("/provider/{provider_id}")
async def get_provider_feedbacks(provider_id: str, limit: int = 50):
    """Get all feedback for a provider"""
    try:
        feedbacks = Feedback.get_provider_feedbacks(provider_id, limit)
        return {
            "success": True,
            "feedbacks": feedbacks
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch feedbacks: {str(e)}"
        )


@router.get("/seeker/{seeker_id}")
async def get_seeker_feedbacks(seeker_id: str, limit: int = 50):
    """Get all feedback for a seeker"""
    try:
        feedbacks = Feedback.get_seeker_feedbacks(seeker_id, limit)
        return {
            "success": True,
            "feedbacks": feedbacks
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch feedbacks: {str(e)}"
        )


@router.get("/check/{booking_id}/{reviewer_type}")
async def check_feedback_exists(booking_id: str, reviewer_type: str):
    """Check if feedback exists for a booking"""
    try:
        exists = Feedback.check_feedback_exists(booking_id, reviewer_type)
        return {
            "success": True,
            "exists": exists
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to check feedback: {str(e)}"
        )

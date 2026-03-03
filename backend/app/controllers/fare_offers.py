"""
Fare Offer REST API Controller
Handles InDrive-style bidding and negotiation between seekers and providers
"""

from fastapi import APIRouter, HTTPException, status
from typing import Optional
from ..schemas.fare_offer_schema import (
    FareOfferCreate, CounterOfferRequest, UpdateOfferPrice,
    FareOfferResponse, FareOffersListResponse
)
from ..models.fare_offer import FareOffer
from ..services.websocket_manager import manager, WSMessageType, create_ws_message

router = APIRouter()


@router.post("", response_model=FareOfferResponse, status_code=status.HTTP_201_CREATED)
async def create_fare_offer(offer: FareOfferCreate):
    """
    Provider creates a fare offer on a booking request (bid)
    This is the InDrive-style bidding mechanism
    """
    try:
        offer_data = FareOffer.create(offer.dict())
        
        if not offer_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create fare offer"
            )
        
        # Notify seeker via WebSocket about the new offer
        # Get booking to find seeker ID
        from ..models.booking import Booking
        booking = Booking.get_by_id(offer.bookingId)
        if booking:
            await manager.send_personal_message(
                booking['seekerId'],
                create_ws_message(
                    WSMessageType.NEW_FARE_OFFER,
                    offer_data,
                    booking_id=offer.bookingId,
                    sender_id=offer.providerId
                )
            )
        
        return FareOfferResponse(
            success=True,
            message="Fare offer created successfully",
            offer=offer_data
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create fare offer: {str(e)}"
        )


@router.get("/booking/{booking_id}", response_model=FareOffersListResponse)
async def get_booking_offers(booking_id: str):
    """Get all fare offers for a specific booking (for seeker to view bids)"""
    try:
        offers = FareOffer.get_offers_for_booking(booking_id)
        
        return FareOffersListResponse(
            success=True,
            message="Offers retrieved successfully",
            offers=offers,
            total=len(offers)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch offers: {str(e)}"
        )


@router.get("/provider/{provider_id}", response_model=FareOffersListResponse)
async def get_provider_offers(provider_id: str, status: Optional[str] = None):
    """Get all offers made by a provider"""
    try:
        offers = FareOffer.get_provider_offers(provider_id, status)
        
        return FareOffersListResponse(
            success=True,
            message="Provider offers retrieved successfully",
            offers=offers,
            total=len(offers)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch provider offers: {str(e)}"
        )


@router.get("/{offer_id}", response_model=FareOfferResponse)
async def get_offer(offer_id: str):
    """Get a specific fare offer by ID"""
    try:
        offer = FareOffer.get_by_id(offer_id)
        
        if not offer:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Offer not found"
            )
        
        return FareOfferResponse(
            success=True,
            message="Offer retrieved successfully",
            offer=offer
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch offer: {str(e)}"
        )


@router.put("/{offer_id}/accept", response_model=FareOfferResponse)
async def accept_offer(offer_id: str):
    """
    Seeker accepts a fare offer
    This confirms the booking with the selected provider
    """
    try:
        offer_data = FareOffer.accept_offer(offer_id)
        
        if not offer_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Offer not found"
            )
        
        # Notify provider that their offer was accepted
        await manager.send_personal_message(
            offer_data['providerId'],
            create_ws_message(
                WSMessageType.FARE_OFFER_ACCEPTED,
                offer_data,
                booking_id=offer_data['bookingId'],
                sender_id=offer_data.get('booking', {}).get('seekerId')
            )
        )
        
        # Also notify other providers that their offers were rejected
        # (This is handled in the model when we accept one offer)
        
        return FareOfferResponse(
            success=True,
            message="Offer accepted - booking confirmed!",
            offer=offer_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to accept offer: {str(e)}"
        )


@router.put("/{offer_id}/reject", response_model=FareOfferResponse)
async def reject_offer(offer_id: str):
    """Seeker rejects a fare offer"""
    try:
        # Get offer first to notify provider
        existing = FareOffer.get_by_id(offer_id)
        
        offer_data = FareOffer.reject_offer(offer_id)
        
        if not offer_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Offer not found"
            )
        
        # Notify provider that their offer was rejected
        if existing:
            await manager.send_personal_message(
                existing['providerId'],
                create_ws_message(
                    WSMessageType.FARE_OFFER_REJECTED,
                    offer_data,
                    booking_id=existing['bookingId']
                )
            )
        
        return FareOfferResponse(
            success=True,
            message="Offer rejected successfully",
            offer=offer_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to reject offer: {str(e)}"
        )


@router.put("/{offer_id}/counter", response_model=FareOfferResponse)
async def counter_offer(offer_id: str, counter: CounterOfferRequest):
    """
    Seeker makes a counter offer
    Provider can then accept, reject, or update their price
    """
    try:
        # Get offer first to notify provider
        existing = FareOffer.get_by_id(offer_id)
        
        offer_data = FareOffer.counter_offer(offer_id, counter.counterPrice)
        
        if not offer_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Offer not found"
            )
        
        # Notify provider about the counter offer
        if existing:
            await manager.send_personal_message(
                existing['providerId'],
                create_ws_message(
                    WSMessageType.COUNTER_OFFER,
                    {
                        'offerId': offer_id,
                        'counterPrice': counter.counterPrice,
                        'originalPrice': existing['offeredPrice']
                    },
                    booking_id=existing['bookingId']
                )
            )
        
        return FareOfferResponse(
            success=True,
            message="Counter offer sent successfully",
            offer=offer_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send counter offer: {str(e)}"
        )


@router.put("/{offer_id}/update-price", response_model=FareOfferResponse)
async def update_offer_price(offer_id: str, update: UpdateOfferPrice):
    """
    Provider updates their offer price (in response to counter offer)
    """
    try:
        # Get offer and booking to notify seeker
        existing = FareOffer.get_by_id(offer_id)
        
        offer_data = FareOffer.update_offer_price(offer_id, update.newPrice, update.message)
        
        if not offer_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Offer not found"
            )
        
        # Notify seeker about the updated offer
        if existing:
            from ..models.booking import Booking
            booking = Booking.get_by_id(existing['bookingId'])
            if booking:
                await manager.send_personal_message(
                    booking['seekerId'],
                    create_ws_message(
                        WSMessageType.OFFER_UPDATED,
                        offer_data,
                        booking_id=existing['bookingId'],
                        sender_id=existing['providerId']
                    )
                )
        
        return FareOfferResponse(
            success=True,
            message="Offer price updated successfully",
            offer=offer_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update offer price: {str(e)}"
        )


@router.put("/{offer_id}/withdraw", response_model=FareOfferResponse)
async def withdraw_offer(offer_id: str):
    """Provider withdraws their offer"""
    try:
        # Get offer and booking to notify seeker
        existing = FareOffer.get_by_id(offer_id)
        
        offer_data = FareOffer.withdraw_offer(offer_id)
        
        if not offer_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Offer not found"
            )
        
        # Notify seeker about withdrawn offer
        if existing:
            from ..models.booking import Booking
            booking = Booking.get_by_id(existing['bookingId'])
            if booking:
                await manager.send_personal_message(
                    booking['seekerId'],
                    create_ws_message(
                        WSMessageType.OFFER_WITHDRAWN,
                        {'offerId': offer_id},
                        booking_id=existing['bookingId']
                    )
                )
        
        return FareOfferResponse(
            success=True,
            message="Offer withdrawn successfully",
            offer=offer_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to withdraw offer: {str(e)}"
        )

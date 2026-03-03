"""
REST API routers for Haulistry backend
Complete API structure for seeker-provider platform
"""

from fastapi import APIRouter
from . import bookings, vehicles, auth, services, fare_offers, locations, feedback, calls, messages

# Create main API router
api_router = APIRouter(prefix="/api")

# Include sub-routers
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
api_router.include_router(vehicles.router, prefix="/vehicles", tags=["vehicles"])
api_router.include_router(services.router, prefix="/services", tags=["services"])
api_router.include_router(fare_offers.router, prefix="/fare-offers", tags=["fare-offers"])
api_router.include_router(locations.router, prefix="/locations", tags=["locations"])
api_router.include_router(feedback.router, tags=["feedback"])
api_router.include_router(calls.router, tags=["calls"])
api_router.include_router(messages.router, tags=["messages"])

# Keep legacy controllers for GraphQL
from .user_controller import UserController
from .vehicle_controller import VehicleController
from .booking_controller import BookingController

__all__ = ['UserController', 'VehicleController', 'BookingController', 'api_router']


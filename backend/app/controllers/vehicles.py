"""
Vehicle REST API Controller
Handles HTTP requests and delegates to model layer
"""

from fastapi import APIRouter, HTTPException, status
from ..schemas.vehicle_schema import VehicleCreate, VehicleUpdate, VehicleResponse
from ..models.vehicle import Vehicle
from ..models.user import User
from ..database import neo4j_driver

router = APIRouter()


@router.post("", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
async def create_vehicle(vehicle: VehicleCreate):
    """Create a new vehicle"""
    try:
        provider = User.get_by_id(vehicle.providerId)
        if not provider:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Provider not found."
            )

        vehicle_data = Vehicle.create(vehicle.dict())
        
        if not vehicle_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create vehicle"
            )
        
        return VehicleResponse(
            success=True,
            message="Vehicle created successfully",
            vehicle=vehicle_data
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create vehicle: {str(e)}"
        )


@router.put("/{vehicle_id}", response_model=VehicleResponse)
async def update_vehicle(vehicle_id: str, vehicle_update: VehicleUpdate):
    """Update vehicle details. When isAvailable changes, cascades to linked services."""
    try:
        update_dict = vehicle_update.dict()
        update_data = {k: v for k, v in update_dict.items() if v is not None}

        vehicle_data = Vehicle.update(vehicle_id, update_data)

        if not vehicle_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehicle not found"
            )

        # Cascade availability change to linked services
        if 'isAvailable' in update_dict and update_dict['isAvailable'] is not None:
            is_available = bool(update_dict['isAvailable'])
            neo4j_driver.execute_write(
                """
                MATCH (v:Vehicle {id: $vehicleId})-[:PROVIDES]->(s:Service)
                SET s.isActive = $isActive, s.updatedAt = datetime()
                """,
                {'vehicleId': vehicle_id, 'isActive': is_available},
            )

        return VehicleResponse(
            success=True,
            message="Vehicle updated successfully",
            vehicle=vehicle_data
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update vehicle: {str(e)}"
        )


@router.delete("/{vehicle_id}", response_model=VehicleResponse)
async def delete_vehicle(vehicle_id: str):
    """Delete a vehicle"""
    try:
        deleted = Vehicle.delete(vehicle_id)
        
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehicle not found"
            )
        
        return VehicleResponse(
            success=True,
            message="Vehicle deleted successfully",
            vehicle=None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete vehicle: {str(e)}"
        )

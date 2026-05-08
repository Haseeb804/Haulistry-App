"""
Service REST API Controller
Handles service management for providers
"""

from fastapi import APIRouter, HTTPException, status, Query
from typing import Optional
from ..schemas.service_schema import (
    ServiceCreate, ServiceUpdate, ServiceResponse, ServicesListResponse
)
from ..models.service import Service
from ..config.service_form_configs import get_form_config, list_service_types

router = APIRouter()


@router.get("/form-config/all", tags=["Service Forms"])
async def get_all_form_configs():
    """Return form field configs for all known service types."""
    from ..config.service_form_configs import SERVICE_FORM_CONFIGS
    return {"success": True, "configs": SERVICE_FORM_CONFIGS, "serviceTypes": list_service_types()}


@router.get("/form-config/{service_type}", tags=["Service Forms"])
async def get_service_form_config(service_type: str):
    """Return dynamic form field configuration for a given service type."""
    config = get_form_config(service_type)
    if config is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No form config found for service type: {service_type}",
        )
    return {"success": True, "serviceType": service_type, "config": config}


@router.post("", response_model=ServiceResponse, status_code=status.HTTP_201_CREATED)
async def create_service(service: ServiceCreate):
    """Create a new service offering"""
    try:
        service_data = Service.create(service.dict())
        
        if not service_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create service"
            )
        
        return ServiceResponse(
            success=True,
            message="Service created successfully",
            service=service_data
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create service: {str(e)}"
        )


@router.get("", response_model=ServicesListResponse)
async def get_available_services(
    category: Optional[str] = Query(None, description="Filter by category"),
    latitude: Optional[float] = Query(None, description="User latitude for nearby search"),
    longitude: Optional[float] = Query(None, description="User longitude for nearby search"),
    radius: float = Query(50.0, description="Search radius in km")
):
    """Get all available services (for seekers to browse)"""
    try:
        services = Service.get_available_services(
            category=category,
            latitude=latitude,
            longitude=longitude,
            radius_km=radius
        )
        
        return ServicesListResponse(
            success=True,
            message="Services retrieved successfully",
            services=services,
            total=len(services)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch services: {str(e)}"
        )


@router.get("/provider/{provider_id}", response_model=ServicesListResponse)
async def get_provider_services(provider_id: str):
    """Get all services offered by a provider"""
    try:
        services = Service.get_by_provider(provider_id)
        
        return ServicesListResponse(
            success=True,
            message="Provider services retrieved successfully",
            services=services,
            total=len(services)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch provider services: {str(e)}"
        )


@router.get("/vehicle/{vehicle_id}", response_model=ServicesListResponse)
async def get_vehicle_services(vehicle_id: str):
    """Get all services offered by a specific vehicle"""
    try:
        services = Service.get_by_vehicle(vehicle_id)
        
        return ServicesListResponse(
            success=True,
            message="Vehicle services retrieved successfully",
            services=services,
            total=len(services)
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch vehicle services: {str(e)}"
        )


@router.get("/{service_id}", response_model=ServiceResponse)
async def get_service(service_id: str):
    """Get a specific service by ID"""
    try:
        service = Service.get_by_id(service_id)
        
        if not service:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Service not found"
            )
        
        return ServiceResponse(
            success=True,
            message="Service retrieved successfully",
            service=service
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch service: {str(e)}"
        )


@router.put("/{service_id}", response_model=ServiceResponse)
async def update_service(service_id: str, service_update: ServiceUpdate):
    """Update a service"""
    try:
        update_data = {k: v for k, v in service_update.dict().items() if v is not None}
        service_data = Service.update(service_id, update_data)
        
        if not service_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Service not found"
            )
        
        return ServiceResponse(
            success=True,
            message="Service updated successfully",
            service=service_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update service: {str(e)}"
        )


@router.delete("/{service_id}", response_model=ServiceResponse)
async def delete_service(service_id: str):
    """Delete a service"""
    try:
        deleted = Service.delete(service_id)
        
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Service not found"
            )
        
        return ServiceResponse(
            success=True,
            message="Service deleted successfully",
            service=None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete service: {str(e)}"
        )

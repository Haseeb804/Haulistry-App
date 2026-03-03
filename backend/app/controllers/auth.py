"""
Auth REST API Controller
Handles Firebase authentication and Neo4j user data sync
"""

from fastapi import APIRouter, HTTPException, status, Header
from typing import Optional
import firebase_admin
from firebase_admin import credentials, auth
from ..schemas.user_schema import (
    UserCreate, UserUpdate, UserResponse,
    TokenVerifyRequest, TokenVerifyResponse
)
from ..models.user import User
from ..config import settings
import os
import json
import base64
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


def _init_firebase() -> firebase_admin.App:
    """
    Initialise Firebase Admin SDK.

    Priority order (supports both local dev and serverless environments):
      1. FIREBASE_CREDENTIALS_JSON  – base64-encoded service-account JSON
                                      (set this env var on Vercel / any serverless host)
      2. FIREBASE_CREDENTIALS_PATH  – path to a local service-account JSON file
                                      (used for local development)
      3. Project-ID fallback         – minimal init when neither is available
    """
    raw_b64 = os.getenv("FIREBASE_CREDENTIALS_JSON")
    if raw_b64:
        try:
            service_account_info = json.loads(base64.b64decode(raw_b64).decode("utf-8"))
            cred = credentials.Certificate(service_account_info)
            app = firebase_admin.initialize_app(cred)
            logger.info("Firebase initialised from FIREBASE_CREDENTIALS_JSON env var")
            return app
        except Exception as exc:
            logger.error(f"Failed to parse FIREBASE_CREDENTIALS_JSON: {exc}")

    service_account_path = os.path.abspath(settings.FIREBASE_CREDENTIALS_PATH)
    if os.path.exists(service_account_path):
        cred = credentials.Certificate(service_account_path)
        app = firebase_admin.initialize_app(cred)
        logger.info(f"Firebase initialised from file: {service_account_path}")
        return app

    # Last-resort fallback — auth token verification will not work
    options = {"projectId": "haulistry-1b835"}
    app = firebase_admin.initialize_app(options=options)
    logger.warning("Firebase initialised with project ID only (no service account — token verification disabled)")
    return app


# Initialize Firebase Admin SDK (idempotent — won't re-init if already done)
try:
    firebase_app = firebase_admin.get_app()
except ValueError:
    firebase_app = _init_firebase()


@router.get("/test")
async def test_endpoint():
    """Test endpoint to verify auth router is working"""
    return {"message": "Auth router is working!", "status": "ok"}


@router.post("/sync", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def sync_user(user: UserCreate):
    """
    Sync user data from Firebase to Neo4j
    Called after successful Firebase signup/login
    """
    try:
        user_data = User.create(user.dict())
        
        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to sync user to Neo4j"
            )
        return UserResponse(
            success=True,
            message="User synced successfully to Neo4j",
            user=user_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to sync user: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync user: {str(e)}"
        )


@router.post("/verify-token", response_model=TokenVerifyResponse)
async def verify_token(token_request: TokenVerifyRequest):
    """
    Verify Firebase ID token and return user data from Neo4j
    """
    try:
        # Verify the Firebase token
        decoded_token = auth.verify_id_token(token_request.idToken)
        firebase_uid = decoded_token['uid']
        email = decoded_token.get('email', '')
        
        # Get user from Neo4j
        user_data = User.get_by_id(firebase_uid)
        
        if not user_data:
            return TokenVerifyResponse(
                success=False,
                message="User not found in Neo4j. Please sync user data first.",
                firebaseUid=firebase_uid,
                email=email,
                user=None
            )
        
        return TokenVerifyResponse(
            success=True,
            message="Token verified successfully",
            firebaseUid=firebase_uid,
            email=email,
            user=user_data
        )
        
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token"
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has expired"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Token verification failed: {str(e)}"
        )


@router.get("/me", response_model=UserResponse)
async def get_current_user(authorization: Optional[str] = Header(None)):
    """Get current user data from Neo4j using Firebase token"""
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header"
        )
    
    try:
        id_token = authorization.split('Bearer ')[1]
        decoded_token = auth.verify_id_token(id_token)
        firebase_uid = decoded_token['uid']
        
        user_data = User.get_by_id(firebase_uid)
        
        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User data not found in database"
            )
        
        return UserResponse(
            success=True,
            message="User retrieved successfully",
            user=user_data
        )
        
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token"
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has expired"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user: {str(e)}"
        )


@router.put("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    authorization: Optional[str] = Header(None)
):
    """
    Update current user data in Neo4j
    """
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header"
        )
    
    try:
        # Extract token
        id_token = authorization.split('Bearer ')[1]
        
        # Verify token
        decoded_token = auth.verify_id_token(id_token)
        firebase_uid = decoded_token['uid']
        
        # Filter out None values
        update_data = {k: v for k, v in user_update.dict().items() if v is not None}
        
        # Update user in Neo4j
        user_data = User.update(firebase_uid, update_data)
        
        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found in Neo4j"
            )
        
        return UserResponse(
            success=True,
            message="User updated successfully",
            user=user_data
        )
        
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token"
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has expired"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user: {str(e)}"
        )


@router.get("/user/{user_id}", response_model=UserResponse)
async def get_user_by_id(user_id: str):
    """
    Get user data by Firebase UID (useful for retrieving phone numbers for calls)
    """
    try:
        user_data = User.get_by_id(user_id)
        
        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found in Neo4j"
            )
        
        return UserResponse(
            success=True,
            message="User retrieved successfully",
            user=user_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user: {str(e)}"
        )

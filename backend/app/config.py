import os
import json
from typing import List
from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import field_validator, model_validator
from dotenv import load_dotenv

# Load .env from multiple possible locations
env_paths = [
    Path(__file__).parent.parent / ".env",  # backend/.env
    Path(__file__).parent.parent.parent / ".env",  # root .env
]
for env_path in env_paths:
    if env_path.exists():
        load_dotenv(env_path)
        break


class Settings(BaseSettings):
    """Application settings and configuration"""
    
    # Application
    APP_NAME: str = "Haulistry Backend"
    VERSION: str = "1.0.0"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 4000
    ENVIRONMENT: str = "development"
    SECRET_KEY: str = "your-secret-key-here"
    OTP_EXPOSE_IN_RESPONSE: bool = True
    
    # Neo4j Configuration
    NEO4J_URI: str = os.getenv("NEO4J_URI") or os.getenv("NEO4J_URL") or "bolt://localhost:7687"
    NEO4J_USERNAME: str = os.getenv("NEO4J_USERNAME") or os.getenv("NEO4J_USER") or "neo4j"
    NEO4J_PASSWORD: str = os.getenv("NEO4J_PASSWORD") or "password"
    NEO4J_DATABASE: str = os.getenv("NEO4J_DATABASE") or "neo4j"
    
    # Firebase Configuration
    FIREBASE_CREDENTIALS_PATH: str = "./serviceAccountKey.json"
    
    # CORS Configuration
    ALLOWED_ORIGINS: str = "*"

    # Socket.IO / Realtime Configuration
    SOCKETIO_PATH: str = "socket.io"
    SOCKETIO_CORS_ORIGINS: str = "*"
    SOCKETIO_PING_INTERVAL: int = 25
    SOCKETIO_PING_TIMEOUT: int = 60

    # Redis Configuration
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    REDIS_ENABLED: bool = os.getenv("REDIS_ENABLED", "true").lower() == "true"

    # Upstash (optional fallback hints)
    UPSTASH_REDIS_REST_URL: str = os.getenv("UPSTASH_REDIS_REST_URL", "")
    UPSTASH_REDIS_REST_TOKEN: str = os.getenv("UPSTASH_REDIS_REST_TOKEN", "")

    # Metered TURN Configuration
    METERED_TURN_DOMAIN: str = os.getenv("METERED_TURN_DOMAIN", "haulistry.metered.live")
    METERED_API_KEY: str = os.getenv("METERED_API_KEY", "")
    TURN_REGION: str = os.getenv("TURN_REGION", "global")
    # Optional static fallback ICE servers as JSON array
    TURN_FALLBACK_ICE_SERVERS: str = os.getenv("TURN_FALLBACK_ICE_SERVERS", "")
    
    @model_validator(mode='before')
    @classmethod
    def strip_bad_prefixes(cls, values: dict) -> dict:
        """Strip accidental leading tab/space/= from ALL env var values (Railway copy-paste artifact)."""
        cleaned = {}
        for k, v in values.items():
            if isinstance(v, str):
                s = v.strip()
                if s.startswith('='):
                    s = s.lstrip('=').strip()
                cleaned[k] = s
            else:
                cleaned[k] = v
        return cleaned

    @field_validator('REDIS_ENABLED', 'DEBUG', 'OTP_EXPOSE_IN_RESPONSE', mode='before')
    @classmethod
    def parse_bool_env(cls, v):
        if isinstance(v, bool):
            return v
        # Strip whitespace, leading/trailing '=' (common copy-paste mistake)
        cleaned = str(v).strip().strip('=').strip().lower()
        return cleaned in ('true', '1', 'yes')

    @field_validator('ALLOWED_ORIGINS')
    @classmethod
    def parse_cors(cls, v):
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v

    @field_validator('SOCKETIO_CORS_ORIGINS')
    @classmethod
    def parse_socketio_cors(cls, v):
        if isinstance(v, str):
            if v.strip() == "*":
                return "*"
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v

    @field_validator('TURN_FALLBACK_ICE_SERVERS')
    @classmethod
    def parse_turn_fallback_servers(cls, v):
        if not isinstance(v, str) or not v.strip():
            return []
        try:
            data = json.loads(v)
            if isinstance(data, list):
                return data
        except Exception:
            return []
        return []
    
    # Pricing Configuration
    BASE_RATE_MULTIPLIER: float = float(os.getenv("BASE_RATE_MULTIPLIER", "1.0"))
    DISTANCE_RATE_PER_KM: float = float(os.getenv("DISTANCE_RATE_PER_KM", "5.0"))
    MINIMUM_CHARGE: float = float(os.getenv("MINIMUM_CHARGE", "100.0"))
    
    # Service Types
    SERVICE_TYPES: List[str] = [
        "Sand Trolley",
        "Bricks Trolley",
        "Harvester",
        "Crane",
        "Excavator",
        "Bulldozer",
        "Concrete Mixer",
        "Dumper Truck",
    ]
    
    # Base Rates for Services
    BASE_RATES: dict = {
        "Sand Trolley": 50.0,
        "Bricks Trolley": 60.0,
        "Harvester": 150.0,
        "Crane": 200.0,
        "Excavator": 180.0,
        "Bulldozer": 170.0,
        "Concrete Mixer": 80.0,
        "Dumper Truck": 100.0,
    }
    
    # Booking Status
    STATUS_PENDING: str = "pending"
    STATUS_ACCEPTED: str = "accepted"
    STATUS_IN_PROGRESS: str = "in_progress"
    STATUS_COMPLETED: str = "completed"
    STATUS_CANCELLED: str = "cancelled"
    
    # User Roles
    ROLE_SEEKER: str = "seeker"
    ROLE_PROVIDER: str = "provider"
    
    # Storage Configuration
    MAX_IMAGE_SIZE_MB: int = 5
    ALLOWED_IMAGE_EXTENSIONS: str = "jpg,jpeg,png,webp"
    
    @field_validator('ALLOWED_IMAGE_EXTENSIONS')
    @classmethod
    def parse_extensions(cls, v):
        if isinstance(v, str):
            return [ext.strip() for ext in v.split(",")]
        return v
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore extra fields in .env file


# Create settings instance
settings = Settings()

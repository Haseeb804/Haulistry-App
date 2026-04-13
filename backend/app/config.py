import os
from typing import List
from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import field_validator
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
    OTP_DELIVERY_MODE: str = "debug"  # debug | android_gateway
    OTP_MESSAGE_TEMPLATE: str = "{app_name} verification code: {otp}. It expires in {minutes} minutes."

    # Android phone SMS gateway configuration (free/self-hosted option)
    ANDROID_SMS_GATEWAY_URL: str = ""
    ANDROID_SMS_GATEWAY_API_KEY: str = ""
    ANDROID_SMS_GATEWAY_AUTH_HEADER: str = "X-API-KEY"
    SMS_HTTP_TIMEOUT_SECONDS: int = 15
    
    # Neo4j Configuration
    NEO4J_URI: str = os.getenv("NEO4J_URI") or os.getenv("NEO4J_URL") or "bolt://localhost:7687"
    NEO4J_USERNAME: str = os.getenv("NEO4J_USERNAME") or os.getenv("NEO4J_USER") or "neo4j"
    NEO4J_PASSWORD: str = "password"
    NEO4J_DATABASE: str = "neo4j"
    
    # Firebase Configuration
    FIREBASE_CREDENTIALS_PATH: str = "./serviceAccountKey.json"
    
    # CORS Configuration
    ALLOWED_ORIGINS: str = "*"
    
    @field_validator('ALLOWED_ORIGINS')
    @classmethod
    def parse_cors(cls, v):
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v
    
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

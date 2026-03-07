from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette_graphene3 import GraphQLApp, make_graphiql_handler
import uvicorn
from typing import Optional
import logging

from .config import settings
from .database import neo4j_driver
from .graphql.schema import schema
from .controllers import api_router
from .services.websocket_manager import manager, WSMessageType, create_ws_message

# Configure logging with cleaner format
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s:     %(message)s' if not settings.DEBUG else '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Suppress verbose third-party library logs
logging.getLogger('neo4j').setLevel(logging.WARNING)
logging.getLogger('neo4j.pool').setLevel(logging.WARNING)
logging.getLogger('neo4j.io').setLevel(logging.WARNING)
logging.getLogger('neo4j.notifications').setLevel(logging.ERROR)  # Only show errors for notifications
logging.getLogger('urllib3').setLevel(logging.WARNING)
logging.getLogger('cachecontrol').setLevel(logging.WARNING)
logging.getLogger('graphql').setLevel(logging.WARNING)

# Application logger
logger = logging.getLogger(__name__)
if settings.DEBUG:
    logger.setLevel(logging.DEBUG)


# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    debug=settings.DEBUG,
)

# Add validation error handler
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()}
    )

# Configure CORS - Must be before other middleware
# Use allow_origin_regex to allow all origins (works better with credentials)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=".*",  # Allow all origins via regex
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods (GET, POST, PUT, DELETE, OPTIONS, etc.)
    allow_headers=["*"],  # Allow all headers
    expose_headers=["*"],  # Expose all headers to the client
    max_age=3600,  # Cache preflight requests for 1 hour
)


# Include REST API routers
app.include_router(api_router)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    neo4j_status = neo4j_driver.verify_connectivity()
    
    return {
        "status": "healthy" if neo4j_status else "degraded",
        "version": settings.VERSION,
        "database": {
            "neo4j": "connected" if neo4j_status else "disconnected"
        }
    }


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": f"Welcome to {settings.APP_NAME}",
        "version": settings.VERSION,
        "graphql_endpoint": "/graphql",
        "rest_api_docs": "/docs",
        "graphiql_endpoint": "/graphql (GET request for GraphiQL interface)"
    }


# GraphQL endpoint - Use add_route to avoid 307 redirects
graphql_app = GraphQLApp(
    schema=schema,
    on_get=make_graphiql_handler()  # Enable GraphiQL interface
)

app.add_route("/graphql", graphql_app)
app.add_route("/graphql/", graphql_app)  # Also handle trailing slash


# ============================================
# WEBSOCKET ENDPOINT FOR REAL-TIME FEATURES
# ============================================

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    user_id: str,
    role: str = Query("seeker", description="User role: seeker or provider"),
    token: Optional[str] = Query(None, description="Auth token for verification")
):
    """
    WebSocket endpoint for real-time communication
    
    Features:
    - Booking request broadcasts to providers
    - Fare offer notifications
    - Negotiation updates
    - Live location sharing
    - Booking status updates
    
    Message Types (receive from client):
    - ping: Keep-alive ping
    - location_update: Share location during active booking
    - subscribe_category: Provider subscribes to a service category
    - unsubscribe_category: Provider unsubscribes from a category
    - join_booking: Join a booking room for location sharing
    - leave_booking: Leave a booking room
    """
    # Token verification can be added when needed by validating the token parameter
    # against Firebase Auth or JWT tokens
    
    await manager.connect(websocket, user_id, role)
    
    try:
        while True:
            # Receive messages from client
            data = await websocket.receive_json()
            message_type = data.get("type", "")
            
            if message_type == WSMessageType.PING:
                # Respond to ping with pong
                await websocket.send_json({
                    "type": WSMessageType.PONG,
                    "timestamp": data.get("timestamp")
                })
            
            elif message_type == WSMessageType.LOCATION_UPDATE:
                # Handle location update during active booking
                booking_id = data.get("bookingId")
                if booking_id:
                    # Broadcast to other user in the booking
                    await manager.broadcast_to_booking_room(
                        booking_id,
                        create_ws_message(
                            WSMessageType.LOCATION_UPDATE,
                            {
                                "userId": user_id,
                                "latitude": data.get("latitude"),
                                "longitude": data.get("longitude"),
                                "heading": data.get("heading"),
                                "speed": data.get("speed")
                            },
                            booking_id=booking_id,
                            sender_id=user_id
                        ),
                        exclude_user=user_id
                    )
            
            elif message_type == "subscribe_category":
                # Provider subscribes to service category
                category = data.get("category")
                if category:
                    manager.subscribe_to_category(user_id, category)
                    await websocket.send_json({
                        "type": WSMessageType.ACK,
                        "message": f"Subscribed to {category}"
                    })
            
            elif message_type == "unsubscribe_category":
                # Provider unsubscribes from category
                category = data.get("category")
                if category:
                    manager.unsubscribe_from_category(user_id, category)
                    await websocket.send_json({
                        "type": WSMessageType.ACK,
                        "message": f"Unsubscribed from {category}"
                    })
            
            elif message_type == "join_booking":
                # User joins a booking room
                booking_id = data.get("bookingId")
                if booking_id:
                    manager.join_booking_room(booking_id, user_id)
                    await websocket.send_json({
                        "type": WSMessageType.ACK,
                        "message": f"Joined booking room {booking_id}"
                    })
            
            elif message_type == "leave_booking":
                # User leaves a booking room
                booking_id = data.get("bookingId")
                if booking_id:
                    manager.leave_booking_room(booking_id, user_id)
                    await websocket.send_json({
                        "type": WSMessageType.ACK,
                        "message": f"Left booking room {booking_id}"
                    })
            
            else:
                # Unknown message type
                await websocket.send_json({
                    "type": WSMessageType.ERROR,
                    "message": f"Unknown message type: {message_type}"
                })
    
    except WebSocketDisconnect:
        manager.disconnect(user_id)
    except Exception as e:
        manager.disconnect(user_id)


# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize connections on startup"""
    # Verify Neo4j connection
    if neo4j_driver.verify_connectivity():
        logger.info("Neo4j connection successful")
    else:
        logger.warning("Neo4j connection failed")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    neo4j_driver.close()
def main():
    """Run the application"""
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info" if not settings.DEBUG else "debug",
    )


if __name__ == "__main__":
    main()

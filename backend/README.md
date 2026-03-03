# Haulistry Backend - Python GraphQL Server with Neo4j

A robust backend service for the Haulistry platform built with Python, GraphQL, and Neo4j.

## Tech Stack

- **Python 3.10+**
- **GraphQL** (Graphene)
- **Neo4j Aura** (Graph Database)
- **FastAPI** (Web Framework)
- **Firebase Admin** (Authentication)

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                 # Application entry point
│   ├── config.py               # Configuration management
│   ├── models/                 # Data models
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── vehicle.py
│   │   └── booking.py
│   ├── controllers/            # Business logic (MVC)
│   │   ├── __init__.py
│   │   ├── user_controller.py
│   │   ├── vehicle_controller.py
│   │   └── booking_controller.py
│   ├── graphql/                # GraphQL schema and resolvers
│   │   ├── __init__.py
│   │   ├── schema.py
│   │   ├── types.py
│   │   ├── queries.py
│   │   └── mutations.py
│   ├── database/               # Database connection and utilities
│   │   ├── __init__.py
│   │   └── neo4j_driver.py
│   ├── middleware/             # Authentication and middleware
│   │   ├── __init__.py
│   │   └── auth.py
│   └── utils/                  # Utility functions
│       ├── __init__.py
│       └── helpers.py
├── requirements.txt
├── .env.example
└── README.md
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Environment Configuration

Create a `.env` file:

```env
NEO4J_URI=neo4j+s://your-instance.databases.neo4j.io
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_password

FIREBASE_CREDENTIALS_PATH=path/to/serviceAccountKey.json

SECRET_KEY=your_secret_key
DEBUG=True
HOST=0.0.0.0
PORT=4000
```

### 3. Run the Server

```bash
python -m app.main
```

Server will be available at: `http://localhost:4000/graphql`

## GraphQL Endpoints

### Queries

- `getUser(id: ID!): User`
- `getAllServices: [Service]`
- `getBooking(id: ID!): Booking`
- `getUserBookings(userId: ID!): [Booking]`
- `getAvailableVehicles(serviceType: String!): [Vehicle]`

### Mutations

- `createUser(input: UserInput!): User`
- `updateUser(id: ID!, input: UserInput!): User`
- `createBooking(input: BookingInput!): Booking`
- `updateBookingStatus(id: ID!, status: String!): Booking`
- `rateProvider(bookingId: ID!, rating: Float!, review: String): Booking`

## Neo4j Graph Model

### Nodes

- `User` (Seeker/Provider)
- `Vehicle`
- `Booking`
- `Service`

### Relationships

- `(User)-[:OWNS]->(Vehicle)`
- `(User)-[:CREATED]->(Booking)`
- `(Provider)-[:ACCEPTED]->(Booking)`
- `(Booking)-[:USES]->(Vehicle)`
- `(Booking)-[:FOR]->(Service)`

## Development

### Running Tests

```bash
pytest
```

### Code Formatting

```bash
black app/
flake8 app/
```

### Logging Configuration

The application uses Python's built-in logging system with configurable levels:

**Clean Production Logs (Default)**
- Set `DEBUG=False` in `.env`
- Shows only INFO, WARNING, and ERROR messages
- Clean format without timestamps
- Suppresses verbose third-party library logs (Neo4j, urllib3, etc.)

**Verbose Debug Logs**
- Set `DEBUG=True` in `.env`
- Shows all DEBUG messages with timestamps
- Includes detailed logs from Neo4j driver and other libraries
- Useful for troubleshooting connection issues

**Example Output (DEBUG=False)**
```
INFO:     Uvicorn running on http://127.0.0.1:4000
INFO:     Neo4j connection successful
INFO:     Application startup complete
```

**Example Output (DEBUG=True)**
```
2026-02-21 16:24:59,484 - neo4j - DEBUG - [#0000] resolve home database
2026-02-21 16:25:01,378 - app.main - INFO - Neo4j connection successful
INFO:     Application startup complete
```

**Control Logging Levels**
```env
DEBUG=False        # Toggle verbose logging
LOG_LEVEL=INFO     # Options: DEBUG, INFO, WARNING, ERROR
```

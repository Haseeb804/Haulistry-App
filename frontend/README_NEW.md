# 🚛 Haulistry - Service Platform for Construction & Agriculture

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![Neo4j](https://img.shields.io/badge/Neo4j-Aura-008CC1?logo=neo4j)](https://neo4j.com)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase)](https://firebase.google.com)
[![GraphQL](https://img.shields.io/badge/GraphQL-E10098?logo=graphql)](https://graphql.org)

A comprehensive service-based platform connecting service providers with customers in the construction and agriculture industries. Built with Flutter, Python, GraphQL, and Neo4j.

---

## 🌟 Features

### For Service Seekers
- 🔍 Browse and book construction/agriculture services
- 📍 Real-time location tracking
- 💰 Dynamic pricing based on distance and vehicle type
- ⭐ Rate and review service providers
- 📜 View booking history
- 💬 In-app communication with providers

### For Service Providers
- 📄 Document verification system
- 🚜 Manage multiple vehicles
- 📊 Track earnings and bookings
- 🔔 Real-time booking notifications
- 🗺️ Navigation to pickup/drop locations
- ⚡ Accept/reject booking requests

### Services Offered
- Sand Trolley
- Bricks Trolley
- Harvester
- Crane
- Excavator
- Bulldozer
- Concrete Mixer
- Dumper Truck

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.x with BLoC |
| **Backend** | Python 3.10+ with FastAPI |
| **API** | GraphQL (Graphene) |
| **Database** | Neo4j Aura (Graph DB) |
| **Auth** | Firebase Authentication |
| **Storage** | Firebase Storage & Firestore |
| **Maps** | Google Maps Flutter |
| **Architecture** | Clean Architecture (Frontend), MVC (Backend) |

---

## 📁 Project Structure

```
FYP/
├── lib/                    # Flutter frontend
│   ├── core/              # Core utilities, constants, theme
│   ├── features/          # Feature modules (auth, booking, etc.)
│   └── main.dart          # App entry point
├── backend/               # Python backend
│   ├── app/
│   │   ├── models/       # Data models
│   │   ├── controllers/  # Business logic (MVC)
│   │   ├── graphql/      # GraphQL schema
│   │   └── database/     # Neo4j connection
│   └── requirements.txt
├── android/              # Android configuration
├── ios/                  # iOS configuration
└── assets/              # Images, fonts, animations
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Python 3.10+
- Neo4j Aura account
- Firebase project

### Setup in 3 Steps

1. **Install Dependencies**
```bash
# Flutter
flutter pub get

# Python
cd backend
pip install -r requirements.txt
```

2. **Configure Environment**
- Add Firebase config files
- Create `backend/.env` from `.env.example`
- Set Neo4j credentials

3. **Run**
```bash
# Backend
python -m app.main

# Flutter
flutter run
```

📖 **Detailed setup guide**: See [QUICK_START.md](QUICK_START.md)

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [QUICK_START.md](QUICK_START.md) | Step-by-step setup guide |
| [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) | Complete technical documentation |
| [FEATURE_STATUS.md](FEATURE_STATUS.md) | Implementation status & roadmap |
| [backend/README.md](backend/README.md) | Backend-specific documentation |

---

## 🎯 Key Features Implemented

✅ User authentication (Seeker & Provider)  
✅ Document verification for providers  
✅ Vehicle management  
✅ Booking system with status tracking  
✅ Dynamic pricing calculator  
✅ Rating and review system  
✅ GraphQL API with 15+ queries/mutations  
✅ Neo4j graph database integration  
✅ Clean architecture with BLoC pattern  
✅ Modern Material Design 3 UI  

---

## 🔌 API Example

### Create a Booking
```graphql
mutation {
  createBooking(input: {
    seekerId: "user123"
    serviceType: "Sand Trolley"
    pickupLatitude: 31.5204
    pickupLongitude: 74.3587
    pickupAddress: "Liberty Market, Lahore"
    dropLatitude: 31.4697
    dropLongitude: 74.2728
    dropAddress: "Fortress Stadium, Lahore"
    distanceInKm: 12.5
    estimatedPrice: 162.5
  }) {
    booking {
      id
      status
      estimatedPrice
    }
    success
    message
  }
}
```

---

## 💰 Pricing System

**Formula**: `Base Rate + (Distance × Rate/km) + Hourly Charges + Surcharges`

**Example**: Sand Trolley for 10 km
- Base Rate: PKR 50
- Distance: PKR 50 (10 × 5)
- **Total**: PKR 100

**Surcharges**:
- Urgent requests: +20%
- Night time (8PM-6AM): +15%

---

## 🗺️ Graph Database Schema

```cypher
# Nodes
(User:Seeker|Provider)
(Vehicle)
(Booking)

# Relationships
(Provider)-[:OWNS]->(Vehicle)
(Seeker)-[:CREATED]->(Booking)
(Provider)-[:ACCEPTED]->(Booking)
(Booking)-[:USES]->(Vehicle)
```

---

## 📱 Screenshots

*Coming soon - App screenshots will be added here*

---

## 🧪 Testing

```bash
# Flutter tests
flutter test

# Backend tests
pytest
```

---

## 📦 Build for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 🔒 Security Features

- Firebase Authentication
- Secure token management
- Input validation
- HTTPS/WSS encryption
- Document verification
- Role-based access control

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📄 License

This project is part of a Final Year Project (FYP).

---

## 🎓 Academic Project

**Course**: Final Year Project  
**Institution**: [Your University Name]  
**Year**: 2025-2026  

---

## 📞 Contact

For questions or support:
- Email: support@haulistry.com
- Create an issue in this repository

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Neo4j for graph database technology
- Firebase for backend services
- Open source community

---

## 📈 Project Status

**Current Version**: 1.0.0  
**Status**: Active Development  
**Completion**: ~35%  

See [FEATURE_STATUS.md](FEATURE_STATUS.md) for detailed progress.

---

**Built with ❤️ using Flutter & Python**

---

*Last Updated: January 15, 2026*

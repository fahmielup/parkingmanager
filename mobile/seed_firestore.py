"""
Firestore seeding script for the Parking Shuttle mobile app.

Usage:
    python seed_firestore.py

Requirements:
    pip install firebase-admin

Before running, place your Firebase service account key at:
    mobile/firebase-service-account.json

To use the Firestore emulator instead of production, set:
    FIRESTORE_EMULATOR_HOST=localhost:8080
    GOOGLE_CLOUD_PROJECT=your-project-id
"""

import os
import firebase_admin
from firebase_admin import credentials, firestore


def init_firebase():
    """Initialize the Firebase Admin SDK."""
    if firebase_admin._apps:
        return

    sa_path = os.path.join(os.path.dirname(__file__), "firebase-service-account.json")
    if os.path.exists(sa_path):
        cred = credentials.Certificate(sa_path)
        firebase_admin.initialize_app(cred)
    else:
        # Assumes GOOGLE_APPLICATION_CREDENTIALS is set in the environment.
        firebase_admin.initialize_app()


def seed_company_vehicles(db):
    """Seed the company_vehicles collection with two mock vans."""
    vehicles = [
        {"model": "Toyota HiAce", "plateNumber": "WUX 8842", "status": "Available"},
        {"model": "Nissan Urvan", "plateNumber": "VCH 1193", "status": "Available"},
    ]

    batch = db.batch()
    for v in vehicles:
        doc = db.collection("company_vehicles").document()
        batch.set(doc, v)
    batch.commit()
    print(f"Seeded {len(vehicles)} vehicles into 'company_vehicles'.")


def seed_staff_attendance(db):
    """Create a sample active staff attendance record."""
    from firebase_admin import firestore as fs
    doc = db.collection("staff_attendance").document()
    doc.set({
        "driverName": "Ahmad",
        "timestamp": fs.SERVER_TIMESTAMP,
        "vehicleInfo": "Toyota HiAce (WUX 8842)",
        "status": "Active",
    })
    print("Seeded sample record into 'staff_attendance'.")


def seed_shuttle_requests(db):
    """Create a sample pending shuttle request with dummy coordinates."""
    from firebase_admin import firestore as fs
    doc = db.collection("shuttle_requests").document()
    doc.set({
        "customerName": "Siti",
        "carPlate": "JKG 1234",
        "parkingZone": "Zone A",
        "parkingPlanType": "Plan Harian",
        "status": "pending",
        "driverVehicle": "",
        "timestamp": fs.SERVER_TIMESTAMP,
        "currentLat": 1.4928,
        "currentLng": 103.7415,
    })
    print("Seeded sample record into 'shuttle_requests'.")


def seed_chat_channels(db):
    """Ensure the three chat channels exist."""
    from firebase_admin import firestore as fs
    channels = ["customer_admin", "driver_admin", "customer_driver"]
    for channel in channels:
        db.collection("chats").document(channel).set(
            {"createdAt": fs.SERVER_TIMESTAMP}, merge=True
        )
    print(f"Ensured chat channels exist: {channels}.")


def main():
    init_firebase()
    db = firestore.client()

    seed_company_vehicles(db)
    seed_staff_attendance(db)
    seed_shuttle_requests(db)
    seed_chat_channels(db)

    print("Firestore seeding complete.")


if __name__ == "__main__":
    main()

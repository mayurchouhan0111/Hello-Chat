import firebase_admin
from firebase_admin import credentials, firestore
import os

def seed_svga_gifts():
    print("Initializing Firebase Admin SDK for Firestore seeding...")
    
    cert_path = os.path.join("scripts", "service-account-key.json")
    if not os.path.exists(cert_path):
        print(f"Error: Firebase service account key not found at {cert_path}")
        return

    try:
        # Initialize firebase app if not already initialized
        if not firebase_admin._apps:
            cred = credentials.Certificate(cert_path)
            firebase_admin.initialize_app(cred)

        db = firestore.client()

        svga_gifts = [
            {
                'id': 'mystic_rings',
                'name': 'Mystic Rings',
                'priceInDiamonds': 1200,
                'category': 'Vip',
                'imageUrl': '💍',
                'lottieAssetPath': 'https://res.cloudinary.com/dceh4ob2i/raw/upload/v1779870996/gifts/animations/qwvmyhkpv9huodaly5fd.svga',
                'isActive': True,
                'sortOrder': 11
            },
            {
                'id': 'royal_carriage',
                'name': 'Royal Carriage',
                'priceInDiamonds': 8000,
                'category': 'Luxury',
                'imageUrl': '🎠',
                'lottieAssetPath': 'https://res.cloudinary.com/dceh4ob2i/raw/upload/v1779870999/gifts/animations/re6l3nozgkdjpe1lpiii.svga',
                'isActive': True,
                'sortOrder': 12
            },
            {
                'id': 'crystal_palace',
                'name': 'Crystal Palace',
                'priceInDiamonds': 15000,
                'category': 'Luxury',
                'imageUrl': '🏰',
                'lottieAssetPath': 'https://storage.googleapis.com/hellochat-e8965.firebasestorage.app/gifts/animations/crystal_palace.svga',
                'isActive': True,
                'sortOrder': 13
            }
        ]

        print("Seeding new premium SVGA gifts to Firestore 'gifts' collection...")
        
        for g in svga_gifts:
            gift_id = g['id']
            # We want to create or overwrite the gift in the 'gifts' collection
            doc_ref = db.collection('gifts').document(gift_id)
            
            gift_data = {
                'giftId': gift_id,
                'name': g['name'],
                'priceInDiamonds': g['priceInDiamonds'],
                'category': g['category'].lower(), # Match lower case schema in getGiftsStream
                'imageUrl': g['imageUrl'],
                'lottieAssetPath': g['lottieAssetPath'],
                'sortOrder': g['sortOrder'],
                'isActive': g['isActive'],
                'createdAt': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
            
            doc_ref.set(gift_data, merge=True)
            print(f"  Successfully seeded: {g['name']} (ID: {gift_id}, Price: {g['priceInDiamonds']} diamonds)")

        print("\nAll premium SVGA gifts seeded successfully to Firestore!")

    except Exception as e:
        print(f"Error seeding Firestore: {e}")

if __name__ == "__main__":
    seed_svga_gifts()

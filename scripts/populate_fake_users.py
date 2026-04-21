import firebase_admin
from firebase_admin import credentials, firestore
import random
import time

# 🔑 INITIALIZE FIREBASE
# Make sure you have your serviceAccountKey.json in the same directory!
try:
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase Connected Successfully")
except Exception as e:
    print(f"❌ Initialization Error: {e}")
    print("💡 Tip: Ensure 'serviceAccountKey.json' exists in this folder.")
    exit()

# 🎭 USER PERSONAS
personas = [
    {"name": "Zane Storm", "bio": "Competitive gamer | PK King 👑", "tag": "Elite"},
    {"name": "Luna Moonlight", "bio": "Singing and spreading vibes ✨", "tag": "Star"},
    {"name": "Arjun Rao", "bio": "Tech enthusiast & late-night talker 🎙️", "tag": "Host"},
    {"name": "Sarah Jenkins", "bio": "Lifestyle blogger | New to Hello Chat! 🥂", "tag": "Newbie"},
    {"name": "Kaito Vlogs", "bio": "Anime & J-Pop lover 🇯🇵", "tag": "Otaku"}
]

uids = []

def create_fake_users():
    print(f"🚀 Creating {len(personas)} Realistic Users...")
    
    for i, p in enumerate(personas):
        uid = f"fake_user_{int(time.time())}_{i}"
        username = p['name'].lower().replace(" ", "_") + str(random.randint(10, 99))
        
        user_data = {
            "uid": uid,
            "username": username,
            "username_lowercase": username.lower(),
            "displayName": p['name'],
            "displayName_lowercase": p['name'].lower(),
            "bio": p[ 'bio'],
            "diamondBalance": random.randint(500, 5000),
            "beansBalance": random.randint(100, 2000),
            "followerCount": 0,
            "followingCount": 0,
            "friendsCount": 0,
            "level": random.randint(5, 25),
            "profilePhotoUrl": f"https://api.dicebear.com/7.x/avataaars/png?seed={username}",
            "tags": [p['tag'], "Verified"],
            "status": "online",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "vipTier": "Gold" if i == 0 else "none"
        }
        
        # Save to Users collection
        db.collection("users").doc(uid).set(user_data)
        
        # Save to Usernames index
        db.collection("usernames").doc(username).set({"uid": uid})
        
        uids.append(uid)
        print(f"   👤 Added: {p['name']} (@{username})")

def setup_relationships():
    print("\n🤝 Establishing 'Following' Relationships (to enable PK)...")
    
    # Make everyone follow everyone to ensure PK works for all fake accounts
    for follower in uids:
        for target in uids:
            if follower == target: continue
            
            timestamp = firestore.SERVER_TIMESTAMP
            
            # Add to sub-collections
            db.collection("users").doc(follower).collection("following").doc(target).set({"followedAt": timestamp})
            db.collection("users").doc(target).collection("followers").doc(follower).set({"followedAt": timestamp})
            
            # Increment counts (Basic update)
            db.collection("users").doc(follower).update({"followingCount": firestore.Increment(1)})
            db.collection("users").doc(target).update({"followerCount": firestore.Increment(1)})
            
    print("✅ Relationships Synced (Following-Only PK now active for these users)")

if __name__ == "__main__":
    create_fake_users()
    setup_relationships()
    print("\n🎉 Ecosystem Population Complete! You can now log in with these IDs or simulate PKs.")

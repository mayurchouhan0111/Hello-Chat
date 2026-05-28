import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

docs = db.collection('users').limit(5).stream()
for doc in docs:
    data = doc.to_dict()
    print(f"User: {doc.id}, Level: {data.get('level')}, XP: {data.get('xp')}, Diamond Spent: {data.get('totalDiamondsSpent')}")

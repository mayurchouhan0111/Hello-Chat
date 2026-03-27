import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

// Replace with your Firebase Config (from Firebase Console)
const firebaseConfig = {
  apiKey: "AIzaSyDlt3B1TB0jY4nZfwkfObYOdLCBktFtnPQ",
  authDomain: "hellochat-e8965.firebaseapp.com",
  projectId: "hellochat-e8965",
  storageBucket: "hellochat-e8965.firebasestorage.app",
  messagingSenderId: "657653942476",
  appId: "1:657653942476:web:c5043565cf484339239a69" // Inferred from android ID
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

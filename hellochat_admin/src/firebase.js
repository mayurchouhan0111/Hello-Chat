import { initializeApp } from "firebase/app";
import { getAuth, connectAuthEmulator } from "firebase/auth";
import { getFirestore, connectFirestoreEmulator } from "firebase/firestore";
import { getStorage, connectStorageEmulator } from "firebase/storage";
import { getFunctions, connectFunctionsEmulator } from "firebase/functions";

// Replace with your Firebase Config (from Firebase Console)
const firebaseConfig = {
  apiKey: "AIzaSyDlt3B1TB0jY4nZfwkfObYOdLCBktFtnPQ",
  authDomain: "hellochat-e8965.firebaseapp.com",
  projectId: "hellochat-e8965",
  storageBucket: "hellochat-e8965.firebasestorage.app",
  messagingSenderId: "657653942476",
  appId: "1:657653942476:web:c5043565cf484339239a69" // Inferred from android ID
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const functions = getFunctions(app);

// Test-only: VITE_USE_EMULATOR=1 npx vite --port 5174
// Inlined away entirely when the var is unset, so production is unaffected.
if (import.meta.env.VITE_USE_EMULATOR) {
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  connectFirestoreEmulator(db, "127.0.0.1", 8085);
  connectStorageEmulator(storage, "127.0.0.1", 9199);
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
}

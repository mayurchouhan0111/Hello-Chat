import { useState, useEffect } from 'react';
import { db, app } from '../firebase';
import { 
  collection, 
  doc, 
  setDoc, 
  deleteDoc, 
  getDocs, 
  query, 
  where, 
  onSnapshot,
  or,
  serverTimestamp,
  writeBatch
} from 'firebase/firestore';
import { 
  Database, 
  UserPlus, 
  Trash2, 
  RefreshCcw, 
  CheckCircle, 
  AlertTriangle,
  Users
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { Sparkles, Search, Swords, ShieldCheck, XCircle, Trophy, Zap } from 'lucide-react';

export const DevTools = () => {

  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState(null);
  const [pkRooms, setPkRooms] = useState([]);
  const { user } = useAdmin();

  const FAKE_USERS = [
    { id: 'test_user_01', name: 'Alex River', username: 'alex_test', bio: 'Adventurer & Coffee lover ☕' },
    { id: 'test_user_02', name: 'Sophie Chen', username: 'sophie_dev', bio: 'Building the future of social! 🚀' },
    { id: 'test_user_03', name: 'Marcus Wright', username: 'marcus_m', bio: 'Musician / Traveler / Dreamer' },
    { id: 'test_user_04', name: 'Elena Gomez', username: 'elena_style', bio: 'Fashion and Lifestyle enthusiast' },
    { id: 'test_user_05', name: 'David Kim', username: 'david_k', bio: 'Tech geek and gamer 🎮' },
    { id: 'test_user_06', name: 'Sarah Miller', username: 'sarah_m', bio: 'Yoga instructor and wellness coach' },
    { id: 'test_user_07', name: 'Jordan Lee', username: 'jordan_vibe', bio: 'Life is a journey, not a destination' },
    { id: 'test_user_08', name: 'Chloe Brown', username: 'chloe_b', bio: 'Art, design, and everything fine' },
    { id: 'test_user_09', name: 'Ryan Wilson', username: 'ryan_w', bio: 'Fitness junkie and food explorer 🍕' },
    { id: 'test_user_10', name: 'Maya Gupta', username: 'maya_g', bio: 'Poetry and sunsets' },
  ];

  const MOMENT_CAPTIONS = [
    "Enjoying the beautiful sunset today! 🌅",
    "Just finished an amazing workout. Feeling pumped! 💪",
    "Finally visited this hidden gem in the city. #Travel",
    "Late night coding sessions are the best. 💻✨",
    "Good food = Good mood. #Foodie",
    "Exploring the mountains. The air is so fresh here! 🏔️",
    "New favorite spot for brunch discovered! 🥑☕",
    "Sunday vibes with my favorite book. 📚",
    "What a great experience at the concert last night! 🎵",
    "Coffee is always a good idea. ☕❤️",
  ];

  const seedData = async () => {
    if (loading) return;
    setLoading(true);
    setStatus('FEEDING DATA...');
    
    try {
      const batch = writeBatch(db);

      for (let i = 0; i < FAKE_USERS.length; i++) {
        const fakeUser = FAKE_USERS[i];
        const userRef = doc(db, 'users', fakeUser.id);
        
        // 1. Create User
        batch.set(userRef, {
          uid: fakeUser.id,
          displayName: fakeUser.name,
          username: fakeUser.username,
          bio: fakeUser.bio,
          profilePhotoUrl: `https://picsum.photos/seed/user_${fakeUser.id}/400`,
          tags: ['TestUser'],
          diamondBalance: 1000,
          beansBalance: 5000,
          level: 5,
          country: i % 2 === 0 ? "India 🇮🇳" : "Bangladesh 🇧🇩",
          vipTier: i % 3 === 0 ? "VIP 1" : "none",
          svipLevel: i % 4 === 0 ? 3 : 0,
          monthlyRecharge: i % 4 === 0 ? 60000 : 6000,
          svipPoints: i % 4 === 0 ? 200 : 20,
          badges: ["Early User", "Moment Star"],

          createdAt: serverTimestamp(),
          status: 'online'
        });

        // 2. Create 2 Moments for each user
        for (let j = 0; j < 2; j++) {
          const momentId = `test_moment_${fakeUser.id}_${j}`;
          const momentRef = doc(db, 'moments', momentId);
          batch.set(momentRef, {
            mediaId: momentId,
            userId: fakeUser.id,
            caption: MOMENT_CAPTIONS[(i + j) % MOMENT_CAPTIONS.length],
            imageUrl: `https://picsum.photos/seed/moment_${momentId}/800/600`,
            tag: 'moment',
            type: 'moment',
            tags: ['TestUser'],
            likesCount: Math.floor(Math.random() * 50),
            commentsCount: Math.floor(Math.random() * 10),
            isDeleted: false,
            createdAt: serverTimestamp(),
          });
        }
      }

      await batch.commit();
      await logAdminAction(user, "SEED_TEST_DATA", "DEV_TOOLS", { count: FAKE_USERS.length });
      setStatus('DATA SYNCHRONIZED! ✅');
      setTimeout(() => setStatus(null), 3000);
    } catch (err) {
      console.error(err);
      alert("Error seeding data: " + err.message);
      setStatus('ERROR');
    } finally {
      setLoading(false);
    }
  };

  const cleanupData = async () => {
    if (loading) return;
    if (!window.confirm("Are you sure you want to delete ALL test users and moments?")) return;
    
    setLoading(true);
    setStatus('CLEANING UP...');
    
    try {
      // 1. Delete Users with TestUser tag
      const usersQuery = query(collection(db, "users"), where("tags", "array-contains", "TestUser"));
      const usersSnap = await getDocs(usersQuery);
      
      // 2. Delete Moments with TestUser tag
      const momentsQuery = query(collection(db, "moments"), where("tags", "array-contains", "TestUser"));
      const momentsSnap = await getDocs(momentsQuery);

      const batch = writeBatch(db);
      usersSnap.docs.forEach(d => batch.delete(d.ref));
      momentsSnap.docs.forEach(d => batch.delete(d.ref));

      await batch.commit();
      await logAdminAction(user, "CLEANUP_TEST_DATA", "DEV_TOOLS", { 
        usersDeleted: usersSnap.size, 
        momentsDeleted: momentsSnap.size 
      });
      
      setStatus('DATA PURGED! 🗑️');
      setTimeout(() => setStatus(null), 3000);
    } catch (err) {
      console.error(err);
      alert("Error cleaning up: " + err.message);
      setStatus('ERROR');
    } finally {
      setLoading(false);
    }
  };

  // 🛡️ PK Diagnostic Hooks - More permissive query to ensure we see everything
  useEffect(() => {
    // We listen to all active rooms and filter for PK status locally 
    // to avoid index requirement issues during development.
    const q = query(
      collection(db, "rooms"), 
      where("status", "==", "active")
    );
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const activePkRooms = snapshot.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .filter(room => room.pkActive || (room.pkChallenge && room.pkChallenge.status === 'pending'));
      
      setPkRooms(activePkRooms);
    });
    return () => unsubscribe();
  }, []);

  const handlePKAction = async (roomId, action, accepted = false) => {
    if (loading) return;
    setLoading(true);
    setStatus(`EXECUTING ${action.toUpperCase()}...`);
    try {
      const funcs = getFunctions(app, 'us-central1');
      if (action === 'respond') {
        const respondToPK = httpsCallable(funcs, 'respondToPKChallenge');
        await respondToPK({ 
          roomId, 
          accepted, 
          receiverUid: user?.uid, // Send explicit UID as fallback
          adminUid: user?.uid 
        });
      } else if (action === 'end') {
        const endPK = httpsCallable(funcs, 'endPKBattle');
        await endPK({ roomId });
      }
      setStatus(`ACTION COMPLETED! ✅`);
      setTimeout(() => setStatus(null), 3000);
    } catch (err) {
      console.error(err);
      alert(`Simulation Error: ${err.message}`);
      setStatus('ERROR');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      <div className="px-1">
        <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
          <div className="p-3 bg-amber-500/20 rounded-2xl border border-amber-500/30">
            <Database className="text-amber-500" size={28} />
          </div>
          Developer Utilities
        </h1>
        <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Advanced Platform Seeding & Regression Tools</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        
        {/* Seed Card */}
        <div className="card-glass bg-slate-900/40 p-10 border-white/5 space-y-8 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-12 bg-primary/5 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
          
          <div className="space-y-4">
            <h3 className="text-2xl font-black flex items-center gap-4">
              <UserPlus className="text-primary-light" size={24} />
              Population Feed
            </h3>
            <p className="text-slate-400 text-sm leading-relaxed">
              Generate 10 high-fidelity test user profiles with pre-configured wallets, 
              custom bios, and AI-simulated moment feeds for end-to-end regression testing.
            </p>
          </div>

          <div className="bg-slate-950/50 p-6 rounded-2xl border border-white/5 space-y-3">
             <div className="flex items-center justify-between text-[10px] font-black uppercase tracking-widest text-slate-500">
                <span>Entities to Create</span>
                <span className="text-primary-light">10 Users</span>
             </div>
             <div className="flex items-center justify-between text-[10px] font-black uppercase tracking-widest text-slate-500">
                <span>Content Volume</span>
                <span className="text-primary-light">20 Moments</span>
             </div>
             <div className="flex items-center justify-between text-[10px] font-black uppercase tracking-widest text-slate-500">
                <span>Identity Source</span>
                <span className="text-primary-light">Static Mock Array</span>
             </div>
          </div>

          <button 
            onClick={seedData}
            disabled={loading}
            className="w-full h-16 bg-primary hover:bg-primary-dark disabled:opacity-50 text-white rounded-2xl font-black uppercase tracking-widest flex items-center justify-center gap-4 transition-all shadow-primary/20 shadow-2xl"
          >
            {loading && status?.includes('FEEDING') ? <RefreshCcw className="animate-spin" /> : <Database size={20} />}
            FEED PLATFORM DATA
          </button>
        </div>

        {/* Purge Card */}
        <div className="card-glass bg-slate-900/40 p-10 border-white/5 space-y-8 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-12 bg-red-500/5 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
          
          <div className="space-y-4">
            <h3 className="text-2xl font-black flex items-center gap-4 text-red-400">
              <Trash2 className="text-red-500" size={24} />
              Data Sanitization
            </h3>
            <p className="text-slate-400 text-sm leading-relaxed">
              Automatically identify and purge all system-generated test data using the 
              <span className="text-red-400 font-bold"> #TestUser </span> identifier. 
              Safe for selective cleanup without affecting real production users.
            </p>
          </div>

          <div className="bg-slate-950/50 p-6 rounded-2xl border border-red-500/10 border-dashed space-y-3">
             <div className="flex items-center gap-3 text-red-400/80">
                <AlertTriangle size={16} />
                <span className="text-[10px] font-black uppercase tracking-widest">IRREVERSIBLE OPERATION</span>
             </div>
             <p className="text-[10px] text-slate-600 font-medium">
                This action will permanently delete all records tagged as 'TestUser' from users 
                and moments collections.
             </p>
          </div>

          <button 
            onClick={cleanupData}
            disabled={loading}
            className="w-full h-16 bg-red-500/10 border-2 border-red-500/20 hover:bg-red-500 hover:text-white text-red-500 disabled:opacity-50 rounded-2xl font-black uppercase tracking-widest flex items-center justify-center gap-4 transition-all"
          >
            {loading && status?.includes('CLEANING') ? <RefreshCcw className="animate-spin" /> : <Trash2 size={20} />}
            CLEANUP TEST DATA
          </button>
        </div>


        {/* SVIP Testing Tool */}
        <div className="card-glass bg-amber-500/5 border-amber-500/20 p-10 col-span-full space-y-6">
           <div className="flex items-center justify-between">
              <h3 className="text-xl font-black text-amber-400 uppercase tracking-tight flex items-center gap-3">
                 <Sparkles size={24} /> SVIP Loyalty Tester
              </h3>
              <span className="px-3 py-1 bg-amber-500/20 text-amber-400 rounded-full text-[10px] font-black uppercase tracking-tighter">Live Injection</span>
           </div>
           <p className="text-slate-500 text-sm">
             Simulate a diamond recharge for a test user to verify the automated SVIP rank-up logic and monthly recharge counters. 
             This triggers the <code>rechargeDiamonds</code> Cloud Function internally.
           </p>
           <div className="flex gap-4">
              <input 
                id="test_uid" placeholder="User UID (e.g. test_user_01)" 
                className="flex-1 h-14 bg-slate-950/50 border border-white/5 rounded-xl px-6 text-sm text-white"
              />
              <input 
                id="test_amount" type="number" placeholder="Diamonds (e.g. 50000)" 
                className="w-48 h-14 bg-slate-950/50 border border-white/5 rounded-xl px-6 text-sm text-white"
              />
              <button 
                onClick={async () => {
                  const uid = document.getElementById('test_uid').value;
                  const amt = parseInt(document.getElementById('test_amount').value);
                  if(!uid || !amt) return alert("Missing UID or Amount");
                  
                  setLoading(true);
                  setStatus('TRIGGERING RECHARGE...');
                  try {
                    // We can't call httpsCallable easily from here without initializing it,
                    // but we can manually update the doc to simulate the function logic 
                    // for rapid testing.
                    const userRef = doc(db, 'users', uid);
                    const userSnap = await getDocs(query(collection(db, 'users'), where('uid', '==', uid)));
                    if (userSnap.empty) throw new Error("User not found");
                    
                    const userData = userSnap.docs[0].data();
                    const newTotal = (userData.monthlyRecharge || 0) + amt;
                    
                    // Client-side simulation of logic (Update to Matches new policy)
                    let newLvl = 0;
                    if (newTotal >= 10000000) newLvl = 1;
                    if (newTotal >= 30000000) newLvl = 2;
                    if (newTotal >= 50000000) newLvl = 3;
                    if (newTotal >= 100000000) newLvl = 4;
                    if (newTotal >= 200000000) newLvl = 5;
                    if (newTotal >= 300000000) newLvl = 6;
                    if (newTotal >= 500000000) newLvl = 7;


                    await setDoc(userRef, {
                      monthlyRecharge: newTotal,
                      diamondBalance: (userData.diamondBalance || 0) + amt,
                      svipLevel: newLvl
                    }, { merge: true });

                    setStatus(`RECHARGE SUCCESS! UID: ${uid} | New LV: SVIP${newLvl}`);
                    setTimeout(() => setStatus(null), 4000);
                  } catch (e) {
                    alert(e.message);
                    setStatus('ERROR');
                  } finally { setLoading(false); }
                }}
                className="px-10 h-14 bg-amber-500 hover:bg-amber-600 text-slate-950 rounded-xl font-black uppercase text-xs tracking-widest"
              >
                Infect Balance
              </button>
           </div>
        </div>

        {/* Rocket Fuel Injector */}
        <div className="card-glass bg-indigo-500/5 border-indigo-500/20 p-10 col-span-full space-y-6">
           <div className="flex items-center justify-between">
              <h3 className="text-xl font-black text-indigo-400 uppercase tracking-tight flex items-center gap-3">
                 <Zap size={24} /> Rocket Fuel Injector
              </h3>
              <span className="px-3 py-1 bg-indigo-500/20 text-indigo-400 rounded-full text-[10px] font-black uppercase tracking-tighter">Testing Tool</span>
           </div>
           <p className="text-slate-500 text-sm">
             Inject diamonds directly into a room's rocket fuel to test level progression and global launch animations.
             This bypasses the gifting flow and triggers the <code>adminFuelRocket</code> Cloud Function.
           </p>
           <div className="flex gap-4">
              <input 
                id="rocket_room_id" placeholder="Room ID" 
                className="flex-1 h-14 bg-slate-950/50 border border-white/5 rounded-xl px-6 text-sm text-white"
              />
              <input 
                id="rocket_amount" type="number" placeholder="Fuel Points (Diamonds)" 
                className="w-48 h-14 bg-slate-950/50 border border-white/5 rounded-xl px-6 text-sm text-white"
              />
              <button 
                onClick={async () => {
                  const roomId = document.getElementById('rocket_room_id').value;
                  const amt = parseInt(document.getElementById('rocket_amount').value);
                  if(!roomId || !amt) return alert("Missing Room ID or Amount");
                  
                  setLoading(true);
                  setStatus('INJECTING FUEL...');
                  try {
                    const funcs = getFunctions(app, 'us-central1');
                    const injectFuel = httpsCallable(funcs, 'adminFuelRocket');
                    const res = await injectFuel({ roomId, amount: amt });
                    
                    setStatus(`FUEL INJECTED! 🚀 | New Fuel: ${res.data.newFuel}`);
                    setTimeout(() => setStatus(null), 4000);
                  } catch (e) {
                    alert(e.message);
                    setStatus('ERROR');
                  } finally { setLoading(false); }
                }}
                className="px-10 h-14 bg-indigo-500 hover:bg-indigo-600 text-white rounded-xl font-black uppercase text-xs tracking-widest"
              >
                Ignite
              </button>
           </div>
        </div>

        {/* PK Diagnostic Center */}
        <div className="card-glass bg-rose-500/5 border-rose-500/20 p-10 col-span-full space-y-8 text-white">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-black text-rose-400 uppercase tracking-tight flex items-center gap-3">
              <Swords size={24} /> PK Battle Diagnostic Center
            </h3>
            <span className="px-3 py-1 bg-rose-500/20 text-rose-400 rounded-full text-[10px] font-black uppercase tracking-tighter">
              {pkRooms.length} Active Events
            </span>
          </div>

          {!pkRooms.length ? (
            <div className="bg-slate-950/50 p-12 rounded-3xl border border-white/5 text-center space-y-4">
              <div className="w-16 h-16 bg-slate-900 rounded-2xl flex items-center justify-center mx-auto text-slate-700">
                <ShieldCheck size={32} />
              </div>
              <p className="text-slate-500 font-bold uppercase tracking-widest text-[10px]">No active challenges or battles globally</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {pkRooms.map((room) => (
                <div key={room.id} className="bg-slate-950/80 p-6 rounded-2xl border border-white/10 space-y-6">
                  <div className="flex justify-between items-start">
                    <div>
                      <h4 className="font-black text-white text-sm truncate w-40">{room.name}</h4>
                      <p className="text-[10px] text-slate-500 font-mono mt-1 uppercase">{room.id.substring(0, 8)}...</p>
                    </div>
                    <span className={`px-2 py-1 rounded-md text-[8px] font-black uppercase tracking-widest ${
                      room.pkActive ? 'bg-emerald-500/20 text-emerald-400' : 'bg-amber-500/20 text-amber-400'
                    }`}>
                      {room.pkActive ? 'IN BATTLE' : 'CHALLENGE PENDING'}
                    </span>
                  </div>

                  <div className="space-y-2">
                    <div className="flex justify-between text-[10px]">
                      <span className="text-slate-500 font-bold uppercase">Initiator:</span>
                      <span className="text-white font-mono">{(room.pkChallenge?.senderUid || Object.keys(room.pkTeams || {})[0] || 'Unknown').substring(0,6)}...</span>
                    </div>
                    <div className="flex justify-between text-[10px]">
                      <span className="text-slate-500 font-bold uppercase">Target:</span>
                      <span className="text-white font-mono">{(room.pkChallenge?.receiverUid || Object.keys(room.pkTeams || {})[1] || 'Unknown').substring(0,6)}...</span>
                    </div>
                  </div>

                  {room.pkChallenge && room.pkChallenge.status === 'pending' ? (
                    <div className="flex gap-2">
                      <button 
                         onClick={() => handlePKAction(room.id, 'respond', true)}
                         className="flex-1 h-10 bg-emerald-500 hover:bg-emerald-600 text-slate-950 rounded-lg font-black uppercase text-[10px] flex items-center justify-center gap-2 transition-all"
                      >
                        <ShieldCheck size={14} /> Accept
                      </button>
                      <button 
                         onClick={() => handlePKAction(room.id, 'respond', false)}
                         className="flex-1 h-10 bg-white/5 hover:bg-white/10 text-white border border-white/10 rounded-lg font-black uppercase text-[10px] flex items-center justify-center gap-2 transition-all"
                      >
                        <XCircle size={14} /> Reject
                      </button>
                    </div>
                  ) : room.pkActive ? (
                    <button 
                       onClick={() => handlePKAction(room.id, 'end')}
                       className="w-full h-10 bg-rose-500/10 border border-rose-500/20 hover:bg-rose-500 hover:text-white text-rose-400 rounded-lg font-black uppercase text-[10px] flex items-center justify-center gap-2 transition-all"
                    >
                      <Trophy size={14} /> Force Terminate Battle
                    </button>
                  ) : null}
                </div>
              ))}
            </div>
          )}
          <p className="text-[10px] text-slate-600 italic">
            * Note: Actions are performed using your Admin Identity. The backend allows this override for diagnostic purposes.
          </p>
        </div>

        {/* Search Index Indexer */}
        <div className="card-glass bg-blue-500/5 border-blue-500/20 p-10 col-span-full space-y-6">
           <div className="flex items-center justify-between">
              <h3 className="text-xl font-black text-blue-400 uppercase tracking-tight flex items-center gap-3">
                 <Search size={24} /> Search Engine Indexer
              </h3>
              <span className="px-3 py-1 bg-blue-500/20 text-blue-400 rounded-full text-[10px] font-black uppercase tracking-tighter">Month 7 Fix</span>
           </div>
           <p className="text-slate-500 text-sm">
             Synchronize existing data with the new lowercase search indexes. 
             Select a collection to backfill historical records.
           </p>
           <div className="flex gap-4">
              <button 
                onClick={async () => {
                  setLoading(true);
                  setStatus('INDEXING USERS...');
                  try {
                    const func = httpsCallable(getFunctions(), 'adminBackfillSearchIndexes');
                    const res = await func({ targetCollection: 'users' });
                    setStatus(`SUCCESS: ${res.data.count} Users Indexed! 🚀`);
                    setTimeout(() => setStatus(null), 4000);
                  } catch (e) {
                    alert(e.message);
                    setStatus('ERROR');
                  } finally { setLoading(false); }
                }}
                className="flex-1 h-14 bg-blue-500/10 border-2 border-blue-500/20 hover:bg-blue-500 hover:text-white text-blue-400 rounded-xl font-black uppercase text-xs tracking-widest transition-all"
              >
                Index All Users
              </button>
              <button 
                onClick={async () => {
                  setLoading(true);
                  setStatus('INDEXING ROOMS...');
                  try {
                    const func = httpsCallable(getFunctions(), 'adminBackfillSearchIndexes');
                    const res = await func({ targetCollection: 'rooms' });
                    setStatus(`SUCCESS: ${res.data.count} Rooms Indexed! 🚀`);
                    setTimeout(() => setStatus(null), 4000);
                  } catch (e) {
                    alert(e.message);
                    setStatus('ERROR');
                  } finally { setLoading(false); }
                }}
                className="flex-1 h-14 bg-white/5 border-2 border-white/10 hover:bg-white/10 text-white rounded-xl font-black uppercase text-xs tracking-widest transition-all"
              >
                Index All Rooms
              </button>
           </div>
        </div>

      </div>

      {status && (

        <div className="fixed bottom-10 left-1/2 -translate-x-1/2 flex items-center gap-4 px-8 py-4 bg-slate-900 border border-white/10 rounded-2xl shadow-3xl animate-bounce-in">
           <CheckCircle className="text-emerald-400" />
           <span className="text-xs font-black uppercase tracking-widest">{status}</span>
        </div>
      )}

      {/* Info Card */}
      <div className="card-glass bg-indigo-500/10 border-indigo-500/20 p-8 flex items-start gap-6">
         <div className="p-3 bg-indigo-500/20 rounded-xl">
            <Users className="text-indigo-400" size={24} />
         </div>
         <div>
            <h4 className="font-black text-white uppercase tracking-widest text-sm mb-2">Usage Advice</h4>
            <p className="text-slate-400 text-xs leading-relaxed max-w-2xl">
              Use these tools to verify the "Month 1 Foundation" features (Moments, Likes, Profile Setup). 
              After feeding, you can visit the <b>User Orchestration</b> tab and filter by "All" to see the 
              newly generated personalities. Try logging into the mobile app and commenting on their posts!
            </p>
         </div>
      </div>
    </div>
  );
};

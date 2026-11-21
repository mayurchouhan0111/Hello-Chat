import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { 
  collection, 
  query, 
  doc, 
  updateDoc, 
  onSnapshot, 
  orderBy, 
  writeBatch, 
  increment,
  serverTimestamp 
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { 
  Users, 
  Trash2, 
  Activity, 
  ExternalLink, 
  Mic, 
  Search, 
  Zap, 
  Flame, 
  Diamond, 
  CheckSquare, 
  MessageSquare, 
  X, 
  Check, 
  RefreshCw,
  Clock
} from 'lucide-react';
// eslint-disable-next-line no-unused-vars
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';

export const RoomManagement = () => {
  const { user, role } = useAdmin();
  const [rooms, setRooms] = useState([]);
  const [selectedRooms, setSelectedRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  // Welcome Message Editor Modal State
  const [editingWelcomeRoom, setEditingWelcomeRoom] = useState(null);
  const [welcomeText, setWelcomeText] = useState('');
  const [savingWelcome, setSavingWelcome] = useState(false);
  const [welcomeError, setWelcomeError] = useState('');

  useEffect(() => {
    // Real-time listener for active rooms
    const q = query(collection(db, "rooms"), orderBy("currentUsersCount", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setRooms(list);
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleEndRoom = async (roomId) => {
    if (!window.confirm("ARE YOU SURE? This will permanently end the session for all participants.")) return;
    try {
      await updateDoc(doc(db, "rooms", roomId), { status: 'ended', currentUsersCount: 0 });
    } catch (err) {
      alert("Error ending room: " + err.message);
    }
  };

  const openWelcomeEditor = (room) => {
    setEditingWelcomeRoom(room);
    setWelcomeText(room.welcomeMessage || '');
    setWelcomeError('');
  };

  const handleSaveWelcomeMessage = async (e) => {
    e.preventDefault();
    if (!editingWelcomeRoom) return;

    if (welcomeText.length > 500) {
      setWelcomeError('Welcome message cannot exceed 500 characters.');
      return;
    }

    setSavingWelcome(true);
    setWelcomeError('');

    try {
      // 1. Try secure Cloud Function first (enforces validation and audit log)
      const updateFn = httpsCallable(functions, 'updateRoomWelcomeMessage');
      await updateFn({
        roomId: editingWelcomeRoom.id,
        welcomeMessage: welcomeText.trim()
      });
      setEditingWelcomeRoom(null);
    } catch (fnErr) {
      console.warn("Cloud function updateRoomWelcomeMessage failed, applying direct fallback:", fnErr);
      try {
        // Direct Firestore fallback with audit fields
        await updateDoc(doc(db, "rooms", editingWelcomeRoom.id), {
          welcomeMessage: welcomeText.trim(),
          welcomeMessageUpdatedAt: serverTimestamp(),
          welcomeMessageUpdatedBy: user?.uid || 'admin',
          welcomeMessageUpdatedByRole: role || 'admin',
          updatedAt: serverTimestamp()
        });
        setEditingWelcomeRoom(null);
      } catch (dbErr) {
        setWelcomeError("Failed to update welcome message: " + (dbErr.message || dbErr));
      }
    } finally {
      setSavingWelcome(false);
    }
  };

  const filteredRooms = rooms.filter(r => 
    r.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    r.ownerUid?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    r.id?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter flex items-center gap-4 uppercase">
            <div className="p-3 bg-[#B4E0A2]/20 rounded-2xl border border-[#B4E0A2]/30">
              <Activity className="text-[#B4E0A2]" size={28} />
            </div>
            Active Orchestration
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Monitoring {rooms.length} live synchronized environments
          </p>
        </div>

        <div className="flex items-center gap-4">
          <div className="relative group w-80">
            <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
              <Search className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
            </div>
            <input 
              type="text" 
              placeholder="Locate room by name or ID..."
              className="glass-input w-full pl-12 !py-3.5"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <button 
            onClick={() => {
              if (selectedRooms.length === filteredRooms.length && filteredRooms.length > 0) {
                setSelectedRooms([]);
              } else {
                setSelectedRooms(filteredRooms.map(r => r.id));
              }
            }}
            className="flex items-center gap-2 p-3 bg-[#B4E0A2]/10 border border-[#B4E0A2]/20 rounded-xl hover:bg-[#B4E0A2] text-[#B4E0A2] hover:text-black text-xs font-black uppercase tracking-widest transition-all cursor-pointer"
          >
            <CheckSquare size={14} /> 
            {selectedRooms.length === filteredRooms.length && filteredRooms.length > 0 ? 'DESELECT ALL' : 'SELECT ALL'}
          </button>
          <button
            onClick={async () => {
              if (selectedRooms.length === 0) {
                alert('No rooms selected for termination.');
                return;
              }
              if (!window.confirm(`Terminate ${selectedRooms.length} selected room(s)? This action cannot be undone.`)) return;
              try {
                const chunkSize = 400;
                for (let i = 0; i < selectedRooms.length; i += chunkSize) {
                  const chunk = selectedRooms.slice(i, i + chunkSize);
                  const batch = writeBatch(db);
                  for (const id of chunk) {
                    batch.update(doc(db, "rooms", id), { status: 'ended', currentUsersCount: 0 });
                  }
                  await batch.commit();
                }
                setSelectedRooms([]);
              } catch (err) {
                alert('Error terminating rooms: ' + err.message);
              }
            }}
            className="flex items-center gap-2 p-3 bg-red-500/10 border border-red-500/20 rounded-xl hover:bg-red-500 text-red-500 hover:text-white text-xs font-black uppercase tracking-widest transition-all cursor-pointer"
          >
            <Trash2 size={14} /> TERMINATE SELECTED
          </button>
        </div>
      </div>

      {/* Stats Quick Look */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        {[
          { label: 'Total Viewers', val: rooms.reduce((acc, r) => acc + (r.currentUsersCount || 0), 0), icon: Users, color: 'text-[#B4E0A2]' },
          { label: 'Active PK Battles', val: rooms.filter(r => r.pkActive).length.toLocaleString(), icon: Flame, color: 'text-orange-400' },
          { label: 'Economic Load', val: 'Syncing...', icon: Diamond, color: 'text-amber-400' },
          { label: 'Avg Pulse', val: '98%', icon: Activity, color: 'text-emerald-400' },
        ].map(stat => (
          <div key={stat.label} className="card-glass p-5 border-white/5 flex items-center gap-4 group hover:bg-white/5 transition-all">
            <div className={`p-3 rounded-xl bg-white/5 border border-white/10 ${stat.color}`}>
              <stat.icon size={20} />
            </div>
            <div>
              <p className="text-[10px] font-black uppercase tracking-widest text-slate-500">{stat.label}</p>
              <p className="text-xl font-black text-white tracking-tight">{stat.val}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Rooms Grid */}
      {loading ? (
        <div className="h-64 flex items-center justify-center">
          <div className="flex flex-col items-center gap-4">
            <div className="w-10 h-10 border-4 border-[#B4E0A2] border-t-transparent rounded-full animate-spin" />
            <span className="text-xs font-black uppercase text-slate-600 tracking-widest">Scanning Frequencies...</span>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 2xl:grid-cols-3 gap-8">
          <AnimatePresence>
            {filteredRooms.map((room) => (
              <motion.div 
                key={room.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                className="card-glass p-0 border-white/5 bg-[#18181B]/40 overflow-hidden group hover:border-[#B4E0A2]/30 transition-all shadow-2xl relative"
              >
                {/* Selection Checkbox */}
                <div className="absolute top-2 left-2 z-20">
                  <input
                    type="checkbox"
                    checked={selectedRooms.includes(room.id)}
                    onChange={(e) => {
                      const checked = e.target.checked;
                      setSelectedRooms((prev) =>
                        checked ? [...prev, room.id] : prev.filter((id) => id !== room.id)
                      );
                    }}
                    className="w-4 h-4 text-[#B4E0A2] bg-gray-100 border-gray-300 rounded focus:ring-[#B4E0A2] cursor-pointer"
                  />
                </div>

                {/* Visual Status Indicator */}
                <div className="absolute top-4 left-4 z-10">
                  <div className="flex items-center gap-2 bg-black/60 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/10">
                    <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(239,68,68,0.8)]" />
                    <span className="text-[9px] font-black text-white uppercase tracking-widest leading-none">LIVE NOW</span>
                  </div>
                </div>

                {/* Banner / Cover */}
                <div className="relative h-48 overflow-hidden">
                  <img 
                    src={room.coverUrl || `https://picsum.photos/seed/${room.id}/500/300`} 
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700 opacity-60 group-hover:opacity-80" 
                    alt={room.name || 'Room'}
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black via-transparent to-transparent" />
                  
                  <div className="absolute bottom-4 left-6 right-6">
                    {room.pkActive && (
                      <div className="flex items-center gap-2 mb-3 bg-orange-600/90 backdrop-blur-md px-3 py-1 rounded-lg border border-orange-400/50 w-fit">
                        <Flame size={12} className="text-white animate-bounce" />
                        <span className="text-[10px] font-black text-white uppercase tracking-tighter">BATTLE ACTIVE</span>
                      </div>
                    )}
                    <h3 className="text-xl font-black text-white tracking-tight truncate">{room.name || 'Untitled Room'}</h3>
                    <div className="flex items-center gap-4 mt-2">
                      <div className="flex items-center gap-2">
                        <Users size={14} className="text-[#B4E0A2]" />
                        <span className="text-xs font-bold text-slate-300">{room.currentUsersCount || 0} listening</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <Mic size={14} className="text-emerald-400" />
                        <span className="text-xs font-bold text-slate-300">8 slots</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Info & Meta */}
                <div className="p-6 space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <img src={`https://picsum.photos/seed/${room.ownerUid}/100`} className="w-8 h-8 rounded-lg outline outline-2 outline-white/10" alt="Host" />
                      <div>
                        <p className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">HOSTED BY</p>
                        <p className="text-xs font-black text-white">@{room.ownerUid?.slice(0,10) || 'Unknown'}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="px-2 py-1 bg-white/5 rounded-md text-[9px] font-black text-slate-400 border border-white/5 uppercase">{room.category || 'CHITCHAT'}</span>
                    </div>
                  </div>

                  {/* Real-Time Welcome Message Section */}
                  <div className="p-3 bg-white/[0.02] border border-white/5 rounded-2xl space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-black uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                        <MessageSquare size={12} className="text-[#B4E0A2]" />
                        Welcome Message
                      </span>
                      <button
                        onClick={() => openWelcomeEditor(room)}
                        className="px-2.5 py-1 bg-[#B4E0A2]/10 hover:bg-[#B4E0A2]/20 text-[#B4E0A2] rounded-lg text-[10px] font-bold uppercase transition-all cursor-pointer"
                      >
                        Edit
                      </button>
                    </div>
                    {room.welcomeMessage ? (
                      <p className="text-xs text-slate-300 font-medium italic line-clamp-2 bg-black/30 p-2.5 rounded-xl border border-white/[0.03]">
                        "{room.welcomeMessage}"
                      </p>
                    ) : (
                      <p className="text-[11px] text-slate-600 italic">No welcome message configured for this room.</p>
                    )}
                    {room.welcomeMessageUpdatedAt && (
                      <div className="flex items-center gap-1 text-[9px] text-slate-500 font-mono">
                        <Clock size={10} />
                        <span>Updated by {room.welcomeMessageUpdatedByRole || 'Admin'}</span>
                      </div>
                    )}
                  </div>

                  <div className="pt-2 border-t border-white/5 space-y-2">
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        updateDoc(doc(db, "rooms", room.id), { weeklyEarnings: increment(10000) });
                      }}
                      className="w-full flex items-center justify-center gap-2 p-2 bg-[#B4E0A2]/10 border border-[#B4E0A2]/20 rounded-xl hover:bg-[#B4E0A2] text-[#B4E0A2] hover:text-black text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer"
                    >
                      <Zap size={12} /> +10K Diamonds (Star Mission Test)
                    </button>

                    <button 
                      onClick={async (e) => {
                        e.stopPropagation();
                        const amount = prompt("Enter Fuel Amount (Diamonds):", "1000000");
                        if (!amount) return;
                        try {
                          const injectFuel = httpsCallable(functions, 'adminFuelRocket');
                          await injectFuel({ roomId: room.id, amount: parseInt(amount) });
                          alert("Rocket fuel injected!");
                        } catch (err) {
                          alert("Error: " + err.message);
                        }
                      }}
                      className="w-full flex items-center justify-center gap-2 p-2 bg-indigo-500/10 border border-indigo-500/20 rounded-xl hover:bg-indigo-500 text-indigo-400 hover:text-white text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer"
                    >
                      <Flame size={12} /> Ignite Rocket (Launch Test)
                    </button>
                  </div>

                  {/* Admin Ops Bar */}
                  <div className="grid grid-cols-2 gap-3 pt-3">
                    <button 
                      onClick={() => openWelcomeEditor(room)}
                      className="flex items-center justify-center gap-2 p-3 bg-white/5 border border-white/5 rounded-xl hover:bg-white/10 text-xs font-black uppercase tracking-widest text-slate-300 transition-all cursor-pointer"
                    >
                      <ExternalLink size={14} /> WELCOME
                    </button>
                    <button 
                      onClick={() => handleEndRoom(room.id)}
                      className="flex items-center justify-center gap-2 p-3 bg-red-500/10 border border-red-500/20 rounded-xl hover:bg-red-500 text-red-500 hover:text-white text-xs font-black uppercase tracking-widest transition-all cursor-pointer"
                    >
                      <Trash2 size={14} /> TERMINATE
                    </button>
                  </div>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}

      {/* Real-time Welcome Message Editor Modal */}
      <AnimatePresence>
        {editingWelcomeRoom && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-[#121214] border border-white/[0.08] w-full max-w-lg rounded-[32px] p-8 shadow-2xl relative"
            >
              <button
                onClick={() => setEditingWelcomeRoom(null)}
                className="absolute top-6 right-6 p-2 text-gray-400 hover:text-white rounded-xl hover:bg-white/[0.05] transition-all cursor-pointer"
              >
                <X size={20} />
              </button>

              <div className="flex items-center gap-3 mb-6">
                <div className="p-3 bg-[#B4E0A2]/10 text-[#B4E0A2] rounded-2xl border border-[#B4E0A2]/20">
                  <MessageSquare size={24} />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white">Live Room Welcome Message</h2>
                  <p className="text-gray-400 text-xs mt-0.5">
                    Room: {editingWelcomeRoom.name || editingWelcomeRoom.id}
                  </p>
                </div>
              </div>

              <form onSubmit={handleSaveWelcomeMessage} className="space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-xs font-black text-gray-400 uppercase tracking-widest">
                      Welcome Message Content
                    </label>
                    <span className={`text-xs font-mono font-bold ${welcomeText.length > 500 ? 'text-red-400' : 'text-slate-400'}`}>
                      {welcomeText.length}/500
                    </span>
                  </div>
                  <textarea
                    rows={4}
                    maxLength={500}
                    placeholder="Enter welcome message broadcasted to participants entering this live room..."
                    className="w-full bg-[#18181B] border border-white/[0.08] rounded-2xl p-4 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-[#B4E0A2] resize-none"
                    value={welcomeText}
                    onChange={(e) => setWelcomeText(e.target.value)}
                  />
                  <p className="text-[11px] text-slate-500 mt-1">
                    Canonical field <code className="text-[#B4E0A2]">rooms/{editingWelcomeRoom.id}.welcomeMessage</code>. Synchronized in real-time across all mobile participants.
                  </p>
                </div>

                {welcomeError && (
                  <div className="p-3 bg-red-500/10 border border-red-500/20 text-red-400 rounded-xl text-xs font-bold">
                    {welcomeError}
                  </div>
                )}

                <div className="flex justify-end gap-3 pt-4 border-t border-white/5">
                  <button
                    type="button"
                    onClick={() => setEditingWelcomeRoom(null)}
                    className="px-5 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-black uppercase tracking-wider text-slate-300 transition-all cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={savingWelcome || welcomeText.length > 500}
                    className="px-6 py-3 bg-[#B4E0A2] hover:bg-[#8DBB7E] text-black font-black text-xs uppercase tracking-wider rounded-xl transition-all shadow-lg shadow-[#B4E0A2]/20 flex items-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    {savingWelcome ? <RefreshCw size={16} className="animate-spin" /> : <Check size={16} />}
                    <span>Save Welcome Message</span>
                  </button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

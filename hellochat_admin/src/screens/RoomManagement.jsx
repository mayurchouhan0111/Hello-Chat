import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, getDocs, doc, deleteDoc, updateDoc, onSnapshot, orderBy } from 'firebase/firestore';
import { 
  Users, 
  Volume2, 
  Trash2, 
  ShieldAlert, 
  Activity, 
  ExternalLink, 
  MoreVertical, 
  Mic, 
  Search,
  Zap
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export const RoomManagement = () => {
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

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
      // In a real production app, you'd use a Cloud Function to clean up participants, 
      // but for Spark plan we'll update status to 'ended'
      await updateDoc(doc(db, "rooms", roomId), { status: 'ended', currentUsersCount: 0 });
      // Logic would then move it to history or delete
    } catch (err) {
      alert("Error ending room: " + err.message);
    }
  };

  const filteredRooms = rooms.filter(r => 
    r.title?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    r.ownerUid?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter flex items-center gap-4 uppercase">
            <div className="p-3 bg-cyan-500/20 rounded-2xl border border-cyan-500/30">
              <Activity className="text-cyan-400" size={28} />
            </div>
            Active Orchestration
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Monitoring {rooms.length} live synchronized environments</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group">
              <Search className="absolute left-4 top-4 text-slate-500 group-focus-within:text-cyan-400 transition-colors" size={20} />
              <input 
                type="text" 
                placeholder="Locate room by title or owner ID..."
                className="input-field w-80 pl-12 bg-slate-950/50 border-white/5 focus:ring-cyan-500/50"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
           </div>
           <button className="bg-white/5 border border-white/10 p-4 rounded-2xl hover:bg-white/10 transition-all text-white">
              <Zap size={20} />
           </button>
        </div>
      </div>

      {/* Stats Quick Look */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
         {[
           { label: 'Total Viewers', val: rooms.reduce((acc, r) => acc + (r.currentUsersCount || 0), 0), icon: Users, color: 'text-cyan-400' },
           { label: 'Mic Slots Active', val: '1,204', icon: Mic, color: 'text-purple-400' },
           { label: 'Gifts Flux P/M', val: '4,102', icon: ShieldAlert, color: 'text-amber-400' },
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
               <div className="w-10 h-10 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin"></div>
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
                className="card-glass p-0 border-white/5 bg-slate-800/20 overflow-hidden group hover:border-cyan-500/30 transition-all shadow-2xl relative"
              >
                {/* Visual Status Indicator */}
                <div className="absolute top-4 left-4 z-10">
                   <div className="flex items-center gap-2 bg-black/60 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/10">
                      <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(239,68,68,0.8)]"></div>
                      <span className="text-[9px] font-black text-white uppercase tracking-widest leading-none">LIVE NOW</span>
                   </div>
                </div>

                {/* Banner / Cover */}
                <div className="relative h-48 overflow-hidden">
                   <img 
                    src={room.coverUrl || `https://picsum.photos/seed/${room.id}/500/300`} 
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700 opacity-60 group-hover:opacity-80" 
                   />
                   <div className="absolute inset-0 bg-gradient-to-t from-slate-900 via-transparent to-transparent"></div>
                   
                   <div className="absolute bottom-4 left-6 right-6">
                      <h3 className="text-xl font-black text-white tracking-tight truncate">{room.title || 'Untitled Room'}</h3>
                      <div className="flex items-center gap-4 mt-2">
                        <div className="flex items-center gap-2">
                           <Users size={14} className="text-cyan-400" />
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
                         <img src={`https://picsum.photos/seed/${room.ownerUid}/100`} className="w-8 h-8 rounded-lg outline outline-2 outline-white/10" />
                         <div>
                            <p className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">HOSTED BY</p>
                            <p className="text-xs font-black text-white">@{room.ownerUid?.slice(0,10) || 'Unknown'}</p>
                         </div>
                      </div>
                      <div className="flex items-center gap-2">
                         <span className="px-2 py-1 bg-white/5 rounded-md text-[9px] font-black text-slate-400 border border-white/5 uppercase">{room.category || 'CHITCHAT'}</span>
                      </div>
                   </div>

                   {/* Admin Ops Bar */}
                   <div className="grid grid-cols-2 gap-3 pt-4">
                      <button className="flex items-center justify-center gap-2 p-3 bg-white/5 border border-white/5 rounded-xl hover:bg-white/10 text-xs font-black uppercase tracking-widest text-slate-300 transition-all">
                        <ExternalLink size={14} /> INSPECT
                      </button>
                      <button 
                        onClick={() => handleEndRoom(room.id)}
                        className="flex items-center justify-center gap-2 p-3 bg-red-500/10 border border-red-500/20 rounded-xl hover:bg-red-500 text-red-500 hover:text-white text-xs font-black uppercase tracking-widest transition-all"
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
    </div>
  );
};

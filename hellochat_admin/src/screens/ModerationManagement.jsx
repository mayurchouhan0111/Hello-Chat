import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, getDocs, doc, updateDoc, where, orderBy, limit, onSnapshot } from 'firebase/firestore';
import { 
  UserX, 
  History, 
  ShieldCheck, 
  Unlock, 
  Search, 
  Filter, 
  MoreVertical,
  Activity,
  AlertTriangle
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export const ModerationManagement = () => {
  const [bannedUsers, setBannedUsers] = useState([]);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    // 1. Listen for Banned Users
    const qUsers = query(collection(db, "users"), where("isBanned", "==", true));
    const unsubUsers = onSnapshot(qUsers, (snap) => {
      setBannedUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    // 2. Listen for Admin Logs
    const qLogs = query(collection(db, "admin_logs"), orderBy("timestamp", "desc"), limit(50));
    const unsubLogs = onSnapshot(qLogs, (snap) => {
      setLogs(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    setLoading(false);
    return () => { unsubUsers(); unsubLogs(); };
  }, []);

  const handleUnban = async (uid) => {
    if (!window.confirm("Restore access for this user?")) return;
    try {
      await updateDoc(doc(db, "users", uid), { isBanned: false, banReason: null });
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const filteredBanned = bannedUsers.filter(u => 
    u.id.toLowerCase().includes(searchTerm.toLowerCase()) || 
    u.displayName?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-red-500/20 rounded-2xl border border-red-500/30">
                 <UserX className="text-red-500" size={28} />
              </div>
              Enforcement Center
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Governance HUD • {bannedUsers.length} Active Suspensions</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group">
              <Search className="absolute left-4 top-4 text-slate-500 group-focus-within:text-red-500 transition-colors" size={20} />
              <input 
                type="text" 
                placeholder="ID Search..." 
                className="input-field w-64 pl-12 bg-slate-950/50 border-white/5"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
           </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        
        {/* Banned Users List */}
        <div className="lg:col-span-2 space-y-6">
           <div className="flex items-center justify-between px-2">
              <h4 className="text-xs font-black uppercase tracking-widest text-slate-500">Isolation Queue</h4>
              <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
           </div>
           
           <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <AnimatePresence>
                {filteredBanned.map((user) => (
                  <motion.div 
                    key={user.id}
                    layout
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.9 }}
                    className="card-glass p-6 bg-slate-900/60 border-red-500/10 hover:border-red-500/30 transition-all flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-4">
                       <img src={user.photoUrl || `https://picsum.photos/seed/${user.id}/100`} className="w-12 h-12 rounded-2xl grayscale group-hover:grayscale-0 transition-all border border-white/5" />
                       <div>
                          <p className="text-sm font-black text-white">{user.displayName || 'Anon User'}</p>
                          <p className="text-[10px] font-bold text-red-500/70 uppercase tracking-widest mt-1">BANNED: {user.banReason?.slice(0,15) || 'Violation'}...</p>
                       </div>
                    </div>
                    <button 
                      onClick={() => handleUnban(user.id)}
                      className="p-3 bg-emerald-500/10 hover:bg-emerald-500 text-emerald-500 hover:text-white rounded-xl border border-emerald-500/20 transition-all"
                    >
                       <Unlock size={16} />
                    </button>
                  </motion.div>
                ))}
              </AnimatePresence>
              {filteredBanned.length === 0 && (
                <div className="col-span-full py-20 text-center border-2 border-dashed border-white/5 rounded-[40px]">
                   <ShieldCheck className="mx-auto text-slate-800 mb-4" size={48} />
                   <p className="text-slate-700 font-bold uppercase tracking-widest">No restricted accounts found</p>
                </div>
              )}
           </div>
        </div>

        {/* Audit History */}
        <div className="card-glass bg-slate-950/50 p-0 border-white/5 overflow-hidden flex flex-col h-fit sticky top-24">
           <div className="p-8 border-b border-white/5 bg-white/5 flex items-center justify-between">
              <h4 className="text-lg font-black tracking-tight uppercase flex items-center gap-3">
                 <History className="text-primary-light" size={20} />
                 Audit Trail
              </h4>
              <Activity className="text-slate-700" size={16} />
           </div>

           <div className="p-6 space-y-6 max-h-[500px] overflow-y-auto custom-scrollbar">
              {logs.map(log => (
                <div key={log.id} className="flex gap-4 group">
                   <div className="flex flex-col items-center">
                      <div className={`w-2.5 h-2.5 rounded-full border-2 border-slate-900 ${log.action?.includes('BAN') ? 'bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.5)]' : 'bg-emerald-500'} z-10`}></div>
                      <div className="w-[1px] flex-1 bg-white/5 mt-2"></div>
                   </div>
                   <div className="pb-6">
                      <p className="text-xs font-black text-white uppercase tracking-tight">{log.action || 'INTERNAL_SYNC'}</p>
                      <p className="text-[10px] font-medium text-slate-500 mt-1 italic leading-relaxed">
                        Executed on @{log.targetId?.slice(0,8) || 'System'} {log.amount ? `[Amt: ${log.amount}]` : ''}
                      </p>
                      <p className="text-[9px] font-black text-slate-700 mt-2 uppercase tracking-widest">
                        {log.timestamp?.toDate().toLocaleString() || 'Syncing...'}
                      </p>
                   </div>
                </div>
              ))}
           </div>
        </div>

      </div>
    </div>
  );
};

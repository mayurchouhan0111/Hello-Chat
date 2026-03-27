import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  orderBy, 
  onSnapshot, 
  limit,
  serverTimestamp,
  addDoc
} from 'firebase/firestore';
import { 
  History, 
  Search, 
  Filter, 
  ArrowRight,
  ShieldCheck,
  Zap,
  Tag,
  Diamond,
  Crown
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
import { format } from 'date-fns';

export const logAdminAction = async (user, action, targetId, details = {}) => {
  if (!user) return;
  try {
    await addDoc(collection(db, "admin_logs"), {
      adminUid: user.uid,
      adminEmail: user.email,
      action: action, // e.g., "PRICE_CHANGE", "GIFT_ADD", "CONFIG_UPDATE"
      targetId: targetId,
      details: details,
      timestamp: serverTimestamp()
    });
  } catch (err) {
    console.error("Log error:", err);
  }
};

export const AuditLogs = () => {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "admin_logs"), orderBy("timestamp", "desc"), limit(100));
    const unsub = onSnapshot(q, (snap) => {
      setLogs(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const getActionIcon = (action) => {
    if (action.includes('GIFT')) return <Tag className="text-pink-500" size={16} />;
    if (action.includes('VIP')) return <Crown className="text-amber-500" size={16} />;
    if (action.includes('BALANCE')) return <Diamond className="text-cyan-500" size={16} />;
    if (action.includes('CONFIG')) return <Zap className="text-emerald-500" size={16} />;
    return <ShieldCheck className="text-slate-500" size={16} />;
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-slate-800/50 rounded-2xl border border-white/5 shadow-2xl">
                 <History className="text-primary-light" size={28} />
              </div>
              Audit Trail
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Platform Accountability Hub • Last 100 System Adjustments</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-700" size={16} />
              <input 
                type="text" 
                placeholder="Search Action ID..." 
                className="bg-slate-900 border border-white/5 rounded-2xl pl-12 pr-6 py-3 text-sm font-bold text-slate-300 focus:border-primary/50 focus:ring-4 focus:ring-primary/10 transition-all w-64 uppercase tracking-widest placeholder:lowercase"
              />
           </div>
           <button className="p-3 bg-white/5 hover:bg-white/10 border border-white/5 rounded-2xl transition-all">
              <Filter className="text-slate-400" size={20} />
           </button>
        </div>
      </div>

      {/* Logs Timeline */}
      <div className="card-glass bg-slate-900/40 border-white/5 overflow-hidden shadow-2xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-white/5 bg-slate-950/20">
                <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Administrator</th>
                <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Action Outcome</th>
                <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Target Node</th>
                <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-widest text-right">Timestamp</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {logs.map((log) => (
                <tr key={log.id} className="hover:bg-white/[0.02] transition-colors group">
                  <td className="px-8 py-6">
                    <div className="flex items-center gap-4">
                       <div className="w-10 h-10 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center font-black text-primary-light text-xs">
                          {log.adminEmail?.charAt(0).toUpperCase() || 'A'}
                       </div>
                       <div>
                          <p className="text-sm font-black text-white">{log.adminEmail || 'Unknown Admin'}</p>
                          <p className="text-[10px] font-bold text-slate-600 uppercase pt-1 tracking-widest">ID: {log.adminUid?.slice(0,8)}</p>
                       </div>
                    </div>
                  </td>
                  <td className="px-8 py-6">
                    <div className="flex items-center gap-3">
                       <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center">
                          {getActionIcon(log.action)}
                       </div>
                       <div>
                          <p className="text-xs font-black text-white tracking-widest uppercase">{log.action}</p>
                          {log.details && <p className="text-[10px] text-slate-500 font-bold mt-1 italic">"{JSON.stringify(log.details).slice(1,-1).replaceAll('"', '')}"</p>}
                       </div>
                    </div>
                  </td>
                  <td className="px-8 py-6">
                    <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/5 rounded-lg border border-white/5">
                       <span className="text-[10px] font-black text-slate-400 font-mono tracking-tighter uppercase">{log.targetId || 'SYSTEM'}</span>
                    </div>
                  </td>
                  <td className="px-8 py-6 text-right">
                    <p className="text-[11px] font-black text-slate-400">
                       {log.timestamp ? format(log.timestamp.toDate(), 'HH:mm:ss') : '...'}
                    </p>
                    <p className="text-[9px] font-bold text-slate-600 uppercase mt-1">
                       {log.timestamp ? format(log.timestamp.toDate(), 'MMM dd, yyyy') : '--'}
                    </p>
                  </td>
                </tr>
              ))}

              {!loading && logs.length === 0 && (
                <tr>
                   <td colSpan="4" className="px-8 py-20 text-center">
                      <div className="flex flex-col items-center gap-4">
                         <ShieldCheck className="text-slate-800" size={48} />
                         <p className="text-slate-600 font-black uppercase text-[10px] tracking-widest">System History is Pristine • No Log Entries Found</p>
                      </div>
                   </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

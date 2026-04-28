import { useState, useEffect } from 'react';
import { auth, db } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  doc, 
  updateDoc, 
  where, 
  orderBy, 
  limit, 
  deleteDoc, 
  onSnapshot 
} from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { 
  ShieldAlert, 
  MessageSquare, 
  UserPlus, 
  Eye, 
  Trash2, 
  UserX, 
  CheckCircle,
  MoreVertical,
  Flag,
  Calendar,
  Layers,
  Search
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export const ModerationReports = () => {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('pending');
  const [searchTerm, setSearchTerm] = useState('');

  const functions = getFunctions();

  useEffect(() => {
    const q = query(
      collection(db, "reports"), 
      where("status", "==", filter)
    );
    
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      // Manual sort to avoid index requirement
      list.sort((a, b) => {
        const timeA = a.createdAt?.toDate?.() || a.timestamp?.toDate?.() || 0;
        const timeB = b.createdAt?.toDate?.() || b.timestamp?.toDate?.() || 0;
        return timeB - timeA;
      });
      setReports(list);
      setLoading(false);
    }, (err) => {
      console.error("REPORTS_ERROR:", err);
      setLoading(false);
    });
    return unsub;
  }, [filter]);

  const handleAction = async (report, actionType) => {
    if (!window.confirm(`Perform ${actionType} on account @${report.targetId}?`)) return;
    
    try {
      if (actionType === 'BAN') {
        const banUser = httpsCallable(functions, 'adminBanUser');
        await banUser({ 
          targetUid: report.targetId, // Fixed field name to match backend expectation
          isBanned: true
        });
      }
      
      // Mark report as resolved
      await updateDoc(doc(db, "reports", report.id), { 
        status: 'resolved', 
        resolution: actionType,
        resolvedAt: new Date()
      });
      
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const filteredReports = reports.filter(r => 
    r.targetId?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    r.reporterId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    r.reason?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-red-500/20 rounded-2xl border border-red-500/30">
                 <Flag className="text-red-500" size={28} />
              </div>
              Moderation Inbox
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">{reports.length} security flags in current view</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group w-64">
              <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                 <Search className="text-slate-600 group-focus-within:text-[#00E5FF] transition-colors" size={18} />
              </div>
              <input 
                type="text" 
                placeholder="Search reports..." 
                className="glass-input w-full pl-12 !py-3"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
           </div>
           <div className="flex gap-2">
              {['pending', 'resolved'].map(f => (
                <button 
                   key={f}
                   onClick={() => setFilter(f)}
                   className={`px-6 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all border ${filter === f ? 'bg-red-500 border-red-500 text-white' : 'bg-white/5 border-white/10 text-slate-500 hover:bg-white/10'}`}
                >
                   {f}
                </button>
              ))}
           </div>
        </div>
      </div>

      {/* Reports Grid */}
      <div className="grid grid-cols-1 gap-6">
         {loading ? (
           <div className="p-20 text-center uppercase tracking-widest text-slate-700 font-black animate-pulse">Scanning user activity feed...</div>
         ) : filteredReports.length === 0 ? (
           <div className="p-20 text-center border-2 border-dashed border-white/5 rounded-[40px] flex flex-col items-center gap-4">
              <CheckCircle className="text-emerald-500/20" size={48} />
              <p className="text-slate-700 font-black tracking-widest uppercase">Platform environment secure • 0 Active Threats</p>
           </div>
         ) : (
           <AnimatePresence>
             {filteredReports.map((report) => (
               <motion.div 
                 key={report.id}
                 layout
                 initial={{ opacity: 0, y: 20 }}
                 animate={{ opacity: 1, y: 0 }}
                 className="card-glass p-0 border-white/5 bg-slate-800/20 flex flex-col md:flex-row overflow-hidden group hover:border-red-500/30 transition-all shadow-2xl"
               >
                 {/* Visual indicator bar */}
                 <div className={`w-2 h-auto ${report.severity === 'high' ? 'bg-red-500 animate-pulse' : 'bg-amber-500'}`}></div>

                 <div className="flex-1 p-8 grid grid-cols-1 lg:grid-cols-4 gap-8">
                    {/* Reporter & Target */}
                    <div className="flex items-start gap-4 col-span-1 border-r border-white/5">
                        <div className="relative">
                           <div className="w-12 h-12 bg-white/5 rounded-2xl border border-white/10"></div>
                           <ShieldAlert className="absolute -bottom-1 -right-1 text-red-500" size={16} />
                        </div>
                        <div>
                           <p className="text-[10px] font-black tracking-[0.2em] text-slate-600 uppercase mb-1">Target Account</p>
                           <p className="text-sm font-black text-white">@{report.targetId?.slice(0,10)}</p>
                           <div className="flex items-center gap-2 mt-4">
                              <span className="text-[8px] font-black px-2 py-0.5 bg-red-500/10 text-red-500 border border-red-500/20 rounded uppercase tracking-widest">{report.category || 'HARASSMENT'}</span>
                           </div>
                        </div>
                    </div>

                    {/* Report Reason */}
                    <div className="col-span-1 lg:col-span-2 space-y-3 pr-8 border-r border-white/5">
                        <div className="flex items-center justify-between">
                           <p className="text-[10px] font-black tracking-[0.2em] text-slate-600 uppercase">Violation Description</p>
                           <p className="text-[9px] font-black text-slate-500 flex items-center gap-2 uppercase tracking-widest"><Calendar size={10} /> 3m ago</p>
                        </div>
                        <p className="text-sm font-bold text-slate-300 leading-relaxed italic">"{report.reason || 'No description provided'}"</p>
                        <div className="flex gap-4 mt-6">
                           <div className="flex items-center gap-2">
                              <UserPlus size={14} className="text-slate-700" />
                              <span className="text-[10px] items-center italic font-bold text-slate-500">Reporter: @{report.reporterId?.slice(0,6)}</span>
                           </div>
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="flex flex-col gap-3 justify-center">
                       <button 
                        onClick={() => handleAction(report, 'BAN')}
                        className="w-full flex items-center justify-center gap-2 p-3.5 bg-red-500/10 border border-red-500/20 text-red-500 rounded-xl font-black text-[10px] tracking-widest uppercase hover:bg-red-500 hover:text-white transition-all transform active:scale-95"
                       >
                          <UserX size={14} /> Global Ban
                       </button>
                       <button 
                        onClick={() => handleAction(report, 'DISMISS')}
                        className="w-full flex items-center justify-center gap-2 p-3.5 bg-white/5 border border-white/10 text-white rounded-xl font-black text-[10px] tracking-widest uppercase hover:bg-white/10 transition-all transform active:scale-95"
                       >
                          <CheckCircle size={14} /> Dismiss Report
                       </button>
                    </div>
                 </div>
               </motion.div>
             ))}
           </AnimatePresence>
         )}
      </div>
    </div>
  );
};

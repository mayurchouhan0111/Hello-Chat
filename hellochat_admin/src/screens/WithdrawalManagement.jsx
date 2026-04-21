import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  onSnapshot, 
  orderBy, 
  doc, 
  updateDoc,
  serverTimestamp 
} from 'firebase/firestore';
import { 
  Clock, 
  CheckCircle2, 
  XCircle, 
  ExternalLink,
  Search,
  Filter,
  CreditCard,
  User,
  ArrowRightLeft
} from 'lucide-react';
import { format } from 'date-fns';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const WithdrawalManagement = () => {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const { user } = useAdmin();

  useEffect(() => {
    const q = query(collection(db, "withdrawals"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setRequests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleUpdateStatus = async (requestId, newStatus) => {
    if(!window.confirm(`Are you sure you want to mark this request as ${newStatus.toUpperCase()}?`)) return;
    try {
      await updateDoc(doc(db, "withdrawals", requestId), {
        status: newStatus,
        processedAt: serverTimestamp(),
        processedBy: user.uid
      });
      await logAdminAction(user, "WITHDRAWAL_STATUS_UPDATE", requestId, { status: newStatus });
    } catch (err) {
      alert("Update failed: " + err.message);
    }
  };

  const filteredRequests = requests.filter(r => filter === 'all' || r.status === filter);

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-blue-500/20 rounded-2xl border border-blue-500/30">
                 <ArrowRightLeft className="text-blue-400" size={28} />
              </div>
              Disbursement Hub
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Withdrawal Requests • Financial Liquidity Panel</p>
        </div>

        <div className="flex items-center gap-3">
          <div className="bg-slate-900 border border-white/5 rounded-2xl p-1 flex">
             {['all', 'pending', 'approved', 'rejected', 'completed'].map(f => (
               <button 
                 key={f}
                 onClick={() => setFilter(f)}
                 className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${filter === f ? 'bg-blue-500 text-white shadow-lg' : 'text-slate-500 hover:text-slate-300'}`}
               >
                 {f}
               </button>
             ))}
          </div>
        </div>
      </div>

      {loading ? (
        <div className="py-20 text-center animate-pulse py-40 font-black text-slate-700 uppercase tracking-widest">Financial Records Syncing...</div>
      ) : (
        <div className="grid grid-cols-1 gap-6">
          {filteredRequests.map((req) => (
            <div key={req.id} className="card-glass bg-slate-900/60 border-white/5 p-8 relative group overflow-hidden">
               <div className="absolute top-0 right-0 p-12 bg-blue-500/5 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
               <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-8 relative">
                  
                  {/* Requester Info */}
                  <div className="flex items-center gap-6">
                     <div className="w-14 h-14 bg-slate-800 rounded-2xl flex items-center justify-center border border-white/10">
                        <User className="text-slate-500" size={24} />
                     </div>
                     <div>
                        <p className="text-xs font-black text-slate-500 uppercase tracking-widest mb-1">Requester ID</p>
                        <h3 className="text-lg font-black text-white">{req.uid}</h3>
                        <p className="text-[10px] font-bold text-slate-600 uppercase mt-1">Requested: {req.createdAt ? format(req.createdAt.toDate(), 'MMM dd, yyyy HH:mm') : '...'}</p>
                     </div>
                  </div>

                  {/* Financial Details */}
                  <div className="flex flex-col items-start lg:items-center px-8 border-l border-white/5">
                     <p className="text-xs font-black text-emerald-400 uppercase tracking-widest mb-1 flex items-center gap-2">
                        <CreditCard size={14} /> Settlement Amount
                     </p>
                     <h2 className="text-3xl font-black text-white tracking-tight">{req.amount.toLocaleString()} <span className="text-xs font-bold text-slate-500 uppercase">Beans</span></h2>
                     <p className="text-[10px] font-bold text-slate-600 uppercase mt-2">Est: ${(req.amount / 100).toFixed(2)} USD</p>
                  </div>

                  {/* Method Details */}
                  <div className="px-8 border-l border-white/5">
                     <div className="flex items-center gap-3 mb-2">
                        <span className="px-3 py-1 bg-white/5 border border-white/10 rounded-lg text-[10px] font-black text-blue-400 uppercase tracking-widest">{req.method}</span>
                     </div>
                     <p className="text-xs font-bold text-slate-400">{req.accountDetails?.account}</p>
                     {req.accountDetails?.ifsc && <p className="text-[10px] font-bold text-slate-600 mt-1 uppercase">IFSC: {req.accountDetails.ifsc}</p>}
                  </div>

                  {/* Status & Actions */}
                  <div className="flex items-center gap-4">
                     <div className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border ${
                       req.status === 'pending' ? 'bg-amber-500/10 text-amber-500 border-amber-500/20' :
                       req.status === 'completed' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' :
                       req.status === 'approved' ? 'bg-blue-500/10 text-blue-400 border-blue-500/20' :
                       'bg-red-500/10 text-red-400 border-red-500/20'
                     }`}>
                        {req.status}
                     </div>

                     {req.status === 'pending' && (
                       <div className="flex gap-2">
                          <button 
                            onClick={() => handleUpdateStatus(req.id, 'approved')}
                            className="p-3 bg-emerald-500 hover:bg-emerald-600 text-slate-950 rounded-xl transition-all shadow-xl shadow-emerald-500/20"
                          >
                             <CheckCircle2 size={18} />
                          </button>
                          <button 
                            onClick={() => handleUpdateStatus(req.id, 'rejected')}
                            className="p-3 bg-red-500 hover:bg-red-600 text-white rounded-xl transition-all shadow-xl shadow-red-500/20"
                          >
                             <XCircle size={18} />
                          </button>
                       </div>
                     )}

                     {req.status === 'approved' && (
                       <button 
                         onClick={() => handleUpdateStatus(req.id, 'completed')}
                         className="flex items-center gap-3 px-6 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-xl font-black uppercase text-[10px] tracking-widest transition-all"
                       >
                          Finalize Payout <ExternalLink size={14} />
                       </button>
                     )}
                  </div>

               </div>
            </div>
          ))}

          {filteredRequests.length === 0 && (
            <div className="py-40 text-center border-2 border-dashed border-white/5 rounded-[40px] bg-slate-900/20">
               <Clock className="text-slate-800 mx-auto mb-4" size={48} />
               <p className="text-slate-600 font-black uppercase text-xs tracking-widest">No matching withdrawal requests found</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

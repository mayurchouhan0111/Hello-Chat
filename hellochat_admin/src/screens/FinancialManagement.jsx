import { useState, useEffect } from 'react';
import { auth, db } from '../firebase';
import { collection, query, getDocs, doc, updateDoc, where, orderBy, limit, addDoc, serverTimestamp, increment } from 'firebase/firestore';
import { 
  Coins, 
  TrendingUp, 
  Clock, 
  CheckCircle, 
  XCircle, 
  Filter, 
  FileText, 
  Download,
  AlertCircle,
  Smartphone,
  Zap
} from 'lucide-react';
import { motion } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';

export const FinancialManagement = () => {
  const { isAdmin } = useAdmin();
  const [recharges, setRecharges] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [financeStats, setFinanceStats] = useState({
    totalRevenue: 0,
    activeCirculation: 0
  });

  useEffect(() => {
    if (isAdmin) {
      fetchFinancialData();
    }
  }, [isAdmin]);

  const fetchFinancialData = async () => {
    setLoading(true);
    setError(null);
    try {
      // 1. Fetch pending recharges
      const rq = query(collection(db, "recharges"), where("status", "==", "pending"), orderBy("createdAt", "desc"));
      const rSnap = await getDocs(rq);
      setRecharges(rSnap.docs.map(d => ({ id: d.id, ...d.data() })));

      // 2. Fetch global transactions
      const tq = query(collection(db, "admin_logs"), where("action", "==", "ADJUST_BALANCE"), orderBy("timestamp", "desc"), limit(20));
      const tSnap = await getDocs(tq);
      setTransactions(tSnap.docs.map(d => ({ id: d.id, ...d.data() })));

      // 3. Calculate Stats
      const allApprovedSnap = await getDocs(query(collection(db, "recharges"), where("status", "==", "approved")));
      let rev = 0;
      allApprovedSnap.docs.forEach(d => {
        // Assume 100 diamonds = $1 for now if currency is not specified, or use the 'price' field if it exists
        const data = d.data();
        rev += data.price || (data.amount / 100); 
      });

      const usersSnap = await getDocs(collection(db, "users"));
      let circulation = 0;
      usersSnap.docs.forEach(d => {
        circulation += (d.data().diamondBalance || 0);
      });

      setFinanceStats({
        totalRevenue: rev,
        activeCirculation: circulation
      });
    } catch (err) {
      console.error(err);
      setError(err.message.includes('permissions') 
        ? "Access Denied: Admin Level Required" 
        : "Snapshot Error: Check Firestore Rules");
    } finally {
      setLoading(false);
    }
  };

  const handleApproveRecharge = async (recharge) => {
    if (!window.confirm("Approve this recharge? Diamonds will be added immediately.")) return;
    try {
      const userRef = doc(db, "users", recharge.uid);
      await updateDoc(userRef, { diamondBalance: increment(recharge.amount) });
      await updateDoc(doc(db, "recharges", recharge.id), { status: 'approved', processedAt: serverTimestamp() });
      
      // Log it
      await addDoc(collection(db, "admin_logs"), {
        action: "RECHARGE_APPROVED",
        targetId: recharge.uid,
        amount: recharge.amount,
        rechargeId: recharge.id,
        timestamp: serverTimestamp()
      });
      
      fetchFinancialData();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-4xl font-black tracking-tighter uppercase flex items-center gap-4">
             <div className="p-3 bg-emerald-500/20 rounded-2xl border border-emerald-500/30">
                <TrendingUp className="text-emerald-400" size={28} />
             </div>
             Economic Control
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Monitoring platform revenue and diamond liquidity</p>
        </div>
        <div className="flex gap-4">
           <button className="flex items-center gap-2 px-6 py-3 bg-white/5 border border-white/10 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-white/10 transition-all">
              <Download size={16} /> Export Reports
           </button>
        </div>
      </div>

      {/* Revenue Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {[
            { label: 'Platform Revenue', val: `$${financeStats.totalRevenue.toLocaleString()}`, icon: Coins, color: 'from-emerald-600 to-teal-500' },
            { label: 'Pending Approvals', val: recharges.length, icon: Clock, color: 'from-amber-600 to-orange-500' },
            { label: 'Active Circulation', val: financeStats.activeCirculation.toLocaleString(), icon: Zap, color: 'from-[#00E5FF] to-blue-600' }
          ].map(stat => (
           <div key={stat.label} className={`bg-gradient-to-br ${stat.color} p-8 rounded-[40px] shadow-2xl relative overflow-hidden group`}>
              <div className="absolute top-0 right-0 p-10 bg-white/10 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
              <p className="text-white/70 font-black uppercase tracking-[0.2em] text-[10px] mb-4">{stat.label}</p>
              <h3 className="text-4xl font-black text-white">{stat.val}</h3>
           </div>
         ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
        
        {/* Recharge Requests */}
        <div className="card-glass bg-slate-900/40 p-0 border-white/5 overflow-hidden">
           <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/5">
              <h4 className="text-lg font-black tracking-tight uppercase flex items-center gap-3">
                 <AlertCircle className="text-amber-500" size={20} />
                 Pending Recharges
              </h4>
              <span className="text-[10px] font-black uppercase text-amber-500 tracking-widest">{recharges.length} WAITING</span>
           </div>
           
           <div className="divide-y divide-white/[0.03]">
             {loading ? <div className="p-20 text-center animate-pulse">Scanning Ledger...</div> : 
             recharges.length === 0 ? <div className="p-20 text-center text-slate-700 font-bold uppercase tracking-widest">No pending transactions</div> :
             recharges.map(req => (
               <div key={req.id} className="p-6 flex items-center justify-between group hover:bg-white/5 transition-all">
                  <div className="flex items-center gap-4">
                     <div className="w-12 h-12 bg-white/5 rounded-2xl flex items-center justify-center border border-white/10">
                        <Smartphone size={20} className="text-slate-500" />
                     </div>
                     <div>
                        <p className="text-sm font-black text-white">@{req.uid.slice(0,10)}</p>
                        <p className="text-[10px] font-black text-emerald-400 mt-1 uppercase">+{req.amount} DIAMONDS</p>
                     </div>
                  </div>
                  <div className="flex items-center gap-3 opacity-0 group-hover:opacity-100 transition-opacity">
                     <button onClick={() => handleApproveRecharge(req)} className="p-3 bg-emerald-500/10 hover:bg-emerald-500 text-emerald-500 hover:text-white rounded-xl border border-emerald-500/20 transition-all"><CheckCircle size={18} /></button>
                     <button className="p-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-xl border border-red-500/20 transition-all"><XCircle size={18} /></button>
                  </div>
               </div>
             ))}
           </div>
        </div>

        {/* Global Audit Log */}
        <div className="card-glass bg-slate-900/40 p-0 border-white/5 overflow-hidden">
           <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/5">
              <h4 className="text-lg font-black tracking-tight uppercase flex items-center gap-3">
                 <FileText className="text-primary-light" size={20} />
                 Compliance Log
              </h4>
              <Filter className="text-slate-600" size={18} />
           </div>

           <div className="divide-y divide-white/[0.03]">
              {transactions.map(t => (
                <div key={t.id} className="p-6 flex items-center justify-between hover:bg-white/5 transition-all">
                   <div className="flex items-center gap-4">
                      <div className={`w-2 h-2 rounded-full ${t.action === 'ADJUST_BALANCE' ? 'bg-cyan-500 animate-pulse' : 'bg-emerald-500'}`}></div>
                      <div>
                         <p className="text-xs font-black text-white">{t.action} on @{t.targetId?.slice(0,8)}</p>
                         <p className="text-[10px] font-black text-slate-500 mt-1 uppercase">{t.timestamp?.toDate().toLocaleString() || 'Syncing...'}</p>
                      </div>
                   </div>
                   <div className="text-right">
                      <p className={`text-xs font-black ${t.amount > 0 ? 'text-emerald-400' : 'text-slate-400'}`}>
                         {t.amount > 0 ? '+' : ''}{t.amount}
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

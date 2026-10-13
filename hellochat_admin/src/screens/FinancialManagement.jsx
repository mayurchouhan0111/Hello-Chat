import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { collection, query, getDocs, where, orderBy, limit } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
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
  Zap,
  Settings,
  DollarSign,
  Diamond,
  Lock
} from 'lucide-react';
import { motion } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';

export const FinancialManagement = () => {
  const { isAdmin, isOwner } = useAdmin();
  const [recharges, setRecharges] = useState([]);
  const [withdrawals, setWithdrawals] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [savingPolicy, setSavingPolicy] = useState(false);
  const [policyMessage, setPolicyMessage] = useState('');

  // Policy Form State
  const [agencyRate, setAgencyRate] = useState(0.30);
  const [adminRate, setAdminRate] = useState(0.10);
  const [conversionRate, setConversionRate] = useState(1000000);

  const [financeStats, setFinanceStats] = useState({
    totalRevenue: 0,
    activeCirculation: 0
  });

  useEffect(() => {
    if (isAdmin) {
      // isOwner can settle a tick after isAdmin; refetch so the Owner-only
      // withdrawal queue appears once ownership is known.
      fetchFinancialData();
      fetchPolicies();
    }
  }, [isAdmin, isOwner]);

  const fetchPolicies = async () => {
    try {
      const getPol = httpsCallable(functions, 'getFinancialPolicies');
      const res = await getPol();
      if (res.data) {
        if (res.data.agencyCommissionRate !== undefined) setAgencyRate(res.data.agencyCommissionRate);
        if (res.data.adminCommissionRate !== undefined) setAdminRate(res.data.adminCommissionRate);
        if (res.data.usdToDiamondRate !== undefined) setConversionRate(res.data.usdToDiamondRate);
        if (Array.isArray(res.data.supportedGateways)) {
          setGateways(res.data.supportedGateways);
        }
      }
    } catch (e) {
      console.error("Error fetching financial policies:", e);
    }
  };

  const handleSavePolicies = async (e) => {
    e.preventDefault();
    setSavingPolicy(true);
    setPolicyMessage('');
    try {
      const updatePol = httpsCallable(functions, 'updateFinancialPolicies');
      await updatePol({
        agencyCommissionRate: parseFloat(agencyRate),
        adminCommissionRate: parseFloat(adminRate),
        usdToDiamondRate: parseInt(conversionRate),
      });
      setPolicyMessage('✅ Financial policies saved successfully!');
    } catch (e) {
      setPolicyMessage('❌ Error: ' + e.message);
    } finally {
      setSavingPolicy(false);
    }
  };

  const fetchFinancialData = async () => {
    setLoading(true);
    setError(null);
    try {
      // 1. Fetch pending recharges
      const rq = query(collection(db, "recharges"), where("status", "==", "pending"), orderBy("createdAt", "desc"));
      const rSnap = await getDocs(rq);
      setRecharges(rSnap.docs.map(d => ({ id: d.id, ...d.data() })));

      // 2. Fetch USD commission withdrawals - rules only allow Owner (or the
      // requester) to list these rows, and reviewCommissionWithdrawal is
      // Owner-only anyway, so non-Owner admins get an empty queue instead of
      // a permission error that would abort the whole fetch.
      if (isOwner) {
        const wq = query(collection(db, "commission_withdrawals"), orderBy("createdAt", "desc"), limit(50));
        const wSnap = await getDocs(wq);
        setWithdrawals(wSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      }

      // 3. Fetch global transactions
      const tq = query(collection(db, "admin_logs"), where("action", "==", "ADJUST_BALANCE"), orderBy("timestamp", "desc"), limit(20));
      const tSnap = await getDocs(tq);
      setTransactions(tSnap.docs.map(d => ({ id: d.id, ...d.data() })));

      // 4. Calculate Stats
      const allApprovedSnap = await getDocs(query(collection(db, "recharges"), where("status", "==", "approved")));
      let rev = 0;
      allApprovedSnap.docs.forEach(d => {
        const data = d.data();
        rev += data.price || (data.amount / 100); 
      });

      // SECURITY: an unfiltered getDocs(collection(db,'users')) is denied by
      // rules for every non-Owner tier. getScopedUsers returns exactly the
      // rows this caller is allowed to see.
      const scoped = httpsCallable(functions, 'getScopedUsers');
      const usersRes = await scoped({ limit: 1000 });
      let circulation = 0;
      (usersRes.data.users || []).forEach(u => {
        circulation += (u.diamondBalance || 0);
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

  const handleReviewWithdrawal = async (reqId, action) => {
    // Lifecycle: pending -> processing -> approved -> paid (money moves on
    // 'pay' / 'reject' only). Confirm each Owner decision explicitly.
    const confirmTexts = {
      process: 'Mark this withdrawal as PROCESSING? No funds move yet.',
      approve: 'APPROVE this withdrawal? Funds still stay locked until you mark it paid.',
      pay: 'MARK AS PAID? This moves the funds out of the pending balance permanently.',
      reject: 'REJECT this withdrawal? The locked amount returns to the requester\'s balance.'
    };
    if (!window.confirm(confirmTexts[action] || 'Confirm?')) return;
    let notes = '';
    if (action === 'reject') {
      notes = prompt('Enter rejection reason for this withdrawal:');
      if (notes === null) return; // cancelled
    }

    try {
      const reviewFn = httpsCallable(functions, 'reviewCommissionWithdrawal');
      await reviewFn({ requestId: reqId, action, notes });
      alert(`Withdrawal ${action} successful.`);
      fetchFinancialData();
    } catch (e) {
      alert("Withdrawal Review Error: " + e.message);
    }
  };

  const handleApproveRecharge = async (recharge) => {
    if (!window.confirm("Approve this recharge? Diamonds will be added immediately.")) return;
    try {
      // SECURITY: this used to run `updateDoc(users/{uid}, { diamondBalance:
      // increment(amount) })` straight from the browser - a client-side diamond
      // mint. `diamondBalance` is now in PROTECTED_FIELDS, so that write is
      // denied. approveRecharge does it atomically, once (idempotent on the
      // recharge's own status), logs the audit, and propagates agency/admin
      // commission in the same transaction.
      const approve = httpsCallable(functions, 'approveRecharge');
      const res = await approve({ rechargeId: recharge.id });

      const c = res.data.commission;
      const commissionNote = c && !c.skipped
        ? ` Commission: $${c.agencyCommissionUSD} agency / $${c.adminCommissionUSD} admin.`
        : '';
      alert(`Recharge approved: ${res.data.amount} diamonds credited.${commissionNote}`);

      fetchFinancialData();
    } catch (err) {
      alert("Error: " + (err.message || err));
    }
  };

  /**
   * Record a confirmed gateway payment so the receiving user can redeem it.
   * Until a payment provider is connected this is the only way a recharge can
   * become real: `rechargeDiamonds` refuses any request without a paid order.
   */
  const [orderForm, setOrderForm] = useState({
    targetUid: '',
    diamonds: '',
    usd: '',
    gateway: '',
    paymentRef: ''
  });
  const [orderBusy, setOrderBusy] = useState(false);
  const [gateways, setGateways] = useState([]);

  const handleIssueOrder = async (e) => {
    e.preventDefault();
    if (!orderForm.targetUid || !orderForm.diamonds || !orderForm.usd || !orderForm.paymentRef) {
      alert('Recipient, diamonds, USD and payment reference are all required.');
      return;
    }
    if (!orderForm.gateway) {
      alert('Select the gateway the payment actually arrived on.');
      return;
    }
    if (!window.confirm(`Issue a paid order for ${orderForm.diamonds} diamonds ($${orderForm.usd}) to ${orderForm.targetUid}?`)) return;

    setOrderBusy(true);
    try {
      const issue = httpsCallable(functions, 'issueRechargeOrder');
      const res = await issue({
        targetUid: orderForm.targetUid.trim(),
        diamonds: Number(orderForm.diamonds),
        usd: Number(orderForm.usd),
        gateway: orderForm.gateway,
        paymentRef: orderForm.paymentRef.trim()
      });
      alert(`Order issued: ${res.data.orderId}\n\nGive this ID to the user, or redeem it for them.`);
      setOrderForm({ targetUid: '', diamonds: '', usd: '', gateway: '', paymentRef: '' });
    } catch (err) {
      alert('Could not issue order: ' + (err.message || err));
    } finally {
      setOrderBusy(false);
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
             Economic & Commission Control
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Platform revenue, commission rules, & USD withdrawal approvals</p>
        </div>
      </div>

      {/* Revenue Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {[
            { label: 'Platform Revenue', val: `$${financeStats.totalRevenue.toLocaleString()}`, icon: Coins, color: 'from-emerald-600 to-teal-500' },
            { label: 'Pending Withdrawals', val: withdrawals.filter(w => w.status === 'pending').length, icon: Clock, color: 'from-amber-600 to-orange-500' },
            { label: 'Active Circulation', val: financeStats.activeCirculation.toLocaleString(), icon: Zap, color: 'from-[#00E5FF] to-blue-600' }
          ].map(stat => (
           <div key={stat.label} className={`bg-gradient-to-br ${stat.color} p-8 rounded-[40px] shadow-2xl relative overflow-hidden group`}>
              <div className="absolute top-0 right-0 p-10 bg-white/10 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
              <p className="text-white/70 font-black uppercase tracking-[0.2em] text-[10px] mb-4">{stat.label}</p>
              <h3 className="text-4xl font-black text-white">{stat.val}</h3>
           </div>
         ))}
      </div>

      {/* SECTION: Owner Financial Controls Panel */}
      <div className="p-8 bg-slate-900/60 border border-white/10 rounded-[32px] shadow-2xl">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <Settings className="text-emerald-400" size={24} />
            <div>
              <h3 className="text-xl font-black uppercase tracking-wider">Financial Policy Configuration (Owner Exclusive)</h3>
              <p className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-1">Centralized commission rates & USD-to-Diamond conversion rate</p>
            </div>
          </div>
          {!isOwner && (
            <span className="px-4 py-2 bg-amber-500/20 text-amber-400 border border-amber-500/30 rounded-2xl text-xs font-black uppercase flex items-center gap-2">
              <Lock size={14} /> Owner Controlled (Read Only)
            </span>
          )}
        </div>

        {policyMessage && <div className="mb-4 p-4 bg-slate-800 rounded-2xl text-xs font-bold">{policyMessage}</div>}

        <form onSubmit={handleSavePolicies} className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Agency Commission Rate</label>
            <div className={`flex items-center bg-black border ${!isOwner ? 'border-white/5 opacity-70' : 'border-white/10'} rounded-2xl px-4 py-3`}>
              <DollarSign className="text-emerald-400 mr-2" size={18} />
              <input 
                type="number" step="0.01" min="0" max="1"
                disabled={!isOwner}
                className="w-full bg-transparent text-white font-black text-lg outline-none disabled:cursor-not-allowed"
                value={agencyRate}
                onChange={e => setAgencyRate(e.target.value)}
              />
              <span className="text-xs text-slate-500 font-bold">({(agencyRate * 100).toFixed(0)}%)</span>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Admin Commission Rate</label>
            <div className={`flex items-center bg-black border ${!isOwner ? 'border-white/5 opacity-70' : 'border-white/10'} rounded-2xl px-4 py-3`}>
              <DollarSign className="text-indigo-400 mr-2" size={18} />
              <input 
                type="number" step="0.01" min="0" max="1"
                disabled={!isOwner}
                className="w-full bg-transparent text-white font-black text-lg outline-none disabled:cursor-not-allowed"
                value={adminRate}
                onChange={e => setAdminRate(e.target.value)}
              />
              <span className="text-xs text-slate-500 font-bold">({(adminRate * 100).toFixed(0)}%)</span>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">USD &rarr; Diamond Rate (per $1 USD)</label>
            <div className={`flex items-center bg-black border ${!isOwner ? 'border-white/5 opacity-70' : 'border-white/10'} rounded-2xl px-4 py-3`}>
              <Diamond className="text-cyan-400 mr-2" size={18} />
              <input 
                type="number"
                disabled={!isOwner}
                className="w-full bg-transparent text-white font-black text-lg outline-none disabled:cursor-not-allowed"
                value={conversionRate}
                onChange={e => setConversionRate(e.target.value)}
              />
            </div>
          </div>

          <div className="md:col-span-3 flex justify-end">
            <button 
              type="submit"
              disabled={!isOwner || savingPolicy}
              className="px-8 py-4 bg-emerald-500 hover:bg-emerald-600 text-black font-black uppercase text-xs tracking-widest rounded-2xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {savingPolicy ? 'Saving Policies...' : isOwner ? 'Save Financial Rules' : 'Locked (Owner Access Only)'}
            </button>
          </div>
        </form>
      </div>

      {/* SECTION: Issue a verified recharge order */}
      <div className="p-8 bg-slate-900/60 border border-white/10 rounded-[32px] shadow-2xl">
        <div className="flex items-center gap-3 mb-2">
          <Smartphone className="text-cyan-400" size={24} />
          <div>
            <h3 className="text-xl font-black uppercase tracking-wider">Issue Verified Recharge</h3>
            <p className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-1">
              Records a payment the platform actually received; the user redeems it for diamonds
            </p>
          </div>
        </div>

        <p className="text-[11px] text-amber-400/80 font-bold bg-amber-500/10 border border-amber-500/20 rounded-2xl px-4 py-3 mb-6">
          Until a payment provider is connected, this admin flow is the only path to a recharge.
          Direct wallet edits are blocked by security rules.
        </p>

        <form onSubmit={handleIssueOrder} className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Recipient UID</label>
            <input
              required
              value={orderForm.targetUid}
              onChange={e => setOrderForm(f => ({ ...f, targetUid: e.target.value }))}
              placeholder="Firebase UID of the user"
              className="w-full bg-black border border-white/10 rounded-2xl px-4 py-3 text-white font-bold text-sm outline-none focus:border-cyan-500/50"
            />
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Payment Gateway</label>
            <select
              required
              value={orderForm.gateway}
              onChange={e => setOrderForm(f => ({ ...f, gateway: e.target.value }))}
              className="w-full bg-black border border-white/10 rounded-2xl px-4 py-3 text-white font-bold text-sm outline-none focus:border-cyan-500/50"
            >
              <option value="">Select gateway...</option>
              {gateways.map(g => <option key={g} value={g}>{g}</option>)}
            </select>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Diamonds</label>
            <input
              required type="number" min="1"
              value={orderForm.diamonds}
              onChange={e => setOrderForm(f => ({ ...f, diamonds: e.target.value }))}
              className="w-full bg-black border border-white/10 rounded-2xl px-4 py-3 text-white font-black text-lg outline-none focus:border-cyan-500/50"
            />
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Amount Paid (USD)</label>
            <input
              required type="number" min="0" step="0.01"
              value={orderForm.usd}
              onChange={e => setOrderForm(f => ({ ...f, usd: e.target.value }))}
              className="w-full bg-black border border-white/10 rounded-2xl px-4 py-3 text-white font-black text-lg outline-none focus:border-cyan-500/50"
            />
          </div>

          <div className="space-y-2 md:col-span-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-2">Gateway Payment Reference</label>
            <input
              required
              value={orderForm.paymentRef}
              onChange={e => setOrderForm(f => ({ ...f, paymentRef: e.target.value }))}
              placeholder="Transaction / receipt ID from the provider"
              className="w-full bg-black border border-white/10 rounded-2xl px-4 py-3 text-white font-bold text-sm outline-none focus:border-cyan-500/50"
            />
          </div>

          <div className="md:col-span-2 flex justify-end">
            <button
              type="submit"
              disabled={!isOwner || orderBusy}
              className="px-8 py-4 bg-cyan-500 hover:bg-cyan-600 text-black font-black uppercase text-xs tracking-widest rounded-2xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {orderBusy ? 'Issuing...' : isOwner ? 'Issue Recharge Order' : 'Locked (Owner Access Only)'}
            </button>
          </div>
        </form>
      </div>

      {/* SECTION: Commission Withdrawals Approval Queue */}
      <div className="card-glass bg-slate-900/40 p-0 border-white/5 overflow-hidden">
        <div className="p-8 border-b border-white/5 flex items-center justify-between bg-white/5">
          <h4 className="text-lg font-black tracking-tight uppercase flex items-center gap-3">
            <Clock className="text-amber-500" size={20} />
            USD Commission Withdrawal Requests Queue
          </h4>
          <span className="text-[10px] font-black uppercase text-amber-500 tracking-widest">
            {withdrawals.filter(w => w.status === 'pending').length} PENDING APPROVAL
          </span>
        </div>

        <div className="divide-y divide-white/[0.03]">
          {!isOwner ? (
            <div className="p-10 text-center text-slate-600 font-bold uppercase tracking-widest flex items-center justify-center gap-3">
              <Lock size={16} /> Withdrawal review is Owner-only
            </div>
          ) : loading ? (
            <div className="p-20 text-center animate-pulse">Loading Withdrawal Queue...</div>
          ) : withdrawals.length === 0 ? (
            <div className="p-20 text-center text-slate-600 font-bold uppercase tracking-widest">No withdrawal requests found</div>
          ) : (
            withdrawals.map(req => (
              <div key={req.id} className="p-6 flex items-center justify-between group hover:bg-white/5 transition-all">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 bg-white/5 rounded-2xl flex items-center justify-center border border-white/10">
                    <DollarSign size={22} className="text-emerald-400" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-black text-white">{req.displayName || req.userId}</p>
                      <span className="px-2 py-0.5 bg-indigo-500/20 text-indigo-400 font-black text-[9px] uppercase rounded">
                        {req.userRole || 'agency'}
                      </span>
                    </div>
                    <p className="text-xs font-black text-emerald-400 mt-1 uppercase">
                      ${req.usdAmount?.toFixed(2)} USD via {req.paymentMethod}
                    </p>
                    <p className="text-[10px] text-slate-500 font-mono mt-0.5">
                      Account: {req.paymentAccountDetails}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-4">
                  <span className={`px-3 py-1 rounded-full text-[10px] font-black uppercase ${
                    req.status === 'paid' ? 'bg-emerald-500/20 text-emerald-400' :
                    req.status === 'rejected' ? 'bg-red-500/20 text-red-400' :
                    req.status === 'processing' ? 'bg-blue-500/20 text-blue-400' :
                    req.status === 'approved' ? 'bg-cyan-500/20 text-cyan-400' :
                    'bg-amber-500/20 text-amber-400'
                  }`}>
                    {req.status}
                  </span>

                  {req.status === 'pending' && (
                    <div className="flex items-center gap-2">
                      <button
                        title="Start processing"
                        onClick={() => handleReviewWithdrawal(req.id, 'process')}
                        className="p-3 bg-blue-500/10 hover:bg-blue-500 text-blue-500 hover:text-white rounded-xl border border-blue-500/20 transition-all"
                      >
                        <Clock size={18} />
                      </button>
                      <button
                        title="Reject"
                        onClick={() => handleReviewWithdrawal(req.id, 'reject')}
                        className="p-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-xl border border-red-500/20 transition-all"
                      >
                        <XCircle size={18} />
                      </button>
                    </div>
                  )}

                  {req.status === 'processing' && (
                    <div className="flex items-center gap-2">
                      <button
                        title="Approve (funds stay locked)"
                        onClick={() => handleReviewWithdrawal(req.id, 'approve')}
                        className="p-3 bg-emerald-500/10 hover:bg-emerald-500 text-emerald-500 hover:text-white rounded-xl border border-emerald-500/20 transition-all"
                      >
                        <CheckCircle size={18} />
                      </button>
                      <button
                        title="Reject"
                        onClick={() => handleReviewWithdrawal(req.id, 'reject')}
                        className="p-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-xl border border-red-500/20 transition-all"
                      >
                        <XCircle size={18} />
                      </button>
                    </div>
                  )}

                  {req.status === 'approved' && (
                    <div className="flex items-center gap-2">
                      <button
                        title="Mark as paid (moves funds)"
                        onClick={() => handleReviewWithdrawal(req.id, 'pay')}
                        className="p-3 bg-emerald-500/10 hover:bg-emerald-500 text-emerald-500 hover:text-white rounded-xl border border-emerald-500/20 transition-all"
                      >
                        <DollarSign size={18} />
                      </button>
                      <button
                        title="Reject"
                        onClick={() => handleReviewWithdrawal(req.id, 'reject')}
                        className="p-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-xl border border-red-500/20 transition-all"
                      >
                        <XCircle size={18} />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};


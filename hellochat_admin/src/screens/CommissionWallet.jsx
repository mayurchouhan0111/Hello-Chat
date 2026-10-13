import { useState, useEffect, useCallback } from 'react';
import { db, functions } from '../firebase';
import { doc, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { useAdmin } from '../context/AdminContext';
import { 
  Wallet, 
  ArrowUpRight, 
  ArrowDownLeft, 
  RefreshCw, 
  TrendingUp, 
  DollarSign, 
  Diamond, 
  Clock, 
  Send, 
  CheckCircle, 
  AlertCircle, 
  Store, 
  ShieldCheck,
  CreditCard,
  History,
  Coins
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export const CommissionWallet = () => {
  const { userData: currentUser, role, isSuperAdmin } = useAdmin();

  // Balance & Profile State
  const [wallet, setWallet] = useState({
    usdCommissionBalance: 0,
    totalCommissionEarned: 0,
    totalRechargeGenerated: 0,
    pendingWithdrawalBalance: 0,
    totalWithdrawnUSD: 0,
    diamondBalance: 0,
  });
  const [policy, setPolicy] = useState({
    minWithdrawalUSD: 10,
    usdToDiamondRate: 1000000,
    supportedGateways: [
      'bKash', 'Nagad', 'Rocket', 'Bank Transfer',
      'PayPal', 'Wise', 'Binance Pay', 'USDT TRC20', 'USDT BEP20'
    ]
  });
  const [loading, setLoading] = useState(true);
  const [activeAction, setActiveAction] = useState('transfer'); // 'transfer' | 'withdraw' | 'convert'
  const [historyTab, setHistoryTab] = useState('transfers'); // 'transfers' | 'withdrawals' | 'conversions' | 'inflows'

  // Action Form States
  // 1. Reseller Transfer
  const [transferHelloId, setTransferHelloId] = useState('');
  const [transferAmount, setTransferAmount] = useState('');
  const [transferBusy, setTransferBusy] = useState(false);
  const [transferResult, setTransferResult] = useState(null);

  // 2. Direct Cashout
  const [withdrawGateway, setWithdrawGateway] = useState('bKash');
  const [withdrawAccount, setWithdrawAccount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [withdrawBusy, setWithdrawBusy] = useState(false);

  // 3. Convert to Diamonds
  const [convertAmount, setConvertAmount] = useState('');
  const [convertBusy, setConvertBusy] = useState(false);

  // History State
  const [historyList, setHistoryList] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  // Super Admin exclusion guard
  if (isSuperAdmin && role !== 'owner') {
    return (
      <div className="p-8 text-center bg-slate-900 border border-white/10 rounded-3xl max-w-xl mx-auto mt-20 text-white space-y-4">
        <AlertCircle size={48} className="text-amber-500 mx-auto" />
        <h2 className="text-2xl font-black uppercase tracking-wider">Access Restricted</h2>
        <p className="text-slate-400 text-sm">
          Per platform policy, Super Admins are strictly excluded from the commission and salary wallet system.
        </p>
      </div>
    );
  }

  // 1. Real-time balance sync from user doc
  useEffect(() => {
    if (!currentUser?.uid) return;
    const unsub = onSnapshot(doc(db, 'users', currentUser.uid), (snap) => {
      if (snap.exists()) {
        const data = snap.data();
        setWallet({
          usdCommissionBalance: Number(data.usdCommissionBalance || 0),
          totalCommissionEarned: Number(data.totalCommissionEarned || 0),
          totalRechargeGenerated: Number(data.totalRechargeGenerated || 0),
          pendingWithdrawalBalance: Number(data.pendingWithdrawalBalance || 0),
          totalWithdrawnUSD: Number(data.totalWithdrawnUSD || 0),
          diamondBalance: Number(data.diamondBalance || 0),
        });
      }
      setLoading(false);
    });

    return () => unsub();
  }, [currentUser?.uid]);

  // 2. Fetch Owner Policies
  useEffect(() => {
    const fetchPolicy = async () => {
      try {
        const getPol = httpsCallable(functions, 'getFinancialPolicies');
        const res = await getPol();
        if (res.data) {
          setPolicy(prev => ({
            ...prev,
            minWithdrawalUSD: res.data.minWithdrawalUSD || prev.minWithdrawalUSD,
            usdToDiamondRate: res.data.usdToDiamondRate || prev.usdToDiamondRate,
            supportedGateways: Array.isArray(res.data.supportedGateways) && res.data.supportedGateways.length
              ? res.data.supportedGateways
              : prev.supportedGateways
          }));
        }
      } catch (e) {
        console.warn('Using default financial policies:', e);
      }
    };
    fetchPolicy();
  }, []);

  // 3. Fetch History Tab Data
  //
  // Reads go through `listMyLedger` rather than a client-side
  // `where(userId == me)` query: Firestore rules cannot see a query's WHERE
  // clause, so every one of these four lists was permission-denied. The
  // callable filters on context.auth.uid server-side instead.
  const loadHistory = useCallback(async () => {
    if (!currentUser?.uid) return;
    setHistoryLoading(true);
    try {
      const fn = httpsCallable(functions, 'listMyLedger');
      const res = await fn({ tab: historyTab, limit: 30 });
      setHistoryList(res.data || []);
    } catch (e) {
      console.warn('Could not load history:', e);
      setHistoryList([]);
    } finally {
      setHistoryLoading(false);
    }
  }, [currentUser?.uid, historyTab]);

  useEffect(() => {
    loadHistory();
  }, [loadHistory]);

  // Action 1: Option 1 (Reseller Transfer)
  const handleTransfer = async (e) => {
    e.preventDefault();
    const amount = parseFloat(transferAmount);
    if (!transferHelloId.trim()) return alert('Please enter target Reseller ID');
    if (isNaN(amount) || amount <= 0) return alert('Please enter a valid amount');
    if (amount > wallet.usdCommissionBalance) return alert('Amount exceeds available USD commission balance');

    setTransferBusy(true);
    setTransferResult(null);
    try {
      const transferFn = httpsCallable(functions, 'transferCommissionToReseller');
      const res = await transferFn({
        targetResellerHelloId: transferHelloId.trim(),
        usdAmount: amount
      });
      setTransferResult(res.data);
      setTransferAmount('');
      setTransferHelloId('');
      alert(`Transfer successful! Transaction: ${res.data.transactionId}`);
      loadHistory();
    } catch (err) {
      alert('Transfer failed: ' + err.message);
    } finally {
      setTransferBusy(false);
    }
  };

  // Action 2: Option 2 (Direct Cashout)
  const handleWithdrawal = async (e) => {
    e.preventDefault();
    const amount = parseFloat(withdrawAmount);
    if (!withdrawAccount.trim()) return alert('Please enter payment account details');
    if (isNaN(amount) || amount < policy.minWithdrawalUSD) {
      return alert(`Minimum withdrawal amount is $${policy.minWithdrawalUSD} USD`);
    }
    if (amount > wallet.usdCommissionBalance) return alert('Amount exceeds available USD commission balance');

    setWithdrawBusy(true);
    try {
      const withdrawFn = httpsCallable(functions, 'submitCommissionWithdrawal');
      await withdrawFn({
        paymentMethod: withdrawGateway,
        paymentAccountDetails: withdrawAccount.trim(),
        usdAmount: amount
      });
      alert('Withdrawal request submitted! It is now pending Owner review.');
      setWithdrawAmount('');
      setWithdrawAccount('');
      loadHistory();
    } catch (err) {
      alert('Withdrawal request failed: ' + err.message);
    } finally {
      setWithdrawBusy(false);
    }
  };

  // Action 3: USD to Diamonds Conversion
  const handleConversion = async (e) => {
    e.preventDefault();
    const amount = parseFloat(convertAmount);
    if (isNaN(amount) || amount <= 0) return alert('Please enter a valid USD amount');
    if (amount > wallet.usdCommissionBalance) return alert('Amount exceeds available USD commission balance');

    const expectedDiamonds = Math.floor(amount * policy.usdToDiamondRate);
    if (!window.confirm(`Convert $${amount} USD into ${expectedDiamonds.toLocaleString()} Diamonds?`)) return;

    setConvertBusy(true);
    try {
      const convertFn = httpsCallable(functions, 'convertCommissionToDiamonds');
      const res = await convertFn({ usdAmount: amount });
      alert(`Conversion complete! Credited ${res.data.diamondsReceived.toLocaleString()} Diamonds.`);
      setConvertAmount('');
      loadHistory();
    } catch (err) {
      alert('Conversion failed: ' + err.message);
    } finally {
      setConvertBusy(false);
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-white/5">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-emerald-500/20 rounded-2xl border border-emerald-500/30">
              <Wallet className="text-emerald-400" size={28} />
            </div>
            USD Commission Wallet
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Real-Time Recharge Commissions • Reseller Transfers • Direct Cashout
          </p>
        </div>

        <button 
          onClick={loadHistory}
          className="flex items-center gap-2 px-5 py-3 bg-slate-900 border border-white/10 rounded-2xl text-[10px] font-black uppercase tracking-widest text-slate-400 hover:text-white transition-all self-start md:self-auto"
        >
          <RefreshCw size={14} className={loading || historyLoading ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      {/* Real-time Stats Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {/* Available Balance */}
        <div className="bg-gradient-to-br from-emerald-600/30 to-teal-800/20 border border-emerald-500/30 p-8 rounded-[36px] relative overflow-hidden shadow-2xl">
          <div className="absolute top-0 right-0 p-8 bg-emerald-500/10 rounded-full blur-2xl"></div>
          <div className="flex items-center justify-between mb-4">
            <span className="text-[10px] font-black text-emerald-400 uppercase tracking-[0.2em]">Available Commission</span>
            <DollarSign size={20} className="text-emerald-400" />
          </div>
          <h2 className="text-4xl font-black text-white tracking-tight">${wallet.usdCommissionBalance.toFixed(2)}</h2>
          <p className="text-[10px] text-emerald-400/80 font-bold uppercase tracking-wider mt-2">Ready to transfer or withdraw</p>
        </div>

        {/* Total Commission Earned */}
        <div className="bg-gradient-to-br from-indigo-600/20 to-slate-900/40 border border-indigo-500/20 p-8 rounded-[36px] relative overflow-hidden shadow-2xl">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[10px] font-black text-indigo-400 uppercase tracking-[0.2em]">Total Earned</span>
            <TrendingUp size={20} className="text-indigo-400" />
          </div>
          <h2 className="text-4xl font-black text-white tracking-tight">${wallet.totalCommissionEarned.toFixed(2)}</h2>
          <p className="text-[10px] text-slate-500 font-bold uppercase tracking-wider mt-2">Lifetime commission revenue</p>
        </div>

        {/* Pending Withdrawals */}
        <div className="bg-gradient-to-br from-amber-600/20 to-slate-900/40 border border-amber-500/20 p-8 rounded-[36px] relative overflow-hidden shadow-2xl">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[10px] font-black text-amber-400 uppercase tracking-[0.2em]">Pending Cashout</span>
            <Clock size={20} className="text-amber-400" />
          </div>
          <h2 className="text-4xl font-black text-amber-400 tracking-tight">${wallet.pendingWithdrawalBalance.toFixed(2)}</h2>
          <p className="text-[10px] text-slate-500 font-bold uppercase tracking-wider mt-2">In-flight Owner review</p>
        </div>

        {/* Total Recharge Generated & Diamonds */}
        <div className="bg-gradient-to-br from-cyan-600/20 to-slate-900/40 border border-cyan-500/20 p-8 rounded-[36px] relative overflow-hidden shadow-2xl">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[10px] font-black text-cyan-400 uppercase tracking-[0.2em]">Recharge Volume</span>
            <Coins size={20} className="text-cyan-400" />
          </div>
          <h2 className="text-4xl font-black text-white tracking-tight">${wallet.totalRechargeGenerated.toFixed(2)}</h2>
          <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider mt-2">
            Diamonds: {wallet.diamondBalance.toLocaleString()} 💎
          </p>
        </div>
      </div>

      {/* Main Action Hub */}
      <div className="bg-[#09090B] border border-white/10 rounded-[36px] p-8 shadow-2xl">
        {/* Action Select Tabs */}
        <div className="flex flex-wrap gap-3 pb-8 border-b border-white/5">
          <button
            onClick={() => setActiveAction('transfer')}
            className={`flex items-center gap-2 px-6 py-4 rounded-2xl text-xs font-black uppercase tracking-wider transition-all ${
              activeAction === 'transfer'
                ? 'bg-amber-500 text-black shadow-lg shadow-amber-500/20'
                : 'bg-white/5 text-slate-400 hover:text-white'
            }`}
          >
            <Store size={18} /> Option 1: Reseller Transfer
          </button>

          <button
            onClick={() => setActiveAction('withdraw')}
            className={`flex items-center gap-2 px-6 py-4 rounded-2xl text-xs font-black uppercase tracking-wider transition-all ${
              activeAction === 'withdraw'
                ? 'bg-emerald-500 text-black shadow-lg shadow-emerald-500/20'
                : 'bg-white/5 text-slate-400 hover:text-white'
            }`}
          >
            <CreditCard size={18} /> Option 2: Direct Cashout
          </button>

          <button
            onClick={() => setActiveAction('convert')}
            className={`flex items-center gap-2 px-6 py-4 rounded-2xl text-xs font-black uppercase tracking-wider transition-all ${
              activeAction === 'convert'
                ? 'bg-cyan-500 text-black shadow-lg shadow-cyan-500/20'
                : 'bg-white/5 text-slate-400 hover:text-white'
            }`}
          >
            <Diamond size={18} /> Convert to Diamonds
          </button>
        </div>

        {/* Action 1: Reseller Transfer Form */}
        {activeAction === 'transfer' && (
          <form onSubmit={handleTransfer} className="pt-8 space-y-6 max-w-2xl">
            <div>
              <h3 className="text-xl font-black text-white uppercase tracking-wider flex items-center gap-3">
                <Store className="text-amber-400" size={24} />
                Instant Reseller Transfer
              </h3>
              <p className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-1">
                Instantly credit USD commission into a target Reseller's balance (generates immutable TRF- audit hash)
              </p>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Target Reseller ID (Hello ID)</label>
              <input
                type="text"
                required
                value={transferHelloId}
                onChange={e => setTransferHelloId(e.target.value)}
                placeholder="e.g. 97702581"
                className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-bold outline-none focus:border-amber-500 text-sm"
              />
            </div>

            <div className="space-y-2">
              <div className="flex justify-between items-center ml-1">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">USD Amount ($)</label>
                <button
                  type="button"
                  onClick={() => setTransferAmount(wallet.usdCommissionBalance.toString())}
                  className="text-[10px] font-black text-amber-400 uppercase hover:underline"
                >
                  Max (${wallet.usdCommissionBalance.toFixed(2)})
                </button>
              </div>
              <input
                type="number"
                step="0.01"
                min="0.01"
                required
                value={transferAmount}
                onChange={e => setTransferAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-xl outline-none focus:border-amber-500"
              />
            </div>

            <button
              type="submit"
              disabled={transferBusy || wallet.usdCommissionBalance <= 0}
              className="w-full py-4 bg-amber-500 hover:bg-amber-600 text-black font-black uppercase text-xs tracking-widest rounded-2xl transition-all shadow-xl shadow-amber-500/20 disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <Send size={16} /> {transferBusy ? 'Processing Transfer...' : 'Send Commission to Reseller'}
            </button>

            {transferResult && (
              <div className="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-2xl text-emerald-400 text-xs font-mono space-y-1">
                <p className="font-black text-sm">✅ Transfer Executed Successfully</p>
                <p>Hash: {transferResult.transactionId}</p>
                <p>Recipient: {transferResult.targetName}</p>
                <p>Amount: ${transferResult.transferAmountUSD} USD</p>
              </div>
            )}
          </form>
        )}

        {/* Action 2: Direct Cashout Form */}
        {activeAction === 'withdraw' && (
          <form onSubmit={handleWithdrawal} className="pt-8 space-y-6 max-w-2xl">
            <div>
              <h3 className="text-xl font-black text-white uppercase tracking-wider flex items-center gap-3">
                <CreditCard className="text-emerald-400" size={24} />
                Multi-Gateway Cashout Request
              </h3>
              <p className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-1">
                Submit withdrawal request for Owner approval across verified payout gateways
              </p>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Payout Gateway</label>
              <select
                value={withdrawGateway}
                onChange={e => setWithdrawGateway(e.target.value)}
                className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-bold outline-none focus:border-emerald-500 text-sm"
              >
                {policy.supportedGateways.map(g => (
                  <option key={g} value={g}>{g}</option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">
                Account Details / Number / Address
              </label>
              <input
                type="text"
                required
                value={withdrawAccount}
                onChange={e => setWithdrawAccount(e.target.value)}
                placeholder="e.g. +8801700000000 or Bank Acc # or USDT TRC20 Wallet"
                className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-bold outline-none focus:border-emerald-500 text-sm"
              />
            </div>

            <div className="space-y-2">
              <div className="flex justify-between items-center ml-1">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">
                  Withdrawal USD ($) (Min: ${policy.minWithdrawalUSD})
                </label>
                <button
                  type="button"
                  onClick={() => setWithdrawAmount(wallet.usdCommissionBalance.toString())}
                  className="text-[10px] font-black text-emerald-400 uppercase hover:underline"
                >
                  Max (${wallet.usdCommissionBalance.toFixed(2)})
                </button>
              </div>
              <input
                type="number"
                step="0.01"
                min={policy.minWithdrawalUSD}
                required
                value={withdrawAmount}
                onChange={e => setWithdrawAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-xl outline-none focus:border-emerald-500"
              />
            </div>

            <button
              type="submit"
              disabled={withdrawBusy || wallet.usdCommissionBalance < policy.minWithdrawalUSD}
              className="w-full py-4 bg-emerald-500 hover:bg-emerald-600 text-black font-black uppercase text-xs tracking-widest rounded-2xl transition-all shadow-xl shadow-emerald-500/20 disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <ArrowDownLeft size={16} /> {withdrawBusy ? 'Submitting Request...' : 'Submit Cashout Request'}
            </button>
          </form>
        )}

        {/* Action 3: Convert to Diamonds */}
        {activeAction === 'convert' && (
          <form onSubmit={handleConversion} className="pt-8 space-y-6 max-w-2xl">
            <div>
              <h3 className="text-xl font-black text-white uppercase tracking-wider flex items-center gap-3">
                <Diamond className="text-cyan-400" size={24} />
                USD Commission &rarr; Diamonds Conversion
              </h3>
              <p className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-1">
                Rate: $1 USD = {policy.usdToDiamondRate.toLocaleString()} Diamonds (Owner configured)
              </p>
            </div>

            <div className="space-y-2">
              <div className="flex justify-between items-center ml-1">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">USD to Convert ($)</label>
                <button
                  type="button"
                  onClick={() => setConvertAmount(wallet.usdCommissionBalance.toString())}
                  className="text-[10px] font-black text-cyan-400 uppercase hover:underline"
                >
                  Max (${wallet.usdCommissionBalance.toFixed(2)})
                </button>
              </div>
              <input
                type="number"
                step="0.01"
                min="0.01"
                required
                value={convertAmount}
                onChange={e => setConvertAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-xl outline-none focus:border-cyan-500"
              />
            </div>

            {convertAmount && !isNaN(parseFloat(convertAmount)) && (
              <div className="p-4 bg-cyan-500/10 border border-cyan-500/20 rounded-2xl text-cyan-400 text-sm font-bold flex items-center justify-between">
                <span>You will receive:</span>
                <span className="text-lg font-black font-mono">
                  {Math.floor(parseFloat(convertAmount) * policy.usdToDiamondRate).toLocaleString()} 💎
                </span>
              </div>
            )}

            <button
              type="submit"
              disabled={convertBusy || wallet.usdCommissionBalance <= 0}
              className="w-full py-4 bg-cyan-500 hover:bg-cyan-600 text-black font-black uppercase text-xs tracking-widest rounded-2xl transition-all shadow-xl shadow-cyan-500/20 disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <Diamond size={16} /> {convertBusy ? 'Converting...' : 'Convert to Diamonds'}
            </button>
          </form>
        )}
      </div>

      {/* Audit History Tables */}
      <div className="bg-[#09090B] border border-white/10 rounded-[36px] overflow-hidden shadow-2xl">
        <div className="p-8 border-b border-white/5 flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white/[0.02]">
          <div className="flex items-center gap-3">
            <History className="text-indigo-400" size={24} />
            <div>
              <h3 className="text-xl font-black text-white uppercase tracking-wider">Audit Ledgers & Logs</h3>
              <p className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-1">Immutable server-recorded transaction history</p>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            {[
              { id: 'transfers', label: 'Reseller Transfers' },
              { id: 'withdrawals', label: 'Cashout Requests' },
              { id: 'conversions', label: 'Diamond Conversions' },
              { id: 'inflows', label: 'Commission Inflows' }
            ].map(tab => (
              <button
                key={tab.id}
                onClick={() => setHistoryTab(tab.id)}
                className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                  historyTab === tab.id
                    ? 'bg-indigo-600 text-white'
                    : 'bg-white/5 text-slate-400 hover:text-white'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {historyLoading ? (
          <div className="py-20 text-center animate-pulse font-black text-slate-600 uppercase tracking-widest text-xs">
            Loading Ledger Records...
          </div>
        ) : historyList.length === 0 ? (
          <div className="py-20 text-center text-slate-600 font-bold uppercase tracking-widest text-xs">
            No records found for {historyTab}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-white/5 text-[10px] font-black text-slate-500 uppercase tracking-widest bg-white/[0.01]">
                  <th className="px-6 py-4">Transaction / ID</th>
                  <th className="px-6 py-4">Details</th>
                  <th className="px-6 py-4">Amount</th>
                  <th className="px-6 py-4">Status</th>
                  <th className="px-6 py-4">Date / Time (UTC)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {historyList.map(item => (
                  <tr key={item.id} className="hover:bg-white/[0.01]">
                    <td className="px-6 py-4 font-mono font-bold text-slate-300">
                      {item.transactionId || item.requestId || item.txId || item.id}
                    </td>
                    <td className="px-6 py-4">
                      {historyTab === 'transfers' && (
                        <span>To: <strong className="text-white">{item.targetName}</strong> (ID: {item.targetHelloId})</span>
                      )}
                      {historyTab === 'withdrawals' && (
                        <span>via <strong className="text-white">{item.paymentMethod}</strong> ({item.paymentAccountDetails})</span>
                      )}
                      {historyTab === 'conversions' && (
                        <span>Credited: <strong className="text-cyan-400">{item.diamondsReceived?.toLocaleString()} 💎</strong></span>
                      )}
                      {historyTab === 'inflows' && (
                        <span>From host <strong className="text-white">{item.hostUid?.slice(0, 10)}...</strong> ({((item.commissionRate || 0) * 100).toFixed(0)}%)</span>
                      )}
                    </td>
                    <td className="px-6 py-4 font-black">
                      <span className="text-emerald-400">
                        ${(item.transferAmountUSD || item.usdAmount || item.commissionUSD || 0).toFixed(2)} USD
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2.5 py-1 rounded-full text-[9px] font-black uppercase ${
                        (item.status === 'completed' || item.status === 'paid') ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' :
                        item.status === 'rejected' ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20' :
                        'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                      }`}>
                        {item.status || 'completed'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-500 font-mono text-[10px]">
                      {(() => {
                        // listMyLedger serializes Timestamps to ISO strings; a
                        // direct Firestore read still yields a Timestamp.
                        const raw = item.createdAt || item.timestamp;
                        if (!raw) return 'N/A';
                        if (typeof raw === 'string') return new Date(raw).toUTCString();
                        if (raw.toDate) return raw.toDate().toUTCString();
                        return 'N/A';
                      })()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

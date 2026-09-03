import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  doc, 
  getDoc, 
  setDoc, 
  collection, 
  query, 
  orderBy, 
  limit, 
  onSnapshot, 
  serverTimestamp 
} from 'firebase/firestore';
import { 
  Sparkles, 
  Save, 
  Plus, 
  Trash2, 
  AlertTriangle, 
  CheckCircle2, 
  RefreshCw, 
  Search, 
  History, 
  Sliders, 
  Coins, 
  Gift as GiftIcon 
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

const DEFAULT_MULTIPLIERS = [
  { multiplier: 0, winningAmount: 0, probability: 45.0, enabled: true },
  { multiplier: 1, winningAmount: 5, probability: 25.0, enabled: true },
  { multiplier: 2, winningAmount: 10, probability: 15.0, enabled: true },
  { multiplier: 5, winningAmount: 25, probability: 7.0, enabled: true },
  { multiplier: 10, winningAmount: 50, probability: 4.0, enabled: true },
  { multiplier: 20, winningAmount: 100, probability: 2.0, enabled: true },
  { multiplier: 50, winningAmount: 250, probability: 1.0, enabled: true },
  { multiplier: 100, winningAmount: 500, probability: 1.0, enabled: true },
  { multiplier: 300, winningAmount: 1500, probability: 0.0, enabled: false },
  { multiplier: 1000, winningAmount: 5000, probability: 0.0, enabled: false },
];

export const WinningConfigManagement = () => {
  const { user } = useAdmin();
  const [activeTab, setActiveTab] = useState('config'); // 'config' | 'history'
  
  // Configuration State
  const [giftPrice, setGiftPrice] = useState(5);
  const [receiverBeanReward, setReceiverBeanReward] = useState(1);
  const [multipliers, setMultipliers] = useState(DEFAULT_MULTIPLIERS);
  const [loadingConfig, setLoadingConfig] = useState(true);
  const [saving, setSaving] = useState(false);

  // History State
  const [transactions, setTransactions] = useState([]);
  const [loadingHistory, setLoadingHistory] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  // Fetch Winning Configuration
  useEffect(() => {
    const fetchConfig = async () => {
      try {
        const configRef = doc(db, "system_settings", "lucky_gift_config");
        const snap = await getDoc(configRef);
        if (snap.exists()) {
          const data = snap.data();
          if (data.giftPrice != null) setGiftPrice(data.giftPrice);
          if (data.receiverBeanReward != null) setReceiverBeanReward(data.receiverBeanReward);
          if (Array.isArray(data.multipliers) && data.multipliers.length > 0) {
            setMultipliers(data.multipliers);
          }
        }
      } catch (err) {
        console.error("Error fetching lucky gift config:", err);
      } finally {
        setLoadingConfig(false);
      }
    };
    fetchConfig();
  }, []);

  // Fetch History Logs
  useEffect(() => {
    if (activeTab !== 'history') return;
    const q = query(
      collection(db, "lucky_gift_transactions"), 
      orderBy("createdAt", "desc"), 
      limit(100)
    );
    const unsub = onSnapshot(q, (snap) => {
      setTransactions(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoadingHistory(false);
    }, (err) => {
      console.error("Error fetching transactions:", err);
      setLoadingHistory(false);
    });

    return () => unsub();
  }, [activeTab]);

  // Calculate Total Probability of Enabled Multipliers
  const enabledMultipliers = multipliers.filter(m => m.enabled !== false);
  const totalProbability = enabledMultipliers.reduce((sum, item) => sum + (parseFloat(item.probability) || 0), 0);
  const isProbabilityValid = Math.abs(totalProbability - 100.0) < 0.01;

  // Handle Input Changes
  const handleMultiplierChange = (index, field, value) => {
    setMultipliers(prev => {
      const copy = [...prev];
      if (field === 'enabled') {
        copy[index].enabled = value;
      } else {
        const numVal = parseFloat(value);
        copy[index][field] = isNaN(numVal) ? 0 : numVal;
      }
      return copy;
    });
  };

  const handleAddRow = () => {
    setMultipliers(prev => [
      ...prev,
      { multiplier: 0, winningAmount: 0, probability: 0, enabled: true }
    ]);
  };

  const handleRemoveRow = (index) => {
    if (multipliers.length <= 1) {
      alert("At least one multiplier row is required.");
      return;
    }
    setMultipliers(prev => prev.filter((_, i) => i !== index));
  };

  // Save Configuration to Firestore
  const handleSaveConfig = async () => {
    if (!isProbabilityValid) {
      alert(`❌ Invalid Total Probability! Sum must be exactly 100%. Current sum: ${totalProbability.toFixed(2)}%`);
      return;
    }

    setSaving(true);
    try {
      const configRef = doc(db, "system_settings", "lucky_gift_config");
      const payload = {
        giftPrice: Number(giftPrice || 5),
        receiverBeanReward: Number(receiverBeanReward || 1),
        multipliers: multipliers.map(m => ({
          multiplier: Number(m.multiplier || 0),
          winningAmount: Number(m.winningAmount || 0),
          probability: Number(m.probability || 0),
          enabled: m.enabled !== false
        })),
        updatedAt: serverTimestamp(),
        updatedBy: user?.email || 'admin'
      };

      await setDoc(configRef, payload, { merge: true });
      await logAdminAction(user, "LUCKY_GIFT_CONFIG_UPDATE", "lucky_gift_config", payload);

      alert("✅ Winning configuration saved successfully!");
    } catch (e) {
      alert("Save Error: " + e.message);
    } finally {
      setSaving(false);
    }
  };

  const filteredTransactions = transactions.filter(tx => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    return (
      (tx.senderName || '').toLowerCase().includes(term) ||
      (tx.senderUid || '').toLowerCase().includes(term) ||
      (tx.receiverName || '').toLowerCase().includes(term) ||
      (tx.targetUid || '').toLowerCase().includes(term) ||
      (tx.transactionId || '').toLowerCase().includes(term) ||
      (tx.giftName || '').toLowerCase().includes(term)
    );
  });

  return (
    <div className="p-6 space-y-6">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-900/80 p-6 rounded-3xl border border-white/10 backdrop-blur-xl">
        <div>
          <div className="flex items-center gap-3">
            <div className="p-3 bg-amber-500/20 text-amber-400 rounded-2xl border border-amber-500/30">
              <Sparkles className="w-6 h-6 animate-pulse" />
            </div>
            <div>
              <h1 className="text-2xl font-black text-white tracking-tight">Bell / Lucky Gift Winning System</h1>
              <p className="text-slate-400 text-xs mt-1">Configure probability-based winning multipliers & view backend audit logs</p>
            </div>
          </div>
        </div>

        {/* Tab Switchers */}
        <div className="flex items-center gap-2 bg-black/40 p-1.5 rounded-2xl border border-white/10">
          <button
            onClick={() => setActiveTab('config')}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'config'
                ? 'bg-amber-500 text-slate-950 shadow-lg shadow-amber-500/20'
                : 'text-slate-400 hover:text-white hover:bg-white/5'
            }`}
          >
            <Sliders className="w-4 h-4" />
            Probability Config
          </button>
          <button
            onClick={() => setActiveTab('history')}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'history'
                ? 'bg-amber-500 text-slate-950 shadow-lg shadow-amber-500/20'
                : 'text-slate-400 hover:text-white hover:bg-white/5'
            }`}
          >
            <History className="w-4 h-4" />
            Winning History & Audit
          </button>
        </div>
      </div>

      {activeTab === 'config' ? (
        <div className="space-y-6">
          {/* Main Parameters Card */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-slate-900/60 p-6 rounded-3xl border border-white/10 space-y-4">
              <div className="flex items-center gap-2 text-amber-400 font-bold text-sm uppercase tracking-wider">
                <Coins className="w-4 h-4" />
                Sender Cost Parameter
              </div>
              <div>
                <label className="text-xs text-slate-400 font-semibold block mb-2">Default Bell / Lucky Gift Price (Diamonds)</label>
                <input
                  type="number"
                  min="1"
                  value={giftPrice}
                  onChange={(e) => setGiftPrice(parseFloat(e.target.value) || 0)}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-4 py-3 text-white text-sm focus:outline-none focus:border-amber-500/50"
                  placeholder="e.g. 5"
                />
                <p className="text-[11px] text-slate-500 mt-2">Cost deducted from Sender per gift send.</p>
              </div>
            </div>

            <div className="bg-slate-900/60 p-6 rounded-3xl border border-white/10 space-y-4">
              <div className="flex items-center gap-2 text-emerald-400 font-bold text-sm uppercase tracking-wider">
                <GiftIcon className="w-4 h-4" />
                Receiver Base Contribution Parameter
              </div>
              <div>
                <label className="text-xs text-slate-400 font-semibold block mb-2">Receiver Reward (Beans per Gift)</label>
                <input
                  type="number"
                  min="1"
                  value={receiverBeanReward}
                  onChange={(e) => setReceiverBeanReward(parseFloat(e.target.value) || 0)}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-4 py-3 text-white text-sm focus:outline-none focus:border-emerald-500/50"
                  placeholder="e.g. 1"
                />
                <p className="text-[11px] text-slate-500 mt-2">Beans credited to Receiver's account. Independent of Sender's winning multiplier.</p>
              </div>
            </div>
          </div>

          {/* Multiplier Probability Matrix */}
          <div className="bg-slate-900/60 rounded-3xl border border-white/10 overflow-hidden">
            <div className="p-6 border-b border-white/10 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h2 className="text-lg font-bold text-white">Winning Multipliers & Probability Matrix</h2>
                <p className="text-xs text-slate-400 mt-0.5">Define multiplier values, winning amounts, and percentage probabilities</p>
              </div>

              {/* Total Probability Meter */}
              <div className={`px-4 py-2 rounded-2xl border flex items-center gap-3 ${
                isProbabilityValid 
                  ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' 
                  : 'bg-rose-500/10 border-rose-500/30 text-rose-400'
              }`}>
                {isProbabilityValid ? (
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                ) : (
                  <AlertTriangle className="w-5 h-5 text-rose-400 animate-bounce" />
                )}
                <div>
                  <div className="text-[10px] uppercase font-black tracking-wider opacity-80">Total Probability</div>
                  <div className="text-base font-black">{totalProbability.toFixed(2)}% {isProbabilityValid ? '(Valid)' : '(Must be 100%)'}</div>
                </div>
              </div>
            </div>

            {/* Probability Warning Alert */}
            {!isProbabilityValid && (
              <div className="bg-rose-500/10 border-b border-rose-500/20 px-6 py-3 text-rose-300 text-xs flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 shrink-0" />
                  <span>The sum of enabled probabilities is <strong>{totalProbability.toFixed(2)}%</strong>. Please adjust values so the total equals <strong>100.00%</strong> before saving.</span>
                </div>
              </div>
            )}

            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-sm">
                <thead>
                  <tr className="bg-black/30 text-slate-400 text-xs uppercase font-bold tracking-wider border-b border-white/10">
                    <th className="px-6 py-4">Status</th>
                    <th className="px-6 py-4">Multiplier</th>
                    <th className="px-6 py-4">Winning Amount (Diamonds)</th>
                    <th className="px-6 py-4">Probability (%)</th>
                    <th className="px-6 py-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5 text-slate-200">
                  {multipliers.map((row, idx) => (
                    <tr key={idx} className={`group hover:bg-white/5 transition-colors ${!row.enabled ? 'opacity-40 bg-black/20' : ''}`}>
                      <td className="px-6 py-4">
                        <label className="relative inline-flex items-center cursor-pointer">
                          <input
                            type="checkbox"
                            checked={row.enabled !== false}
                            onChange={(e) => handleMultiplierChange(idx, 'enabled', e.target.checked)}
                            className="sr-only peer"
                          />
                          <div className="w-9 h-5 bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-amber-500"></div>
                        </label>
                      </td>
                      <td className="px-6 py-4 font-bold text-white">
                        <div className="flex items-center gap-2">
                          <span className="text-amber-400 font-black">{row.multiplier}×</span>
                          <input
                            type="number"
                            step="any"
                            min="0"
                            value={row.multiplier}
                            onChange={(e) => handleMultiplierChange(idx, 'multiplier', e.target.value)}
                            className="w-20 bg-black/40 border border-white/10 rounded-xl px-3 py-1.5 text-xs text-white focus:border-amber-500/50"
                          />
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <span className="text-cyan-400 font-bold">💎</span>
                          <input
                            type="number"
                            min="0"
                            value={row.winningAmount}
                            onChange={(e) => handleMultiplierChange(idx, 'winningAmount', e.target.value)}
                            className="w-28 bg-black/40 border border-white/10 rounded-xl px-3 py-1.5 text-xs text-white focus:border-amber-500/50"
                          />
                          <span className="text-slate-500 text-xs">({giftPrice * row.multiplier} D default)</span>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <input
                            type="number"
                            step="0.01"
                            min="0"
                            max="100"
                            value={row.probability}
                            onChange={(e) => handleMultiplierChange(idx, 'probability', e.target.value)}
                            className="w-28 bg-black/40 border border-white/10 rounded-xl px-3 py-1.5 text-xs text-white font-bold focus:border-amber-500/50"
                          />
                          <span className="text-slate-400 text-xs font-bold">%</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <button
                          onClick={() => handleRemoveRow(idx)}
                          className="p-2 text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 rounded-xl transition-all"
                          title="Remove Multiplier"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Bottom Actions */}
            <div className="p-6 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-4 bg-black/20">
              <button
                onClick={handleAddRow}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-white/10 text-slate-300 hover:text-white hover:bg-white/5 text-xs font-bold transition-all"
              >
                <Plus className="w-4 h-4" />
                Add Multiplier Row
              </button>

              <button
                onClick={handleSaveConfig}
                disabled={saving || !isProbabilityValid}
                className={`flex items-center gap-2 px-8 py-3 rounded-2xl font-bold text-xs uppercase tracking-wider shadow-lg transition-all ${
                  isProbabilityValid && !saving
                    ? 'bg-amber-500 hover:bg-amber-400 text-slate-950 shadow-amber-500/20 cursor-pointer'
                    : 'bg-slate-800 text-slate-500 cursor-not-allowed border border-white/5'
                }`}
              >
                {saving ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                Save & Activate Config
              </button>
            </div>
          </div>
        </div>
      ) : (
        /* History & Audit Tab */
        <div className="bg-slate-900/60 rounded-3xl border border-white/10 overflow-hidden space-y-4">
          <div className="p-6 border-b border-white/10 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-bold text-white">Lucky Gift Audit History</h2>
              <p className="text-xs text-slate-400 mt-0.5">Real-time record of all Bell / Lucky Gift send transactions</p>
            </div>

            {/* Search Input */}
            <div className="relative w-full sm:w-72">
              <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-500" />
              <input
                type="text"
                placeholder="Search Sender, Receiver, Tx ID..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full bg-black/40 border border-white/10 rounded-2xl pl-10 pr-4 py-2 text-xs text-white focus:outline-none focus:border-amber-500/50"
              />
            </div>
          </div>

          <div className="overflow-x-auto">
            {loadingHistory ? (
              <div className="p-12 text-center text-slate-500 text-sm flex items-center justify-center gap-2">
                <RefreshCw className="w-4 h-4 animate-spin" /> Loading transaction logs...
              </div>
            ) : filteredTransactions.length === 0 ? (
              <div className="p-12 text-center text-slate-500 text-sm">
                No lucky gift transaction history found matching your search.
              </div>
            ) : (
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="bg-black/40 text-slate-400 uppercase font-bold tracking-wider border-b border-white/10">
                    <th className="px-6 py-4">Tx ID / Date</th>
                    <th className="px-6 py-4">Sender</th>
                    <th className="px-6 py-4">Receiver</th>
                    <th className="px-6 py-4">Gift Price</th>
                    <th className="px-6 py-4">Multiplier</th>
                    <th className="px-6 py-4">Winning Amount</th>
                    <th className="px-6 py-4">Receiver Beans</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5 text-slate-200">
                  {filteredTransactions.map((tx) => (
                    <tr key={tx.id} className="hover:bg-white/5 transition-colors">
                      <td className="px-6 py-4 font-mono text-slate-400">
                        <div className="font-bold text-white">{tx.transactionId || tx.id.slice(0, 10)}</div>
                        <div className="text-[10px] text-slate-500 mt-0.5">
                          {tx.createdAt?.toDate ? tx.createdAt.toDate().toLocaleString() : 'Just now'}
                        </div>
                      </td>
                      <td className="px-6 py-4 font-bold text-white">
                        <div>{tx.senderName || 'User'}</div>
                        <div className="text-[10px] text-slate-500 font-mono">ID: {tx.senderUid}</div>
                      </td>
                      <td className="px-6 py-4 font-bold text-emerald-400">
                        <div>{tx.receiverName || 'User'}</div>
                        <div className="text-[10px] text-slate-500 font-mono">ID: {tx.targetUid}</div>
                      </td>
                      <td className="px-6 py-4">
                        <span className="font-bold text-white">💎 {tx.totalCost || tx.giftPrice || 5}</span>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`px-2.5 py-1 rounded-lg font-black ${
                          tx.winningMultiplier > 0 
                            ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' 
                            : 'bg-white/5 text-slate-500'
                        }`}>
                          {tx.winningMultiplier || 0}×
                        </span>
                      </td>
                      <td className="px-6 py-4 font-bold">
                        {tx.winningAmount > 0 ? (
                          <span className="text-amber-400 font-black">+💎 {tx.winningAmount.toLocaleString()}</span>
                        ) : (
                          <span className="text-slate-500">0</span>
                        )}
                      </td>
                      <td className="px-6 py-4 font-bold text-emerald-400">
                        +🫘 {tx.receiverBeans || 1}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

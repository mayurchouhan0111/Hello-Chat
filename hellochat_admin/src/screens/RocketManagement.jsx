import { useState, useEffect } from 'react';
import { doc, onSnapshot, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import { 
  Rocket, 
  Save, 
  Loader2, 
  CheckCircle, 
  AlertCircle,
  TrendingUp,
  Sparkles,
  Award,
  Zap,
  Info
} from 'lucide-react';
import { motion } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const RocketManagement = () => {
  const { user } = useAdmin();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState(null);

  // 5 Rocket Levels launch thresholds (in Diamonds)
  const [targets, setTargets] = useState([1000000, 2000000, 3000000, 5000000, 10000000]);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, "system_configs", "rocket_settings"), (snap) => {
      if (snap.exists() && Array.isArray(snap.data()?.targets) && snap.data().targets.length === 5) {
        setTargets(snap.data().targets);
      }
      setLoading(false);
    }, (err) => {
      console.error("Error loading rocket settings:", err);
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleTargetChange = (index, value) => {
    const newTargets = [...targets];
    // Remove non-digits
    const clean = value.replace(/[^0-9]/g, '');
    newTargets[index] = clean === '' ? 0 : parseInt(clean, 10);
    setTargets(newTargets);
  };

  const showToast = (type, message) => {
    setToast({ type, message });
    setTimeout(() => setToast(null), 4000);
  };

  const handleSave = async () => {
    // Validate inputs
    for (let i = 0; i < targets.length; i++) {
      if (!Number.isFinite(targets[i]) || targets[i] <= 0) {
        showToast('error', `Rocket ${i + 1} threshold must be a valid positive number.`);
        return;
      }
    }

    setSaving(true);
    try {
      await setDoc(doc(db, "system_configs", "rocket_settings"), {
        targets: targets.map(t => parseInt(t, 10)),
        updatedAt: serverTimestamp(),
        updatedBy: user?.email || 'admin'
      }, { merge: true });

      await logAdminAction(user, "ROCKET_SETTINGS_UPDATE", "rocket_settings", { targets });
      showToast('success', 'Rocket launch thresholds updated successfully!');
    } catch (err) {
      console.error("Failed to save rocket settings:", err);
      showToast('error', `Save failed: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const rocketCards = [
    { level: 1, name: 'Level 1 Rocket', color: 'from-amber-500 to-orange-600', badge: '1M DEFAULT', icon: Zap, reward: '30K King Rebate + 2K XP' },
    { level: 2, name: 'Level 2 Rocket', color: 'from-blue-500 to-cyan-600', badge: '2M DEFAULT', icon: Sparkles, reward: '60K King Rebate + 3K XP' },
    { level: 3, name: 'Level 3 Rocket', color: 'from-purple-500 to-indigo-600', badge: '3M DEFAULT', icon: Award, reward: '200K King Rebate + 5K XP' },
    { level: 4, name: 'Level 4 Rocket', color: 'from-pink-500 to-rose-600', badge: '5M DEFAULT', icon: TrendingUp, reward: '500K King Rebate + 10K XP' },
    { level: 5, name: 'Level 5 Rocket', color: 'from-emerald-500 to-teal-600', badge: '10M DEFAULT', icon: Rocket, reward: '800K King Rebate + 15K XP (72h Frame)' },
  ];

  const formatNumber = (num) => {
    return (num || 0).toLocaleString();
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Toast Notification */}
      {toast && (
        <motion.div 
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -20 }}
          className={`fixed top-24 right-10 z-50 px-6 py-4 rounded-2xl flex items-center gap-3 border shadow-2xl backdrop-blur-xl ${
            toast.type === 'success' 
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' 
              : 'bg-rose-500/10 border-rose-500/30 text-rose-400'
          }`}
        >
          {toast.type === 'success' ? <CheckCircle size={20} /> : <AlertCircle size={20} />}
          <span className="font-black text-xs uppercase tracking-wider">{toast.message}</span>
        </motion.div>
      )}

      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-amber-500/20 rounded-2xl border border-amber-500/30">
              <Rocket className="text-amber-400" size={28} />
            </div>
            Rocket System Configuration
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Dynamic Launch Threshold & Diamond Fuel Management
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={saving || loading}
          className="flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-white rounded-2xl font-black uppercase text-xs tracking-widest shadow-xl shadow-amber-500/20 transition-all disabled:opacity-50"
        >
          {saving ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
          {saving ? 'Saving Changes...' : 'Save Configuration'}
        </button>
      </div>

      {/* Overview Banner */}
      <div className="bg-[#18181B]/80 border border-white/10 rounded-3xl p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-6 relative overflow-hidden">
        <div className="flex items-start gap-4">
          <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-2xl text-blue-400">
            <Info size={24} />
          </div>
          <div>
            <h3 className="font-black text-white text-sm uppercase tracking-wider">Sequential Launch Rules</h3>
            <p className="text-slate-400 text-xs mt-1 leading-relaxed max-w-3xl font-medium">
              When a user sends a single large Diamond gift (e.g. 50,000,000 Diamonds), the backend will automatically process and launch each reached threshold in sequence (Rocket 1 → Rocket 2 → Rocket 3 → Rocket 4 → Rocket 5) without requiring additional gift sendings.
            </p>
          </div>
        </div>
      </div>

      {loading ? (
        <div className="py-35 text-center text-slate-600 font-black tracking-widest uppercase animate-pulse">
          Loading Rocket Threshold Configuration...
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {rocketCards.map(({ level, name, color, badge, icon: Icon, reward }, idx) => {
            const currentVal = targets[idx] ?? 0;
            return (
              <motion.div
                key={level}
                whileHover={{ y: -4 }}
                className="bg-[#18181B]/80 border border-white/10 rounded-3xl p-6 shadow-2xl relative overflow-hidden flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between border-b border-white/5 pb-4 mb-6">
                    <div className="flex items-center gap-3">
                      <div className={`p-3 rounded-2xl bg-gradient-to-br ${color} text-white shadow-lg`}>
                        <Icon size={22} />
                      </div>
                      <div>
                        <h3 className="font-black text-white text-base tracking-tight">{name}</h3>
                        <span className="text-[9px] font-black text-slate-400 tracking-widest uppercase">
                          LEVEL {level} • {badge}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Reward Summary Badge */}
                  <div className="bg-slate-950/60 border border-white/5 rounded-2xl p-4 mb-6">
                    <span className="text-[9px] font-black text-amber-400 tracking-widest uppercase block mb-1">
                      Target Winner Reward
                    </span>
                    <span className="text-xs font-bold text-slate-300">
                      {reward}
                    </span>
                  </div>

                  {/* Threshold Input */}
                  <div className="space-y-3 mb-4">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1 flex items-center justify-between">
                      <span>Required Diamond Amount</span>
                      <span className="text-amber-400 font-mono font-bold text-xs">
                        {formatNumber(currentVal)} Diamonds
                      </span>
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        placeholder="Enter diamond threshold..."
                        value={currentVal}
                        onChange={(e) => handleTargetChange(idx, e.target.value)}
                        className="w-full h-12 bg-slate-950/80 border border-white/10 rounded-xl px-4 text-sm font-mono font-bold text-white focus:outline-none focus:border-amber-500 transition-colors"
                      />
                      <div className="absolute right-4 top-1/2 -translate-y-1/2 text-xs font-black text-slate-500 pointer-events-none">
                        💎
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
};

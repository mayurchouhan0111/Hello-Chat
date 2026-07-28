import { useState, useEffect } from 'react';
import { 
  collection, 
  query, 
  getDocs, 
  doc, 
  setDoc, 
  updateDoc,
  onSnapshot,
  orderBy,
  where,
  serverTimestamp 
} from 'firebase/firestore';
import { db, functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { 
  Crown, 
  Zap, 
  Star, 
  Search, 
  RefreshCw, 
  ShieldCheck, 
  UserCheck, 
  Clock, 
  Award, 
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Sliders,
  FileText
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const SVIPManagement = () => {
  const [activeTab, setActiveTab] = useState("levels"); // "levels", "users", "audit_logs", "banners"
  const [loading, setLoading] = useState(true);
  const [auditLogs, setAuditLogs] = useState([]);
  const [banners, setBanners] = useState([]);
  
  // User Search & Adjustment State
  const [searchQuery, setSearchQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [pointAdjustment, setPointAdjustment] = useState("");
  const [selectedOverrideLevel, setSelectedOverrideLevel] = useState(1);
  const [extendingDays, setExtendingDays] = useState(60);
  const [processing, setProcessing] = useState(false);
  
  const { user: currentAdmin } = useAdmin();

  // SVIP Tier Configuration Constants
  const defaultSvipTiers = [
    { level: 1, name: "SVIP 1", points: 5000, usd: 50.0, dailyReward: 25000, color: "#FDE047" },
    { level: 2, name: "SVIP 2", points: 10000, usd: 100.0, dailyReward: 50000, color: "#FACC15" },
    { level: 3, name: "SVIP 3", points: 20000, usd: 200.0, dailyReward: 100000, color: "#EAB308" },
    { level: 4, name: "SVIP 4", points: 50000, usd: 500.0, dailyReward: 250000, color: "#CA8A04" },
    { level: 5, name: "SVIP 5", points: 100000, usd: 1000.0, dailyReward: 500000, color: "#A16207" },
    { level: 6, name: "SVIP 6", points: 250000, usd: 2500.0, dailyReward: 1000000, color: "#854D0E" },
  ];

  useEffect(() => {
    // Audit Logs Listener
    const auditQuery = query(collection(db, "svip_audit_logs"), orderBy("timestamp", "desc"));
    const unsubAudit = onSnapshot(auditQuery, (snap) => {
      setAuditLogs(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    // Banners Listener
    const bannerQuery = query(collection(db, "svip_banners"), orderBy("createdAt", "desc"));
    const unsubBanners = onSnapshot(bannerQuery, (snap) => {
      setBanners(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });

    return () => {
      unsubAudit();
      unsubBanners();
    };
  }, []);

  const handleSearchUser = async (e) => {
    e.preventDefault();
    if (!searchQuery.trim()) return;
    setSearching(true);
    try {
      let q;
      const isNum = !isNaN(parseInt(searchQuery.trim()));
      if (isNum) {
        q = query(collection(db, "users"), where("helloId", "==", parseInt(searchQuery.trim())));
      } else {
        q = query(collection(db, "users"), where("username", "==", searchQuery.trim().toLowerCase()));
      }

      const snap = await getDocs(q);
      if (snap.empty) {
        alert("No user found with that Hello ID or Username.");
        setSelectedUser(null);
      } else {
        const uData = snap.docs[0].data();
        setSelectedUser({ id: snap.docs[0].id, ...uData });
      }
    } catch (err) {
      alert("User scan failed: " + err.message);
    } finally {
      setSearching(false);
    }
  };

  const handleAdjustPoints = async (action) => {
    if (!selectedUser) return;
    const pts = parseInt(pointAdjustment);
    if (action !== "reset" && (isNaN(pts) || pts <= 0)) {
      alert("Please enter a valid positive number for point adjustment.");
      return;
    }

    setProcessing(true);
    try {
      const userRef = doc(db, "users", selectedUser.id);
      let newPoints = selectedUser.svipPoints || 0;

      if (action === "add") newPoints += pts;
      else if (action === "deduct") newPoints = Math.max(0, newPoints - pts);
      else if (action === "reset") newPoints = 0;

      await updateDoc(userRef, { svipPoints: newPoints });

      // Audit Log
      await setDoc(doc(collection(db, "svip_audit_logs")), {
        uid: selectedUser.id,
        helloId: selectedUser.helloId,
        type: `admin_${action}_points`,
        pointsBefore: selectedUser.svipPoints || 0,
        pointsAdjusted: action === "reset" ? -(selectedUser.svipPoints || 0) : (action === "add" ? pts : -pts),
        pointsAfter: newPoints,
        adminUid: currentAdmin?.uid || "ADMIN",
        timestamp: serverTimestamp()
      });

      await logAdminAction(currentAdmin, `SVIP_POINTS_${action.toUpperCase()}`, selectedUser.id, { newPoints });
      setSelectedUser(prev => ({ ...prev, svipPoints: newPoints }));
      alert(`SVIP Points successfully updated (${action}).`);
      setPointAdjustment("");
    } catch (err) {
      alert("Point Adjustment Failed: " + err.message);
    } finally {
      setProcessing(false);
    }
  };

  const handleOverrideLevel = async () => {
    if (!selectedUser) return;
    if (!window.confirm(`Override ${selectedUser.displayName}'s SVIP level to SVIP ${selectedOverrideLevel}?`)) return;

    setProcessing(true);
    try {
      const userRef = doc(db, "users", selectedUser.id);
      const now = new Date();
      const sixtyDaysMs = 60 * 24 * 60 * 60 * 1000;
      const cycleEnd = new Date(now.getTime() + sixtyDaysMs);

      await updateDoc(userRef, {
        svipLevel: selectedOverrideLevel,
        svipPoints: 0, // Reset to 0 on level override
        svipCycleStartDate: now,
        svipCycleEndDate: cycleEnd
      });

      // Audit Log
      await setDoc(doc(collection(db, "svip_audit_logs")), {
        uid: selectedUser.id,
        helloId: selectedUser.helloId,
        type: "admin_level_override",
        previousLevel: selectedUser.svipLevel || 0,
        newLevel: selectedOverrideLevel,
        pointsAfterReset: 0,
        adminUid: currentAdmin?.uid || "ADMIN",
        timestamp: serverTimestamp()
      });

      await logAdminAction(currentAdmin, "SVIP_LEVEL_OVERRIDE", selectedUser.id, { level: selectedOverrideLevel });
      setSelectedUser(prev => ({
        ...prev,
        svipLevel: selectedOverrideLevel,
        svipPoints: 0
      }));
      alert(`User upgraded/downgraded to SVIP ${selectedOverrideLevel}. Points reset to 0.`);
    } catch (err) {
      alert("Override Failed: " + err.message);
    } finally {
      setProcessing(false);
    }
  };

  const handleReviewBanner = async (bannerId, approve) => {
    try {
      const reviewFn = httpsCallable(functions, "reviewSvipBanner");
      await reviewFn({ bannerId, approve });
      alert(`Banner ${approve ? 'approved' : 'rejected'}.`);
    } catch (err) {
      alert("Review Error: " + err.message);
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header HUD */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-amber-500/20 rounded-2xl border border-amber-500/30">
              <Crown className="text-amber-400" size={28} />
            </div>
            SVIP Membership Engine
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Recharge-Based Privilege Engine • 60-Day Cycles • Audit Logs
          </p>
        </div>
      </div>

      {/* Tabs Switcher */}
      <div className="flex gap-4 border-b border-white/5 pb-6">
        {[
          { id: "levels", label: "SVIP Level Matrix", icon: Sliders },
          { id: "users", label: "User Point & Tier Adjuster", icon: UserCheck },
          { id: "audit_logs", label: "Audit & Reset Logs", icon: FileText },
          { id: "banners", label: "Banner Approvals", icon: Star },
        ].map(t => {
          const Icon = t.icon;
          return (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              className={`flex items-center gap-2 px-8 py-3.5 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all ${
                activeTab === t.id ? 'bg-amber-500 text-black shadow-lg shadow-amber-500/20' : 'bg-white/5 text-slate-400 hover:text-white'
              }`}
            >
              <Icon size={16} /> {t.label}
            </button>
          );
        })}
      </div>

      {/* Tab 1: SVIP Level Matrix */}
      {activeTab === "levels" && (
        <div className="space-y-8 animate-fade-in">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {defaultSvipTiers.map(tier => (
              <div 
                key={tier.level}
                className="card-glass p-8 bg-[#18181B]/80 border-white/10 rounded-2xl relative overflow-hidden space-y-6"
              >
                <div className="flex items-center justify-between">
                  <span className="text-xs font-black px-3 py-1 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded-full uppercase tracking-wider">
                    {tier.name}
                  </span>
                  <span className="text-xs font-mono font-bold text-emerald-400">${tier.usd.toLocaleString()} USD</span>
                </div>

                <div>
                  <h3 className="text-3xl font-black text-white">{tier.points.toLocaleString()} <span className="text-xs text-slate-500 font-bold">PTS</span></h3>
                  <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest mt-1">1 USD = 100 SVIP Points</p>
                </div>

                <div className="bg-white/5 p-4 rounded-xl space-y-2 border border-white/5 text-xs">
                  <div className="flex justify-between">
                    <span className="text-slate-400">Validity Window</span>
                    <span className="font-bold text-white">60 Days</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-400">Daily Reward</span>
                    <span className="font-bold text-amber-400">{tier.dailyReward.toLocaleString()} 💎</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Tab 2: User Point & Tier Adjuster */}
      {activeTab === "users" && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 animate-fade-in">
          {/* User Lookup */}
          <div className="card-glass p-10 bg-[#18181B]/80 border-amber-500/30 shadow-2xl space-y-8">
            <h3 className="text-xl font-black text-white uppercase tracking-tight flex items-center gap-3 border-b border-white/5 pb-4">
              <Search className="text-amber-400" size={20} /> User Lookup
            </h3>
            <form onSubmit={handleSearchUser} className="space-y-4">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Search by Hello ID or Username</label>
                <div className="flex gap-4">
                  <input
                    required
                    placeholder="Enter Hello ID (e.g. 100234) or Username..."
                    className="input-field flex-1 h-14 bg-slate-950/50 text-white font-mono px-4 rounded-2xl"
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                  />
                  <button
                    type="submit"
                    disabled={searching}
                    className="px-6 bg-amber-500 hover:bg-amber-600 text-black font-black uppercase text-xs tracking-wider rounded-2xl transition-all"
                  >
                    {searching ? "Searching..." : "Scan"}
                  </button>
                </div>
              </div>
            </form>

            {selectedUser && (
              <div className="bg-white/5 p-6 rounded-2xl border border-white/10 space-y-4 animate-fade-in">
                <div className="flex items-center gap-4">
                  <img src={selectedUser.profilePhotoUrl || "https://picsum.photos/100"} alt="avatar" className="w-16 h-16 rounded-full object-cover border border-white/10" />
                  <div>
                    <h4 className="text-lg font-black text-white">{selectedUser.displayName}</h4>
                    <p className="text-xs text-slate-400 font-mono">Hello ID: {selectedUser.helloId}</p>
                    <span className="inline-block mt-2 text-xs font-black px-3 py-0.5 bg-amber-500/20 text-amber-400 border border-amber-500/30 rounded-full">
                      SVIP Level {selectedUser.svipLevel || 0}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4 border-t border-white/5 pt-4 text-xs">
                  <div>
                    <span className="text-slate-500 font-bold block">Current Points</span>
                    <span className="text-base font-black text-amber-400">{selectedUser.svipPoints || 0} PTS</span>
                  </div>
                  <div>
                    <span className="text-slate-500 font-bold block">Cycle End Date</span>
                    <span className="text-base font-black text-slate-200">
                      {selectedUser.svipCycleEndDate?.toDate ? selectedUser.svipCycleEndDate.toDate().toLocaleDateString() : "No Active Cycle"}
                    </span>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Point & Tier Actions */}
          <div className="card-glass p-10 bg-[#18181B]/80 border-white/10 shadow-2xl space-y-8">
            <h3 className="text-xl font-black text-white uppercase tracking-tight flex items-center gap-3 border-b border-white/5 pb-4">
              <Sliders className="text-emerald-400" size={20} /> Override & Adjustment Controls
            </h3>

            {selectedUser ? (
              <div className="space-y-8">
                {/* Points Adjustment */}
                <div className="space-y-4">
                  <h4 className="text-xs font-black uppercase text-amber-400 tracking-wider">1. SVIP Points Adjustment</h4>
                  <div className="flex gap-4">
                    <input
                      type="number"
                      placeholder="Enter Points Amount..."
                      className="input-field flex-1 h-12 bg-slate-950/50 text-white font-mono px-4 rounded-xl"
                      value={pointAdjustment}
                      onChange={e => setPointAdjustment(e.target.value)}
                    />
                    <button
                      onClick={() => handleAdjustPoints("add")}
                      disabled={processing}
                      className="px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-black font-black uppercase text-xs rounded-xl"
                    >
                      + Add
                    </button>
                    <button
                      onClick={() => handleAdjustPoints("deduct")}
                      disabled={processing}
                      className="px-4 py-2 bg-amber-500 hover:bg-amber-600 text-black font-black uppercase text-xs rounded-xl"
                    >
                      - Deduct
                    </button>
                    <button
                      onClick={() => handleAdjustPoints("reset")}
                      disabled={processing}
                      className="px-4 py-2 bg-red-500/20 hover:bg-red-500 text-red-400 hover:text-white font-black uppercase text-xs rounded-xl border border-red-500/30"
                    >
                      Reset to 0
                    </button>
                  </div>
                </div>

                {/* Level Override */}
                <div className="space-y-4 border-t border-white/5 pt-6">
                  <h4 className="text-xs font-black uppercase text-rose-400 tracking-wider">2. Level Override (Resets Points to 0)</h4>
                  <div className="flex gap-4">
                    <select
                      className="input-field flex-1 h-12 bg-slate-950/50 text-white font-black px-4 rounded-xl"
                      value={selectedOverrideLevel}
                      onChange={e => setSelectedOverrideLevel(parseInt(e.target.value))}
                    >
                      {[1, 2, 3, 4, 5, 6].map(lvl => (
                        <option key={lvl} value={lvl} className="bg-slate-900">Set to SVIP {lvl}</option>
                      ))}
                    </select>
                    <button
                      onClick={handleOverrideLevel}
                      disabled={processing}
                      className="px-6 py-2 bg-rose-500 hover:bg-rose-600 text-white font-black uppercase text-xs tracking-wider rounded-xl shadow-lg"
                    >
                      EXECUTE OVERRIDE
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="p-16 text-center text-slate-500 font-bold uppercase text-xs tracking-widest">
                Search and select a user to enable management controls.
              </div>
            )}
          </div>
        </div>
      )}

      {/* Tab 3: Audit & Reset Logs */}
      {activeTab === "audit_logs" && (
        <div className="card-glass p-8 bg-[#18181B]/80 border-white/10 rounded-2xl space-y-6 animate-fade-in">
          <h3 className="text-xl font-black text-white uppercase tracking-tight flex items-center gap-3">
            <FileText className="text-amber-400" size={20} /> SVIP System Audit Trail
          </h3>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-white/5 uppercase text-[10px] font-black text-slate-500 tracking-widest">
                <tr>
                  <th className="p-4">Timestamp</th>
                  <th className="p-4">User UID / Hello ID</th>
                  <th className="p-4">Action Type</th>
                  <th className="p-4">Previous Level</th>
                  <th className="p-4">New Level</th>
                  <th className="p-4">Points State</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {auditLogs.map(log => (
                  <tr key={log.id} className="hover:bg-white/[0.02]">
                    <td className="p-4 font-mono text-slate-400">
                      {log.timestamp?.toDate ? log.timestamp.toDate().toLocaleString() : "N/A"}
                    </td>
                    <td className="p-4 font-mono font-bold text-white">{log.helloId || log.uid}</td>
                    <td className="p-4">
                      <span className="px-2.5 py-1 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded font-black uppercase tracking-wider text-[10px]">
                        {log.type}
                      </span>
                    </td>
                    <td className="p-4 font-bold text-slate-400">{log.previousLevel ?? "N/A"}</td>
                    <td className="p-4 font-bold text-emerald-400">{log.newLevel ?? "N/A"}</td>
                    <td className="p-4 font-mono text-slate-300">
                      {log.pointsAfterReset === 0 ? "Reset to 0" : (log.pointsAfter ? `${log.pointsAfter} PTS` : "0 PTS")}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tab 4: Banner Approvals */}
      {activeTab === "banners" && (
        <div className="card-glass p-8 bg-[#18181B]/80 border-white/10 rounded-2xl space-y-6 animate-fade-in">
          <h3 className="text-xl font-black text-white uppercase tracking-tight flex items-center gap-3">
            <Star className="text-amber-400" size={20} /> User Promotional Banner Review Queue
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {banners.map(b => (
              <div key={b.id} className="bg-white/5 p-6 rounded-2xl border border-white/10 space-y-4">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-black text-amber-400 uppercase">SVIP Level {b.svipLevel} Banner</span>
                  <span className={`text-[10px] font-black uppercase px-2.5 py-0.5 rounded ${b.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : (b.status === 'approved' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400')}`}>
                    {b.status}
                  </span>
                </div>

                <img src={b.bannerUrl} alt="banner" className="w-full h-36 object-cover rounded-xl border border-white/10" />
                <p className="text-xs text-slate-300 font-medium">{b.bannerText || "No text provided"}</p>

                {b.status === "pending" && (
                  <div className="flex gap-4 pt-2">
                    <button
                      onClick={() => handleReviewBanner(b.id, true)}
                      className="flex-1 py-2 bg-emerald-500 hover:bg-emerald-600 text-black font-black uppercase text-xs rounded-xl"
                    >
                      Approve
                    </button>
                    <button
                      onClick={() => handleReviewBanner(b.id, false)}
                      className="flex-1 py-2 bg-red-500/20 hover:bg-red-500 text-red-400 hover:text-white font-black uppercase text-xs rounded-xl border border-red-500/30"
                    >
                      Reject
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

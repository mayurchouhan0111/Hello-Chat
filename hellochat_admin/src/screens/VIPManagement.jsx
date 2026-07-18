import { useState, useEffect } from 'react';
import { 
  collection, 
  query, 
  getDocs, 
  doc, 
  setDoc, 
  onSnapshot,
  orderBy,
  serverTimestamp
} from 'firebase/firestore';
import { 
  ref, 
  uploadBytesResumable, 
  getDownloadURL 
} from 'firebase/storage';
import { db, storage } from '../firebase';
import { 
  Crown, 
  Diamond, 
  Zap, 
  Star, 
  CheckCircle, 
  Percent, 
  Sparkles,
  Layout,
  Plus,
  Trash2,
  Save,
  MessageSquare,
  Upload,
  Loader2,
  Image as ImageIcon
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const VIPManagement = () => {
  const [tiers, setTiers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingTier, setEditingTier] = useState(null);
  const [creating, setCreating] = useState(false);
  const [category, setCategory] = useState("vip_tiers"); // "vip_tiers" or "noble_tiers"
  const [uploadingField, setUploadingField] = useState(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const { user } = useAdmin();
  const [searchHelloId, setSearchHelloId] = useState("");
  const [targetUser, setTargetUser] = useState(null);
  const [refundDetails, setRefundDetails] = useState(null);
  const [searching, setSearching] = useState(false);
  const [refundReason, setRefundReason] = useState("");
  const [executingRefund, setExecutingRefund] = useState(false);


  useEffect(() => {
    const q = query(collection(db, category), orderBy("sortOrder", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setTiers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, [category]);

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...editingTier,
        updatedAt: serverTimestamp()
      };
      
      const docId = creating ? (data.tierId || `${category}_${Date.now()}`) : editingTier.id;
      await setDoc(doc(db, category, docId), data, { merge: true });
      await logAdminAction(user, `${category.toUpperCase()}_${creating ? 'CREATE' : 'UPDATE'}`, docId, { name: data.name });
      
      setEditingTier(null);
      setCreating(false);
      alert(`${category.replace('_', ' ')} updated successfully.`);
    } catch (err) {
      alert("Error: " + err.message);
    }
  };


  const handleSearchUser = async (e) => {
    e.preventDefault();
    if (!searchHelloId) return;
    setSearching(true);
    try {
      const q = query(collection(db, "users"), where("helloId", "==", parseInt(searchHelloId)));
      const usersSnap = await getDocs(q);
      if (usersSnap.empty) {
        alert("No user found with that Hello ID.");
        setTargetUser(null);
        setRefundDetails(null);
        return;
      }
      const userData = usersSnap.docs[0].data();
      setTargetUser({ ...userData, id: usersSnap.docs[0].id });
      const now = new Date();
      const expiry = userData.vipExpiry?.toDate();
      if (!userData.vipTier || userData.vipTier === "none") {
        alert("This user does not currently have an active VIP subscription.");
        setRefundDetails(null);
        return;
      }
      if (!expiry || expiry < now) {
        alert("VIP has already expired. No refund applicable.");
        setRefundDetails(null);
        return;
      }
      const remainingDays = Math.ceil((expiry - now) / (1000 * 60 * 60 * 24));
      const tierSnap = await getDocs(query(collection(db, "vip_tiers"), where("__name__", "==", userData.vipTier)));
      let price = 0;
      if (!tierSnap.empty) {
        price = tierSnap.docs[0].data().monthlyPriceInDiamonds || 0;
      }
      const refundAmt = Math.round(price * 0.2 * (remainingDays / 30));
      setRefundDetails({ expiryString: expiry.toDateString(), remainingDays, price, refundAmt });
    } catch (err) {
      alert("Lookup Error: " + err.message);
    } finally {
      setSearching(false);
    }
  };


  const handleExecuteRefund = async (e) => {
    e.preventDefault();
    if (!targetUser || !refundDetails) return;
    if (!window.confirm("EXECUTE VIP REVOCATION AND REFUND for " + targetUser.displayName + "? This action CANNOT be undone.")) return;
    setExecutingRefund(true);
    try {
      const refundFn = httpsCallable(functions, "refundVip");
      const res = await refundFn({ helloId: searchHelloId, reason: refundReason });
      alert("VIP revoked. Refunded " + res.data.refundedDiamonds + " diamonds.");
      setTargetUser(null);
      setRefundDetails(null);
      setSearchHelloId("");
      setRefundReason("");
    } catch (err) {
      alert("Refund Error: " + (err.message || "Unknown"));
    } finally {
      setExecutingRefund(false);
    }
  };

  const handleDelete = async (tierId) => {
    if(!window.confirm("ARE YOU SURE? This will permanently delete this tier.")) return;
    try {
      await deleteDoc(doc(db, category, tierId));
      await logAdminAction(user, `${category.toUpperCase()}_DELETE`, tierId);
      if(editingTier?.id === tierId) setEditingTier(null);
      alert("Tier removed from ecosystem.");
    } catch (err) {
      alert("Delete Error: " + err.message);
    }
  };

  const startCreating = () => {
    setCreating(true);
    setEditingTier({
      tierId: '',
      name: '',
      level: tiers.length + 1,
      monthlyPriceInDiamonds: 0,
      monthlyPriceInUSD: 0,
      benefits: [],
      profileFrame: '',
      entryAnimation: '',
      badgeIcon: '',
      backgroundImage: '',
      themeColor: '#FFFFFF',
      entryRequirement: 'Monthly Fee',
      priorityMicAccess: false,
      sortOrder: tiers.length + 1,
      isActive: true,
      discount: 0
    });
  };

  const handleFileUpload = async (e, field) => {
    const file = e.target.files[0];
    if (!file) return;

    setUploadingField(field);
    setUploadProgress(0);

    const storageRef = ref(storage, `vip_assets/${category}/${editingTier.id}/${field}_${Date.now()}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        setUploadProgress(progress);
      },
      (error) => {
        alert("Upload failed: " + error.message);
        setUploadingField(null);
      },
      () => {
        getDownloadURL(uploadTask.snapshot.ref).then((downloadURL) => {
          setEditingTier(prev => ({ ...prev, [field]: downloadURL }));
          setUploadingField(null);
          // Optional: Show a brief success state
          const originalName = editingTier.name;
          setEditingTier(prev => ({ ...prev, _lastUploaded: field }));
          setTimeout(() => {
            setEditingTier(prev => {
              const { _lastUploaded, ...rest } = prev;
              return rest;
            });
          }, 3000);
        });
      }
    );
  };

  const handleSeedAll = async () => {
    if(!window.confirm("CRITICAL ACTION: This will overwrite ALL existing VIP and Noble tiers. Continue?")) return;
    setLoading(true);
    try {
      const vipTiers = [
        {
          tierId: 'vip1',
          name: 'VIP 1',
          level: 1,
          monthlyPriceInDiamonds: 1000000,
          monthlyPriceInUSD: 10.0,
          benefits: ["badge", "entry_effect"],
          profileFrame: "",
          entryAnimation: "vip_entry_1",
          badgeIcon: "https://picsum.photos/101",
          backgroundImage: '',
          themeColor: '#10B981',
          entryRequirement: 'Recharge 1,000,000 Diamonds',
          priorityMicAccess: false,
          isActive: true,
          sortOrder: 1
        },
        {
          tierId: 'vip2',
          name: 'VIP 2',
          level: 2,
          monthlyPriceInDiamonds: 5000000,
          monthlyPriceInUSD: 50.0,
          benefits: ["badge", "entry_effect", "mic_ring"],
          profileFrame: "",
          entryAnimation: "vip_entry_2",
          badgeIcon: "https://picsum.photos/102",
          backgroundImage: '',
          themeColor: '#059669',
          entryRequirement: 'Recharge 5,000,000 Diamonds',
          priorityMicAccess: false,
          isActive: true,
          sortOrder: 2
        },
        {
          tierId: 'vip3',
          name: 'VIP 3',
          level: 3,
          monthlyPriceInDiamonds: 20000000,
          monthlyPriceInUSD: 200.0,
          benefits: ["badge", "entry_effect", "mic_ring", "priority_mic"],
          profileFrame: "",
          entryAnimation: "vip_entry_3",
          badgeIcon: "https://picsum.photos/103",
          backgroundImage: '',
          themeColor: '#3B82F6',
          entryRequirement: 'Recharge 20,000,000 Diamonds',
          priorityMicAccess: true,
          isActive: true,
          sortOrder: 3
        },
        {
          tierId: 'vip4',
          name: 'VIP 4',
          level: 4,
          monthlyPriceInDiamonds: 50000000,
          monthlyPriceInUSD: 500.0,
          benefits: ["badge", "entry_effect", "exclusive_gifts", "priority_mic"],
          profileFrame: "",
          entryAnimation: "vip_entry_4",
          badgeIcon: "https://picsum.photos/104",
          backgroundImage: '',
          themeColor: '#8B5CF6',
          entryRequirement: 'Recharge 50,000,000 Diamonds',
          priorityMicAccess: true,
          isActive: true,
          sortOrder: 4
        },
        {
          tierId: 'vip5',
          name: 'VIP 5',
          level: 5,
          monthlyPriceInDiamonds: 100000000,
          monthlyPriceInUSD: 1000.0,
          benefits: ["royal_frame", "badge", "custom_id", "kick_protection"],
          profileFrame: "https://picsum.photos/204",
          entryAnimation: "vip_entry_5",
          badgeIcon: "https://picsum.photos/105",
          backgroundImage: '',
          themeColor: '#F59E0B',
          entryRequirement: 'Recharge 100,000,000 Diamonds',
          priorityMicAccess: true,
          isActive: true,
          sortOrder: 5
        },
        {
          tierId: 'vip6',
          name: 'VIP 6',
          level: 6,
          monthlyPriceInDiamonds: 150000000,
          monthlyPriceInUSD: 1500.0,
          benefits: ["royal_frame", "badge", "custom_id", "kick_protection", "god_badge"],
          profileFrame: "https://picsum.photos/205",
          entryAnimation: "vip_entry_6",
          badgeIcon: "https://picsum.photos/106",
          backgroundImage: '',
          themeColor: '#EF4444',
          entryRequirement: 'Recharge 150,000,000 Diamonds',
          priorityMicAccess: true,
          isActive: true,
          sortOrder: 6
        },
        {
          tierId: 'vip7',
          name: 'VIP 7',
          level: 7,
          monthlyPriceInDiamonds: 200000000,
          monthlyPriceInUSD: 2000.0,
          benefits: ["all_access", "master_badge", "world_announce"],
          profileFrame: "https://picsum.photos/206",
          entryAnimation: "svip_entry",
          badgeIcon: "https://picsum.photos/107",
          backgroundImage: '',
          themeColor: '#FFFFFF',
          entryRequirement: 'Recharge 200,000,000 Diamonds',
          priorityMicAccess: true,
          isActive: true,
          sortOrder: 7
        },
      ];

      const nobleTiers = [
        {
          tierId: 'knight',
          name: 'Knight',
          level: 1,
          monthlyPriceInDiamonds: 200000,
          monthlyPriceInUSD: 200.0,
          benefits: ["noble_badge", "priority_mic"],
          badgeIcon: "https://picsum.photos/110",
          profileFrame: "",
          entryAnimation: 'noble_1',
          backgroundImage: '',
          themeColor: '#34D399',
          entryRequirement: 'Monthly Fee',
          priorityMicAccess: true,
          sortOrder: 1
        },
        {
          tierId: 'viscount',
          name: 'Viscount',
          level: 2,
          monthlyPriceInDiamonds: 1000000,
          monthlyPriceInUSD: 1000.0,
          benefits: ["noble_badge", "entry_effect", "priority_mic"],
          badgeIcon: "https://picsum.photos/111",
          profileFrame: "",
          entryAnimation: 'noble_2',
          backgroundImage: '',
          themeColor: '#10B981',
          entryRequirement: 'Monthly Fee',
          priorityMicAccess: true,
          sortOrder: 2
        },
        {
          tierId: 'marquis',
          name: 'Marquis',
          level: 4,
          monthlyPriceInDiamonds: 5000000,
          monthlyPriceInUSD: 5000.0,
          benefits: ["noble_frame", "kick_protection", "priority_mic"],
          badgeIcon: "https://picsum.photos/113",
          profileFrame: "",
          entryAnimation: 'noble_4',
          backgroundImage: '',
          themeColor: '#3B82F6',
          entryRequirement: 'Monthly Fee',
          priorityMicAccess: true,
          sortOrder: 3
        },
        {
          tierId: 'king',
          name: 'King',
          level: 6,
          monthlyPriceInDiamonds: 50000000,
          monthlyPriceInUSD: 50000.0,
          benefits: ["golden_entry", "kick_protection", "mute_immunity"],
          badgeIcon: "https://picsum.photos/115",
          profileFrame: "",
          entryAnimation: 'noble_6',
          backgroundImage: '',
          themeColor: '#F59E0B',
          entryRequirement: 'Monthly Fee',
          priorityMicAccess: true,
          sortOrder: 4
        },
        {
          tierId: 'emperor',
          name: 'Emperor',
          level: 7,
          monthlyPriceInDiamonds: 200000000,
          monthlyPriceInUSD: 200000.0,
          benefits: ["dragon_entry", "god_badge", "kick_protection", "mute_immunity"],
          badgeIcon: "https://picsum.photos/116",
          profileFrame: "",
          entryAnimation: 'noble_7',
          backgroundImage: '',
          themeColor: '#FFFFFF',
          entryRequirement: 'Monthly Fee',
          priorityMicAccess: true,
          sortOrder: 5
        },

      ];


      const svipLevels = [
        { level: 1, name: "SVIP 1", rechargeThreshold: 10000000, color: "#FDE047" },
        { level: 2, name: "SVIP 2", rechargeThreshold: 30000000, color: "#FACC15" },
        { level: 3, name: "SVIP 3", rechargeThreshold: 50000000, color: "#EAB308" },
        { level: 4, name: "SVIP 4", rechargeThreshold: 100000000, color: "#CA8A04" },
        { level: 5, name: "SVIP 5", rechargeThreshold: 200000000, color: "#A16207" },
        { level: 6, name: "SVIP 6", rechargeThreshold: 300000000, color: "#854D0E" },
        { level: 7, name: "SVIP 7", rechargeThreshold: 500000000, color: "#713F12" },
      ];

      const batch = [];
      vipTiers.forEach(v => batch.push(setDoc(doc(db, "vip_tiers", v.tierId), { ...v, isActive: true, createdAt: serverTimestamp() })));
      nobleTiers.forEach(n => batch.push(setDoc(doc(db, "noble_tiers", n.tierId), { ...n, isActive: true, createdAt: serverTimestamp() })));
      svipLevels.forEach(s => batch.push(setDoc(doc(db, "svip_levels", `svip${s.level}`), { ...s, isActive: true, createdAt: serverTimestamp() })));
      
      await Promise.all(batch);
      await logAdminAction(user, "FULL_ECONOMY_RESEED", "system", { status: "success" });
      alert("Economy Seeding Successful! All Tiers (VIP, Noble, SVIP) Initialized.");

    } catch (err) {
      alert("Seed Error: " + err.message);
    } finally {
      setLoading(false);
    }
  };


  const createTier = () => {
    const newId = `vip_${tiers.length + 1}`;
    setEditingTier({
      id: newId,
      tierId: newId,
      name: 'New VIP Tier',
      level: tiers.length + 1,
      monthlyPriceInDiamonds: 0,
      monthlyPriceInUSD: 0,
      benefits: [],
      profileFrame: '',
      entryAnimation: '',
      badgeIcon: '',
      priorityMicAccess: false,
      isActive: true,
      sortOrder: tiers.length + 1
    });
    setCreating(true);
  };

  const updateBenefit = (benefit, checked) => {
    const currentBenefits = editingTier.benefits || [];
    if(checked) {
       setEditingTier({...editingTier, benefits: [...currentBenefits, benefit]});
    } else {
       setEditingTier({...editingTier, benefits: currentBenefits.filter(b => b !== benefit)});
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-[#B4E0A2]/20 rounded-2xl border border-[#B4E0A2]/30">
                 <Crown className="text-[#B4E0A2]" size={28} />
              </div>
              Prestige Store
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">VIP Membership & Economy Orchestration • {tiers.length} Tiers</p>
        </div>
        <div className="flex items-center gap-3">
          <button 
            onClick={handleSeedAll}
            className="px-6 py-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white border border-red-500/20 rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all"
          >
            Reset & Seed All
          </button>
          <button 
            onClick={createTier}
            className="px-6 py-3 bg-white/5 hover:bg-[#B4E0A2] hover:text-black text-[#B4E0A2] border border-white/5 rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all"
          >
            <Plus size={14} className="inline mr-2" /> New Tier
          </button>
        </div>
      </div>

      <div className="flex gap-4 border-b border-white/5 pb-6">
        <button 
          onClick={() => setCategory("vip_tiers")}
          className={`px-8 py-3 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all ${category === 'vip_tiers' ? 'bg-[#B4E0A2] text-black' : 'bg-white/5 text-slate-500'}`}
        >
          VIP Memberships
        </button>
        <button 
          onClick={() => setCategory("noble_tiers")}
          className={`px-8 py-3 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all ${category === 'noble_tiers' ? 'bg-[#B4E0A2] text-black' : 'bg-white/5 text-slate-500'}`}
        >
          Noble Hall
        </button>
        <button 
          onClick={() => setCategory("svip_levels")} // Current SVIP collection
          className={`px-8 py-3 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all ${category === 'svip_levels' ? 'bg-rose-500 text-white outline outline-1 outline-rose-400' : 'bg-white/5 text-slate-500'}`}
        >
          SVIP (High-Stake)
        </button>
        <button 
           onClick={startCreating}
           className="ml-auto flex items-center gap-2 px-6 py-3 bg-emerald-500 text-slate-950 rounded-xl font-black uppercase text-[10px] tracking-widest hover:bg-emerald-400 transition-all shadow-lg shadow-emerald-500/20"
        >
          <Plus size={16} /> Add New {category === 'vip_tiers' ? 'VIP' : (category === 'noble_tiers' ? 'Noble' : 'SVIP')}
        </button>
      </div>


      
      {category === 'vip_refunds' ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 animate-fade-in">
          <div className="card-glass p-10 bg-[#18181B]/80 border-amber-500/30 shadow-2xl">
            <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4 border-b border-white/5 pb-6">
              <Crown className="text-amber-500 animate-pulse" size={24} /> User Lookup
            </h3>
            <form onSubmit={handleSearchUser} className="space-y-6 pt-6">
              <div className="space-y-3">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Search by Hello ID</label>
                <div className="flex gap-4">
                  <input 
                    required type="number"
                    placeholder="Enter User Hello ID..."
                    className="input-field flex-1 h-14 bg-slate-950/50 text-white font-mono pl-4"
                    value={searchHelloId}
                    onChange={(e) => setSearchHelloId(e.target.value)}
                  />
                  <button 
                    type="submit"
                    disabled={searching}
                    className="px-6 bg-amber-500 hover:bg-amber-600 text-black font-black uppercase text-xs tracking-wider rounded-2xl transition-all disabled:opacity-50"
                  >
                    {searching ? "Scanning..." : "Scan"}
                  </button>
                </div>
              </div>
            </form>
            {targetUser && refundDetails && (
              <div className="mt-8 space-y-6 border-t border-white/5 pt-6 animate-fade-in">
                <div className="flex items-center gap-4 bg-white/5 p-4 rounded-2xl border border-white/5">
                  <img src={targetUser.profilePhotoUrl} alt="avatar" className="w-16 h-16 rounded-full object-cover border border-white/10" />
                  <div>
                    <h4 className="text-lg font-black text-white">{targetUser.displayName}</h4>
                    <p className="text-xs text-slate-500 font-mono">Hello ID: {targetUser.helloId}</p>
                  </div>
                </div>
                <div className="space-y-4 bg-white/[0.02] p-6 rounded-2xl border border-white/5">
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Current VIP Tier</span>
                    <span className="text-xs font-black text-amber-500 uppercase">{targetUser.vipTier}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Expiration Date</span>
                    <span className="text-xs font-black text-slate-300">{refundDetails.expiryString}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Remaining Days</span>
                    <span className="text-xs font-black text-slate-300">{refundDetails.remainingDays} Days</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Monthly Tier Price</span>
                    <span className="text-xs font-black text-emerald-400">{refundDetails.price.toLocaleString()} 💎</span>
                  </div>
                  <div className="border-t border-white/5 pt-4 flex justify-between">
                    <span className="text-sm font-black text-white">Estimated Refund</span>
                    <span className="text-sm font-black text-emerald-400">{refundDetails.refundAmt.toLocaleString()} 💎</span>
                  </div>
                </div>
              </div>
            )}
          </div>
          <div className="card-glass p-10 bg-[#18181B]/80 border-red-500/30 shadow-2xl">
            <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4 border-b border-white/5 pb-6">
              <Trash2 className="text-red-500 animate-pulse" size={24} /> Revocation Actions
            </h3>
            {targetUser ? (
              <form onSubmit={handleExecuteRefund} className="space-y-6 pt-6 animate-fade-in">
                <div className="space-y-3">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Reason for Revocation</label>
                  <textarea 
                    required
                    placeholder="Provide a reason for the VIP cancellation and refund..."
                    className="input-field w-full h-32 bg-slate-950/50 text-white p-4 resize-none"
                    value={refundReason}
                    onChange={(e) => setRefundReason(e.target.value)}
                  />
                </div>
                <div className="bg-red-500/10 border border-red-500/20 p-6 rounded-2xl space-y-2">
                  <h5 className="text-xs font-black text-red-400 uppercase tracking-wider">Warning: Permanent Action</h5>
                  <p className="text-[11px] text-red-500/80 leading-relaxed font-semibold">
                    Executing this action will immediately revoke the user's VIP status, restore their original cosmetic snapshot, delete pending retention bonuses, and refund {refundDetails?.refundAmt.toLocaleString()} diamonds.
                  </p>
                </div>
                <button 
                  type="submit"
                  disabled={executingRefund}
                  className="w-full py-5 bg-red-600 hover:bg-red-700 text-white font-black uppercase text-xs tracking-wider rounded-[32px] transition-all disabled:opacity-50"
                >
                  {executingRefund ? "Executing Revocation..." : "EXECUTE VIP REVOCATION & REFUND"}
                </button>
              </form>
            ) : (
              <div className="p-20 text-center flex flex-col items-center justify-center min-h-[350px]">
                <Crown className="text-slate-800 mb-2" size={48} />
                <p className="text-slate-700 font-bold uppercase tracking-widest text-xs">Lookup a user to display actions</p>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">

        
        {/* Tiers List */}
        <div className="space-y-8">
            <div className="flex items-center justify-between px-2">
               <h4 className="text-xs font-black uppercase tracking-widest text-slate-500">{category === 'vip_tiers' ? 'VIP' : 'Noble'} Configuration HUD</h4>
               <Sparkles className={category === 'vip_tiers' ? 'text-amber-500 animate-pulse' : 'text-purple-400 animate-pulse'} size={16} />
            </div>

           <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {loading ? (
                <div className="col-span-full py-20 text-center animate-pulse py-40 font-black text-slate-700 uppercase tracking-widest">Prestige Ledger Syncing...</div>
              ) : tiers.map((tier) => (
                <motion.div 
                  key={tier.id}
                  whileHover={{ scale: 1.02, y: -5 }}
                  onClick={() => setEditingTier(tier)}
                  className={`card-glass p-8 cursor-pointer transition-all border shadow-2xl relative overflow-hidden group ${editingTier?.id === tier.id ? 'border-[#B4E0A2]/50 bg-[#B4E0A2]/10' : 'bg-[#18181B]/60 border-white/5'}`}
                >
                   <div className="absolute top-0 right-0 p-10 bg-white/5 rounded-full blur-2xl group-hover:scale-125 transition-transform"></div>
                   <div className="flex items-center justify-between mb-8 relative">
                       <div className="w-12 h-12 bg-white/5 rounded-2xl border border-white/10 flex items-center justify-center shadow-lg group-hover:border-amber-400/30 transition-all">
                          <Crown className={tier.id?.includes('v') ? 'text-slate-400' : 'text-amber-400'} size={24} />
                       </div>
                       <div className="flex items-center gap-2">
                          <button 
                            onClick={(e) => { e.stopPropagation(); handleDelete(tier.id); }}
                            className="p-2 bg-red-500/10 text-red-500 rounded-lg opacity-0 group-hover:opacity-100 transition-all hover:bg-red-500 hover:text-white"
                          >
                             <Trash2 size={14} />
                          </button>
                          <div className="text-right">
                         <p className="text-xs font-black text-emerald-400 tracking-tighter uppercase flex items-center gap-2">
                            <Diamond size={12} /> {tier.monthlyPriceInDiamonds?.toLocaleString() || '---'}
                         </p>
                         <p className="text-[10px] font-bold text-slate-600 uppercase mt-1">MONTHLY BASE</p>
                      </div>
                   </div>
                   </div>
                   <h3 className="text-2xl font-black text-white relative">{tier.name || 'Undefined Tier'}</h3>
                   <div className="flex gap-2 mt-4 relative">
                      <span className="text-[9px] font-black px-2 py-0.5 bg-white/5 text-slate-500 border border-white/10 rounded uppercase tracking-widest">{tier.id}</span>
                      {tier.discount > 0 && <span className="text-[9px] font-black px-2 py-0.5 bg-emerald-500/10 text-emerald-400 border border-emerald-500/10 rounded uppercase tracking-widest">-{tier.discount || 0}% OFF</span>}
                   </div>
                </motion.div>
              ))}
           </div>
        </div>

        {/* Editor HUD */}
        <div className="space-y-6">
           <AnimatePresence mode="wait">
             {editingTier ? (
               <motion.div 
                 key="editor"
                 initial={{ opacity: 0, x: 20 }}
                 animate={{ opacity: 1, x: 0 }}
                 exit={{ opacity: 0, x: 20 }}
                 className="card-glass p-10 bg-[#18181B]/80 border-[#B4E0A2]/30 shadow-[#B4E0A2]/10 shadow-2xl"
               >
                  <div className="flex items-center justify-between mb-10 border-b border-white/5 pb-6">
                      <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4">
                        <Zap className={creating ? "text-emerald-400" : "text-amber-400"} size={24} /> 
                        {creating ? "New Prestige Tier" : `Modify ${editingTier.name}`}
                     </h3>
                     <button onClick={() => { setEditingTier(null); setCreating(false); }} className="px-3 py-1 bg-white/5 text-slate-500 rounded hover:text-white uppercase font-black text-[10px] transition-colors">Discard</button>
                  </div>

                   <form onSubmit={handleSave} className="space-y-8">
                     <div className="space-y-3">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Tier Identity (Unique ID)</label>
                        <input 
                          required 
                          disabled={!creating}
                          placeholder="e.g. vip8 or noble_king"
                          className="input-field w-full h-14 bg-slate-950/50 text-white disabled:opacity-50"
                          value={editingTier.tierId || editingTier.id || ''}
                          onChange={(e) => setEditingTier({...editingTier, tierId: e.target.value})}
                        />
                     </div>

                     <div className="space-y-3">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Display Name</label>
                        <input 
                          required 
                          className="input-field w-full h-14 bg-slate-950/50 text-white font-black text-xl"
                          value={editingTier.name || ''}
                          onChange={(e) => setEditingTier({...editingTier, name: e.target.value})}
                        />
                     </div>

                     <div className="grid grid-cols-2 gap-8">
                        <div className="space-y-3">
                           <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Price (Diamonds)</label>
                           <input 
                             required type="number" 
                             className="input-field w-full h-14 bg-slate-950/50 text-white"
                             value={editingTier.monthlyPriceInDiamonds || 0}
                             onChange={(e) => setEditingTier({...editingTier, monthlyPriceInDiamonds: parseInt(e.target.value)})}
                           />
                        </div>
                        <div className="space-y-3">
                           <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Price (USD $)</label>
                           <input 
                             required type="number" step="0.01"
                             className="input-field w-full h-14 bg-slate-950/50 text-white"
                             value={editingTier.monthlyPriceInUSD || 0}
                             onChange={(e) => setEditingTier({...editingTier, monthlyPriceInUSD: parseFloat(e.target.value)})}
                           />
                        </div>
                     </div>

                     <div className="space-y-3">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Active Promotion (%)</label>
                        <div className="relative">
                           <Percent className="absolute left-4 top-4 text-slate-800" size={18} />
                           <input 
                             type="number" max="100"
                             className="input-field w-full h-14 bg-slate-950/50 pl-12"
                             value={editingTier.discount || 0}
                             onChange={(e) => setEditingTier({...editingTier, discount: parseInt(e.target.value)})}
                           />
                        </div>
                     </div>

                     <div className="space-y-6">
                        <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1 text-amber-500">Visual Assets (Upload or URL)</p>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                           {[
                             { label: 'Profile Frame', field: 'profileFrame' },
                             { label: 'Entry Animation', field: 'entryAnimation' },
                             { label: 'Badge Icon', field: 'badgeIcon' },
                             { label: 'Background Image', field: 'backgroundImage' }
                           ].map((asset) => (
                             <div key={asset.field} className="space-y-3 bg-white/5 p-4 rounded-2xl border border-white/5">
                                <div className="flex items-center justify-between">
                                   <label className="text-[10px] font-black text-slate-400 uppercase">{asset.label}</label>
                                   {editingTier[asset.field] && (
                                     <a href={editingTier[asset.field]} target="_blank" rel="noreferrer" className="text-[9px] text-amber-500 font-bold hover:underline">View Asset</a>
                                   )}
                                </div>
                                
                                {/* Asset Preview */}
                                <div className="h-24 w-full bg-slate-950 rounded-xl border border-white/5 flex items-center justify-center overflow-hidden relative group">
                                   {editingTier[asset.field] ? (
                                      asset.field.toLowerCase().includes('animation') ? (
                                        <div className="text-[10px] text-slate-500 font-black uppercase text-center px-4">Animation Link Saved</div>
                                      ) : (
                                        <img 
                                          src={editingTier[asset.field]} 
                                          alt="preview" 
                                          className="h-full w-full object-contain p-2"
                                          onError={(e) => {
                                            e.target.src = "https://placehold.co/200x200/1e293b/475569?text=Broken+Link";
                                          }} 
                                        />
                                      )
                                   ) : (
                                      <ImageIcon className="text-slate-800" size={24} />
                                   )}
                                   
                                   {/* Success Checkmark overlay */}
                                   {editingTier._lastUploaded === asset.field && (
                                     <motion.div 
                                       initial={{ scale: 0, opacity: 0 }}
                                       animate={{ scale: 1, opacity: 1 }}
                                       className="absolute inset-0 bg-emerald-500/90 flex items-center justify-center backdrop-blur-sm z-10"
                                     >
                                        <CheckCircle className="text-white" size={32} />
                                     </motion.div>
                                   )}
                                   
                                   {uploadingField === asset.field && (
                                     <div className="absolute inset-0 bg-slate-900/80 flex flex-col items-center justify-center backdrop-blur-sm">
                                        <Loader2 className="text-amber-500 animate-spin mb-2" size={20} />
                                        <div className="text-[10px] font-black text-white">{Math.round(uploadProgress)}%</div>
                                     </div>
                                   )}

                                   <label className="absolute inset-0 bg-amber-500/80 opacity-0 group-hover:opacity-100 flex items-center justify-center cursor-pointer transition-all">
                                      <Upload className="text-slate-950" size={20} />
                                      <input 
                                        type="file" 
                                        className="hidden" 
                                        accept="image/*,.gif,.svga,.lottie"
                                        onChange={(e) => handleFileUpload(e, asset.field)}
                                      />
                                   </label>
                                </div>

                                <input 
                                  className="input-field w-full h-8 bg-black/20 text-[9px] text-slate-500 font-mono border-none"
                                  placeholder="Or paste URL here..."
                                  value={editingTier[asset.field] || ''}
                                  onChange={(e) => setEditingTier({...editingTier, [asset.field]: e.target.value})}
                                />
                             </div>
                           ))}
                           
                           <label className="flex items-center gap-4 p-5 bg-white/5 rounded-2xl border border-white/5 hover:bg-white/10 transition-colors cursor-pointer group col-span-full">
                                <input 
                                  type="checkbox" 
                                  className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-amber-500 focus:ring-amber-500 focus:ring-offset-0"
                                  checked={editingTier.priorityMicAccess}
                                  onChange={(e) => setEditingTier({...editingTier, priorityMicAccess: e.target.checked})}
                                />
                                <div className="flex flex-col">
                                   <span className="text-xs font-black text-slate-300 group-hover:text-white transition-colors uppercase tracking-tight">Priority Microphone Access</span>
                                   <span className="text-[9px] text-slate-600 font-bold uppercase mt-1">Users can jump to the front of mic queues</span>
                                </div>
                           </label>
                        </div>
                     </div>

                     <button 
                      type="submit"
                      className="w-full flex items-center justify-center gap-3 py-5 bg-[#B4E0A2] hover:bg-[#8DBB7E] text-black rounded-[32px] font-black uppercase text-xs tracking-[0.2em] shadow-2xl transition-all transform active:scale-[0.98] mt-6 shadow-[#B4E0A2]/20"
                     >
                        <Save size={18} /> SYNC PRESTIGE DATA
                     </button>
                  </form>
               </motion.div>
             ) : (
               <div className="p-20 text-center border-2 border-dashed border-white/5 rounded-[40px] flex flex-col items-center gap-4 bg-slate-900/20 h-full justify-center min-h-[500px]">
                  <Crown className="text-slate-800 mb-2" size={48} />
                  <p className="text-slate-700 font-bold uppercase tracking-widest text-xs">Select a Tier to Modify Economics</p>
               </div>
             )}
           </AnimatePresence>
        </div>

      </div>
      )}
    </div>
  );
};

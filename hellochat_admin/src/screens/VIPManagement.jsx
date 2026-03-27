import { useState, useEffect } from 'react';
import { db } from '../firebase';
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
  MessageSquare
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const VIPManagement = () => {
  const [tiers, setTiers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingTier, setEditingTier] = useState(null);
  const [creating, setCreating] = useState(false);
  const { user } = useAdmin();

  useEffect(() => {
    const q = query(collection(db, "vip_tiers"), orderBy("level", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setTiers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...editingTier,
        updatedAt: serverTimestamp()
      };
      await setDoc(doc(db, "vip_tiers", editingTier.id || editingTier.tierId), data, { merge: true });
      await logAdminAction(user, "VIP_TIER_UPDATE", editingTier.id || editingTier.tierId, { name: data.name, price: data.monthlyPriceInDiamonds });
      setEditingTier(null);
      setCreating(false);
    } catch (err) {
      alert("Error: " + err.message);
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
              <div className="p-3 bg-amber-500/20 rounded-2xl border border-amber-500/30">
                 <Crown className="text-amber-400" size={28} />
              </div>
              Prestige Store
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">VIP Membership & Economy Orchestration • {tiers.length} Tiers</p>
        </div>
        <button 
          onClick={createTier}
          className="px-6 py-3 bg-white/5 hover:bg-amber-500 hover:text-slate-950 text-amber-500 border border-white/5 rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all"
        >
          <Plus size={14} className="inline mr-2" /> New Tier
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
        
        {/* Tiers List */}
        <div className="space-y-8">
           <div className="flex items-center justify-between px-2">
              <h4 className="text-xs font-black uppercase tracking-widest text-slate-500">Tier Configuration HUD</h4>
              <Sparkles className="text-amber-500 animate-pulse" size={16} />
           </div>

           <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {loading ? (
                <div className="col-span-full py-20 text-center animate-pulse py-40 font-black text-slate-700 uppercase tracking-widest">Prestige Ledger Syncing...</div>
              ) : tiers.map((tier) => (
                <motion.div 
                  key={tier.id}
                  whileHover={{ scale: 1.02, y: -5 }}
                  onClick={() => setEditingTier(tier)}
                  className={`card-glass p-8 cursor-pointer transition-all border shadow-2xl relative overflow-hidden group ${editingTier?.id === tier.id ? 'border-amber-400/50 bg-amber-500/10' : 'bg-slate-900/60 border-white/5'}`}
                >
                   <div className="absolute top-0 right-0 p-10 bg-white/5 rounded-full blur-2xl group-hover:scale-125 transition-transform"></div>
                   <div className="flex items-center justify-between mb-8 relative">
                      <div className="w-12 h-12 bg-white/5 rounded-2xl border border-white/10 flex items-center justify-center shadow-lg group-hover:border-amber-400/30 transition-all">
                         <Crown className={tier.id.includes('v') ? 'text-slate-400' : 'text-amber-400'} size={24} />
                      </div>
                      <div className="text-right">
                         <p className="text-xs font-black text-emerald-400 tracking-tighter uppercase flex items-center gap-2">
                            <Diamond size={12} /> {tier.monthlyPriceInDiamonds?.toLocaleString() || '---'}
                         </p>
                         <p className="text-[10px] font-bold text-slate-600 uppercase mt-1">MONTHLY BASE</p>
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
                 className="card-glass p-10 bg-slate-900/80 border-amber-500/30 shadow-amber-500/10 shadow-2xl"
               >
                  <div className="flex items-center justify-between mb-10 border-b border-white/5 pb-6">
                     <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4">
                        <Zap className="text-amber-400" size={24} /> 
                        Modify {editingTier.name}
                     </h3>
                     <button onClick={() => setEditingTier(null)} className="px-3 py-1 bg-white/5 text-slate-500 rounded hover:text-white uppercase font-black text-[10px] transition-colors">Discard</button>
                  </div>

                  <form onSubmit={handleSave} className="space-y-8">
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
                        <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Membership Privileges</p>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                           {['Profile Frame', 'Entry Animation', 'Badge Icon'].map(assetField => (
                             <div key={assetField} className="space-y-2">
                                <label className="text-[9px] font-black text-slate-700 uppercase">{assetField} URL</label>
                                <input 
                                  className="input-field w-full h-10 bg-white/5 text-[10px] text-slate-300"
                                  value={editingTier[assetField.replace(' ', '').charAt(0).toLowerCase() + assetField.replace(' ', '').slice(1)] || ''}
                                  onChange={(e) => setEditingTier({...editingTier, [assetField.replace(' ', '').charAt(0).toLowerCase() + assetField.replace(' ', '').slice(1)]: e.target.value})}
                                />
                             </div>
                           ))}
                           <label className="flex items-center gap-4 p-4 bg-white/5 rounded-2xl border border-white/5 hover:bg-white/10 transition-colors cursor-pointer group col-span-full">
                                <input 
                                  type="checkbox" 
                                  className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-amber-500 focus:ring-amber-500 focus:ring-offset-0"
                                  checked={editingTier.priorityMicAccess}
                                  onChange={(e) => setEditingTier({...editingTier, priorityMicAccess: e.target.checked})}
                                />
                                <span className="text-xs font-bold text-slate-400 group-hover:text-white transition-colors uppercase tracking-tight">Priority Microphone Access</span>
                           </label>
                        </div>
                     </div>

                     <button 
                      type="submit"
                      className="w-full flex items-center justify-center gap-3 py-5 bg-amber-500 hover:bg-amber-600 text-slate-950 rounded-2xl font-black uppercase text-xs tracking-[0.2em] shadow-2xl transition-all transform active:scale-[0.98] mt-6 shadow-amber-500/20"
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
    </div>
  );
};

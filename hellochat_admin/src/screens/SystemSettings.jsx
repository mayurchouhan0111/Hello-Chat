import { useState, useEffect } from 'react';
import { 
  collection, 
  query, 
  getDocs, 
  doc, 
  getDoc, 
  setDoc, 
  deleteDoc,
  onSnapshot,
  addDoc,
  serverTimestamp
} from 'firebase/firestore';
import { 
  Settings, 
  Save, 
  Zap, 
  Gamepad2, 
  Coins, 
  Image as ImageIcon, 
  Link as LinkIcon, 
  Plus, 
  Trash2,
  RefreshCcw,
  CheckCircle,
  Layout,
  Layers,
  FileText,
  Radio,
  BarChart3,
  Megaphone,
  Send
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';
import { db } from '../firebase';

export const SystemSettings = () => {
  const [config, setConfig] = useState({
    gameOdds: { spinWheel: 0.1, luckyDraw: 0.2 },
    currency: { diamondToBean: 0.8, beanToDollar: 0.01 },
    salary: { threshold: 50000, multiplier: 0.1 },
    leveling: { userXpRate: 1.0, wealthXpRate: 1.0 }
  });
  const [banners, setBanners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState(null);
  
  // Broadcast State
  const [broadcastMsg, setBroadcastMsg] = useState('');
  const [broadcastTitle, setBroadcastTitle] = useState('Hello Chat Alert');
  const [broadcastImage, setBroadcastImage] = useState('');
  const [isPush, setIsPush] = useState(false);
  const [broadcasting, setBroadcasting] = useState(false);
  const { user } = useAdmin();

  useEffect(() => {
    fetchConfig();
    const unsubBanners = onSnapshot(collection(db, "app_banners"), (snap) => {
      setBanners(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsubBanners();
  }, []);

  const fetchConfig = async () => {
    setLoading(true);
    try {
      const docSnap = await getDoc(doc(db, "app_config", "global"));
      if (docSnap.exists()) {
        setConfig(docSnap.data());
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdate = async (e) => {
    e.preventDefault();
    setLoading(true);
    setStatus('SAVING...');
    try {
      await setDoc(doc(db, "app_config", "global"), config, { merge: true });
      await logAdminAction(user, "CONFIG_UPDATE", "GLOBAL_ECOSYSTEM", config);
      setStatus('CONFIG SYNCHRONIZED ✨');
      setTimeout(() => setStatus(null), 3000);
    } catch (err) {
      alert("Error: " + err.message);
      setStatus('ERROR');
    } finally {
      setLoading(false);
    }
  };

  const sendBroadcast = async () => {
    if (!broadcastMsg) return;
    setBroadcasting(true);
    try {
      await addDoc(collection(db, "global_announcements"), {
        title: broadcastTitle,
        message: broadcastMsg,
        imageUrl: broadcastImage,
        isPush: isPush,
        timestamp: serverTimestamp(),
        type: 'system_broadcast'
      });
      await logAdminAction(user, "GLOBAL_BROADCAST", "SYSTEM", { message: broadcastMsg, isPush: isPush });
      setBroadcastMsg('');
      setBroadcastImage('');
      alert(isPush ? "FCM Push (Rich) & Ticker Transmitted! 📡" : "Ticker Transmitted! 📢");
    } catch (err) {
      alert("Broadcast Error: " + err.message);
    } finally {
      setBroadcasting(false);
    }
  };

  const addBanner = async () => {
    const newId = doc(collection(db, "app_banners")).id;
    await setDoc(doc(db, "app_banners", newId), {
      bannerId: newId, imageUrl: '', title: 'New Event', isActive: true, priority: banners.length + 1, actionType: 'none'
    });
  };

  const removeBanner = async (id) => {
    if (!window.confirm("Delete this banner?")) return;
    await deleteDoc(doc(db, "app_banners", id));
  };

  const updateBanner = async (id, field, value) => {
    await setDoc(doc(db, "app_banners", id), { [field]: value }, { merge: true });
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-primary/20 rounded-2xl border border-primary/30">
                 <Settings className="text-primary-light" size={28} />
              </div>
              Platform Core
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Global Ecosystem Orchestration • Month 7 Governance</p>
        </div>

        <div className="flex items-center gap-4">
           {status && (
             <span className="text-[10px] font-black text-emerald-400 uppercase tracking-widest bg-emerald-500/10 px-4 py-2 rounded-xl border border-emerald-500/20">
               {status}
             </span>
           )}
           <button 
            onClick={handleUpdate}
            disabled={loading}
            className="flex items-center gap-3 px-8 py-4 bg-primary hover:bg-primary-dark text-white rounded-2xl text-xs font-black uppercase tracking-widest shadow-2xl transition-all"
           >
              {loading ? <RefreshCcw className="animate-spin" size={16} /> : <Save size={16} />}
              UPDATE GLOBAL STATE
           </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        
        {/* Left Column: Economy & Rules */}
        <div className="lg:col-span-2 space-y-10">
          
          {/* Economy Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
             <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6">
                <h4 className="text-xs font-black text-emerald-400 tracking-[0.2em] uppercase flex items-center gap-2">
                   <Coins size={14} /> Currency Scalers
                </h4>
                <div className="space-y-4">
                   <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-slate-500 uppercase">Diamond ⮕ Bean</span>
                      <input type="number" step="0.1" className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 w-20 text-right outline-none" value={config.currency?.diamondToBean} onChange={e => setConfig({...config, currency: {...config.currency, diamondToBean: parseFloat(e.target.value)}})} />
                   </div>
                   <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-slate-500 uppercase">Bean ⮕ USD ($)</span>
                      <input type="number" step="0.001" className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 w-20 text-right outline-none" value={config.currency?.beanToDollar} onChange={e => setConfig({...config, currency: {...config.currency, beanToDollar: parseFloat(e.target.value)}})} />
                   </div>
                </div>
             </div>

             <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6">
                <h4 className="text-xs font-black text-cyan-400 tracking-[0.2em] uppercase flex items-center gap-2">
                   <BarChart3 size={14} /> Leveling Growth
                </h4>
                <div className="space-y-4">
                   <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-slate-500 uppercase">User XP Multi</span>
                      <input type="number" step="0.1" className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 w-20 text-right outline-none" value={config.leveling?.userXpRate} onChange={e => setConfig({...config, leveling: {...config.leveling, userXpRate: parseFloat(e.target.value)}})} />
                   </div>
                   <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-slate-500 uppercase">Wealth XP Multi</span>
                      <input type="number" step="0.1" className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 w-20 text-right outline-none" value={config.leveling?.wealthXpRate} onChange={e => setConfig({...config, leveling: {...config.leveling, wealthXpRate: parseFloat(e.target.value)}})} />
                   </div>
                </div>
             </div>
          </div>

          {/* Salary Config */}
          <div className="card-glass bg-slate-900/40 p-10 border-white/5 space-y-8">
             <h4 className="text-xl font-black text-white tracking-tight flex items-center gap-4 border-b border-white/5 pb-6">
                <Radio className="text-orange-400" size={24} /> Salary Formulation
             </h4>
             <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
                <div className="space-y-4">
                   <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Base Payout Threshold (Beans)</label>
                   <input 
                    type="number" className="input-field w-full h-14 bg-slate-950/50"
                    value={config.salary?.threshold}
                    onChange={e => setConfig({...config, salary: {...config.salary, threshold: parseInt(e.target.value)}})}
                   />
                </div>
                <div className="space-y-4">
                   <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Global Agency Multiplier</label>
                   <input 
                    type="number" step="0.01" className="input-field w-full h-14 bg-slate-950/50"
                    value={config.salary?.multiplier}
                    onChange={e => setConfig({...config, salary: {...config.salary, multiplier: parseFloat(e.target.value)}})}
                   />
                </div>
             </div>
          </div>

          {/* Broadcast Tool */}
          <div className="card-glass bg-slate-950/40 p-10 border-white/5 shadow-2xl relative overflow-hidden group">
             <div className="absolute top-0 right-0 p-10 bg-red-500/5 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
             <h4 className="text-xl font-black text-white tracking-tight flex items-center gap-4 border-b border-white/5 pb-6">
                <Megaphone className="text-red-500 animate-pulse" size={24} /> Global System Broadcast
             </h4>
             <div className="space-y-6 pt-4">
                <div className="flex flex-col md:flex-row gap-6">
                   <div className="flex-1 space-y-3">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Message Title</label>
                      <input 
                        placeholder="e.g. 🎁 Holiday Event"
                        className="input-field w-full h-14 bg-slate-950/50"
                        value={broadcastTitle}
                        onChange={e => setBroadcastTitle(e.target.value)}
                      />
                   </div>
                   <div className="flex-1 space-y-3">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Optional Image URL</label>
                      <input 
                        placeholder="e.g. https://domain.com/banner.jpg"
                        className="input-field w-full h-14 bg-slate-950/50"
                        value={broadcastImage}
                        onChange={e => setBroadcastImage(e.target.value)}
                      />
                   </div>
                   <div className="md:w-64 flex flex-col justify-end">
                      <label className="flex items-center gap-4 p-4 bg-white/5 rounded-2xl border border-white/5 hover:bg-white/10 transition-colors cursor-pointer h-14">
                         <input 
                           type="checkbox" 
                           className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-red-500 focus:ring-red-500 focus:ring-offset-0"
                           checked={isPush}
                           onChange={(e) => setIsPush(e.target.checked)}
                         />
                         <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Send as Lock-screen Push</span>
                      </label>
                   </div>
                </div>

                <textarea 
                  placeholder="Transmit message to ALL active rooms and home screen popup..."
                  className="input-field w-full h-32 bg-slate-950/50 py-4 resize-none"
                  value={broadcastMsg}
                  onChange={e => setBroadcastMsg(e.target.value)}
                />
                <button 
                  onClick={sendBroadcast}
                  disabled={broadcasting || !broadcastMsg}
                  className="w-full h-16 bg-red-500 hover:bg-red-600 disabled:opacity-50 text-white rounded-2xl font-black uppercase tracking-widest flex items-center justify-center gap-4 transition-all shadow-red-500/20 shadow-2xl"
                >
                   {broadcasting ? <RefreshCcw className="animate-spin" /> : <Send size={20} />}
                   EXECUTE GLOBAL ANNOUNCEMENT
                </button>
             </div>
          </div>

        </div>

        {/* Right Column: Banners & Games */}
        <div className="space-y-10">
           
           {/* Banner List */}
           <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6 max-h-[700px] overflow-y-auto custom-scrollbar">
              <div className="flex items-center justify-between border-b border-white/5 pb-4">
                 <h4 className="text-sm font-black text-white uppercase tracking-widest">App Banners</h4>
                 <button onClick={addBanner} className="p-2 bg-white/5 hover:bg-primary text-white rounded-lg transition-all"><Plus size={16} /></button>
              </div>
              {banners.map((banner, i) => (
                <div key={banner.id} className="p-4 bg-slate-950/50 rounded-2xl border border-white/5 space-y-4 group">
                   <div className="flex justify-between items-center">
                      <span className="text-[8px] font-black text-slate-700 uppercase">Slide #{i+1}</span>
                      <button onClick={() => removeBanner(banner.id)} className="text-slate-800 hover:text-red-500 transition-colors"><Trash2 size={12} /></button>
                   </div>
                   <input 
                    placeholder="IMAGE URL" className="bg-transparent border-b border-white/5 w-full text-[10px] py-1 text-slate-400 focus:text-white transition-colors outline-none" 
                    value={banner.imageUrl} onChange={e => updateBanner(banner.id, 'imageUrl', e.target.value)}
                   />
                   <input 
                    placeholder="ACTION ID" className="bg-transparent border-b border-white/5 w-full text-[10px] py-1 text-slate-400 focus:text-white transition-colors outline-none" 
                    value={banner.actionValue} onChange={e => updateBanner(banner.id, 'actionValue', e.target.value)}
                   />
                </div>
              ))}
           </div>

           {/* Game Config Card */}
           <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6">
              <h4 className="text-xs font-black text-cyan-400 tracking-[0.2em] uppercase flex items-center gap-2">
                 <Gamepad2 size={14} /> Jackpot Logic
              </h4>
              <div className="space-y-4">
                 <div className="flex items-center justify-between">
                    <span className="text-[10px] font-bold text-slate-500 uppercase">Spin Luck %</span>
                    <input type="number" step="0.01" className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 w-20 text-right outline-none" value={config.gameOdds?.spinWheel} onChange={e => setConfig({...config, gameOdds: {...config.gameOdds, spinWheel: parseFloat(e.target.value)}})} />
                 </div>
                 <div className="flex items-center justify-between">
                    <span className="text-[10px] font-bold text-slate-500 uppercase">Draw Luck %</span>
                    <input type="number" step="0.01" className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 w-20 text-right outline-none" value={config.gameOdds?.luckyDraw} onChange={e => setConfig({...config, gameOdds: {...config.gameOdds, luckyDraw: parseFloat(e.target.value)}})} />
                 </div>
              </div>
           </div>

        </div>

      </div>
    </div>
  );
};

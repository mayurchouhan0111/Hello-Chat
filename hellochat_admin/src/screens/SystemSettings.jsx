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
  serverTimestamp,
  Timestamp
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
  Send,
  Gift
} from 'lucide-react';

import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';
import { db, functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';

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

  // Broadcast Filters & Scheduling State
  const [vipsOnly, setVipsOnly] = useState(false);
  const [minLevel, setMinLevel] = useState(0);
  const [targetCountries, setTargetCountries] = useState('');
  const [targetFamilies, setTargetFamilies] = useState('');
  const [scheduledAt, setScheduledAt] = useState('');
  const [rewardAmount, setRewardAmount] = useState('');
  const { user } = useAdmin();

  const handleGlobalReward = async () => {
    if (!rewardAmount || isNaN(rewardAmount)) return;
    setLoading(true);
    setStatus('DISTRIBUTING...');
    try {
      const distribute = httpsCallable(functions, 'distributeGlobalReward');
      const result = await distribute({ amount: parseInt(rewardAmount), reason: "Event Reward" });
      
      await logAdminAction(user, "GLOBAL_REWARD", "ECONOMY", { amount: rewardAmount });
      
      setStatus('REWARDS TRANSMITTED! 🎁');
      setRewardAmount('');
      setTimeout(() => setStatus(null), 4000);
      alert(result.data.message);
    } catch (err) {
      alert("Reward Error: " + err.message);
      setStatus('DISTRIBUTION FAILED');
    } finally {
      setLoading(false);
    }
  };

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
      const scheduledTimestamp = scheduledAt ? Timestamp.fromDate(new Date(scheduledAt)) : null;

      await addDoc(collection(db, "global_announcements"), {
        title: broadcastTitle,
        message: broadcastMsg,
        imageUrl: broadcastImage,
        isPush: isPush,
        filters: {
          vipsOnly: vipsOnly,
          minLevel: parseInt(minLevel) || 0,
          countries: targetCountries ? targetCountries.split(',').map(s => s.trim().toUpperCase()).filter(s => !!s) : [],
          families: targetFamilies ? targetFamilies.split(',').map(s => s.trim()).filter(s => !!s) : [],
        },
        scheduledAt: scheduledTimestamp,
        createdAt: serverTimestamp(), // Match Flutter createdAt
        isActive: true, // Match Flutter isActive filter
        type: 'system', // Match Flutter type
        pushStatus: scheduledTimestamp ? 'scheduled' : 'pending',
      });

      await logAdminAction(user, "GLOBAL_BROADCAST", "SYSTEM", { 
        message: broadcastMsg, 
        isPush: isPush,
        scheduled: !!scheduledTimestamp
      });
      
      setBroadcastMsg('');
      setBroadcastImage('');
      setVipsOnly(false);
      setMinLevel(0);
      setTargetCountries('');
      setTargetFamilies('');
      setScheduledAt('');
      
      alert(scheduledTimestamp 
        ? "Broadcast successfully scheduled! ⏰" 
        : (isPush ? "FCM Push & Ticker Transmitted! 📡" : "Ticker Transmitted! 📢")
      );
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
                       <input type="number" step="0.1" className="glass-input-sm w-24 text-right" value={config.currency?.diamondToBean} onChange={e => setConfig({...config, currency: {...config.currency, diamondToBean: parseFloat(e.target.value)}})} />
                    </div>
                    <div className="flex items-center justify-between">
                       <span className="text-[10px] font-bold text-slate-500 uppercase">Bean ⮕ USD ($)</span>
                       <input type="number" step="0.001" className="glass-input-sm w-24 text-right" value={config.currency?.beanToDollar} onChange={e => setConfig({...config, currency: {...config.currency, beanToDollar: parseFloat(e.target.value)}})} />
                    </div>
                    <div className="flex items-center justify-between">
                       <span className="text-[10px] font-bold text-slate-500 uppercase">Min Withdrawal (Beans)</span>
                       <input type="number" step="100" className="glass-input-sm w-24 text-right" value={config.currency?.minWithdrawal || 1000} onChange={e => setConfig({...config, currency: {...config.currency, minWithdrawal: parseInt(e.target.value)}})} />
                    </div>
                 </div>
              </div>

              <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6">
                 <h4 className="text-xs font-black text-[#00E5FF] tracking-[0.2em] uppercase flex items-center gap-2">
                    <BarChart3 size={14} /> Leveling Growth
                 </h4>
                 <div className="space-y-4">
                    <div className="flex items-center justify-between">
                       <span className="text-[10px] font-bold text-slate-500 uppercase">User XP Multi</span>
                       <input type="number" step="0.1" className="glass-input-sm w-24 text-right" value={config.leveling?.userXpRate} onChange={e => setConfig({...config, leveling: {...config.leveling, userXpRate: parseFloat(e.target.value)}})} />
                    </div>
                    <div className="flex items-center justify-between">
                       <span className="text-[10px] font-bold text-slate-500 uppercase">Wealth XP Multi</span>
                       <input type="number" step="0.1" className="glass-input-sm w-24 text-right" value={config.leveling?.wealthXpRate} onChange={e => setConfig({...config, leveling: {...config.leveling, wealthXpRate: parseFloat(e.target.value)}})} />
                    </div>
                 </div>
              </div>
           </div>

          <div className="card-glass bg-slate-900/40 p-10 border-white/5 space-y-8">
             <h4 className="text-xl font-black text-white tracking-tight flex items-center gap-4 border-b border-white/5 pb-6">
                <Radio className="text-orange-400" size={24} /> Salary Formulation
             </h4>
             <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
                <div className="space-y-4">
                   <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Base Payout Threshold (Beans)</label>
                   <input 
                    type="number" className="glass-input w-full h-14"
                    value={config.salary?.threshold || 0}
                    onChange={e => setConfig({...config, salary: {...config.salary, threshold: parseInt(e.target.value)}})}
                   />
                </div>
                <div className="space-y-4">
                   <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Global Agency Multiplier</label>
                   <input 
                    type="number" step="0.01" className="glass-input w-full h-14"
                    value={config.salary?.multiplier || 0}
                    onChange={e => setConfig({...config, salary: {...config.salary, multiplier: parseFloat(e.target.value)}})}
                   />
                </div>
             </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
             <div className={`card-glass p-8 border-white/5 space-y-6 transition-all ${config.isMaintenance ? 'bg-orange-500/10 border-orange-500/30 ring-4 ring-orange-500/10' : 'bg-slate-900/40'}`}>
                <div className="flex items-center justify-between">
                   <h4 className="text-xs font-black text-orange-400 tracking-[0.2em] uppercase flex items-center gap-2">
                      <Zap size={14} /> Maintenance Protocol
                   </h4>
                   <div className={`w-3 h-3 rounded-full ${config.isMaintenance ? 'bg-orange-500 animate-pulse' : 'bg-slate-800'}`}></div>
                </div>
                <p className="text-[10px] font-bold text-slate-500 uppercase leading-relaxed">When active, the mobile app will be locked for all users except admins. Useful for database migrations or large deployments.</p>
                <div className="pt-2">
                   <button 
                    onClick={() => setConfig({...config, isMaintenance: !config.isMaintenance})}
                    className={`w-full py-4 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all ${config.isMaintenance ? 'bg-white text-orange-600' : 'bg-orange-500/10 text-orange-500 border border-orange-500/20'}`}
                   >
                     {config.isMaintenance ? 'Disable Maintenance Mode' : 'Go Offline for Maintenance'}
                   </button>
                </div>
             </div>

             <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6 overflow-hidden">
                <h4 className="text-xs font-black text-rose-400 tracking-[0.2em] uppercase flex items-center gap-2">
                   <Gift size={14} /> Global Rewards
                </h4>
                <p className="text-[10px] font-bold text-slate-500 uppercase leading-relaxed">Mass distribute diamonds to all registered users (100+). Use for compensation or events.</p>
                <div className="flex flex-col sm:flex-row gap-3">
                   <input 
                    type="number" className="glass-input flex-1 !h-12 !px-4 !py-0" placeholder="Amount..." 
                    value={rewardAmount}
                    onChange={(e) => setRewardAmount(e.target.value)}
                   />
                   <button 
                    onClick={handleGlobalReward}
                    disabled={loading || !rewardAmount}
                    className="h-12 px-8 bg-rose-600 hover:bg-rose-500 text-white rounded-2xl font-black text-[10px] uppercase transition-all disabled:opacity-50 shadow-xl shadow-rose-900/20 flex-shrink-0"
                   >
                      {loading ? 'Distributing...' : 'Distribute'}
                   </button>
                </div>
             </div>
          </div>

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
                        className="glass-input w-full h-14"
                        value={broadcastTitle}
                        onChange={e => setBroadcastTitle(e.target.value)}
                      />
                   </div>
                   <div className="flex-1 space-y-3">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Optional Image URL</label>
                      <input 
                        placeholder="e.g. https://domain.com/banner.jpg"
                        className="glass-input w-full h-14"
                        value={broadcastImage}
                        onChange={e => setBroadcastImage(e.target.value)}
                      />
                   </div>
                   <div className="md:w-64 flex flex-col justify-end">
                      <label className="flex items-center gap-4 p-4 bg-white/5 rounded-2xl border border-white/5 hover:bg-white/10 transition-colors cursor-pointer h-14">
                         <input 
                           type="checkbox" 
                           className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-[#00E5FF] focus:ring-[#00E5FF] focus:ring-offset-0"
                           checked={isPush}
                           onChange={(e) => setIsPush(e.target.checked)}
                         />
                         <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Send as Lock-screen Push</span>
                      </label>
                   </div>
                </div>

                 {/* Filters HUD */}
                 <div className="grid grid-cols-1 md:grid-cols-3 gap-6 bg-white/[0.02] p-6 rounded-2xl border border-white/5">
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Minimum User Level</label>
                       <input 
                         type="number"
                         min="0"
                         className="glass-input w-full h-14"
                         value={minLevel}
                         onChange={e => setMinLevel(e.target.value)}
                       />
                    </div>
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Target Countries (comma separated)</label>
                       <input 
                         placeholder="All Countries"
                         className="glass-input w-full h-14"
                         value={targetCountries}
                         onChange={e => setTargetCountries(e.target.value)}
                       />
                    </div>
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Target Family IDs (comma separated)</label>
                       <input 
                         placeholder="All Families"
                         className="glass-input w-full h-14"
                         value={targetFamilies}
                         onChange={e => setTargetFamilies(e.target.value)}
                       />
                    </div>
                    <div className="space-y-3 md:col-span-2">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Scheduled Delivery Time (Optional)</label>
                       <input 
                         type="datetime-local"
                         className="glass-input w-full h-14 text-white"
                         value={scheduledAt}
                         onChange={e => setScheduledAt(e.target.value)}
                       />
                    </div>
                    <div className="flex items-end pb-3">
                       <label className="flex items-center gap-4 cursor-pointer">
                          <input 
                            type="checkbox" 
                            className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-[#00E5FF] focus:ring-[#00E5FF] focus:ring-offset-0"
                            checked={vipsOnly}
                            onChange={(e) => setVipsOnly(e.target.checked)}
                          />
                          <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Target VIP Users Only</span>
                       </label>
                    </div>
                 </div>

                <textarea 
                  placeholder="Transmit message to ALL active rooms and home screen popup..."
                  className="glass-input w-full h-32 py-4 resize-none"
                  value={broadcastMsg}
                  onChange={e => setBroadcastMsg(e.target.value)}
                />
                 <button 
                  onClick={sendBroadcast}
                  disabled={broadcasting || !broadcastMsg}
                  className="w-full h-16 bg-[#00E5FF] hover:bg-cyan-400 disabled:opacity-50 text-black rounded-2xl font-black uppercase tracking-widest flex items-center justify-center gap-4 transition-all shadow-cyan-500/20 shadow-2xl"
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
            <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6 max-h-[800px] overflow-y-auto custom-scrollbar">
               <div className="flex items-center justify-between border-b border-white/5 pb-4">
                  <h4 className="text-sm font-black text-white uppercase tracking-widest flex items-center gap-2">
                     <ImageIcon size={18} className="text-[#00E5FF]" /> App Banners
                  </h4>
                  <button onClick={addBanner} className="p-2 bg-[#00E5FF]/10 hover:bg-[#00E5FF] text-[#00E5FF] hover:text-black rounded-lg transition-all border border-[#00E5FF]/20"><Plus size={16} /></button>
               </div>
               <div className="grid grid-cols-1 gap-4">
                  {banners.map((banner, i) => (
                    <div key={banner.id} className="p-6 bg-white/[0.02] rounded-2xl border border-white/5 space-y-4 group hover:bg-white/[0.04] transition-all">
                       <div className="flex justify-between items-center mb-2">
                          <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Banner Slide #{i+1}</span>
                          <button onClick={() => removeBanner(banner.id)} className="p-2 text-slate-600 hover:text-rose-500 transition-colors bg-white/5 rounded-lg"><Trash2 size={14} /></button>
                       </div>
                       <div className="space-y-3">
                          <div className="relative">
                             <ImageIcon className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-700" size={14} />
                             <input 
                               placeholder="IMAGE URL" className="glass-input-sm w-full pl-10" 
                               value={banner.imageUrl} onChange={e => updateBanner(banner.id, 'imageUrl', e.target.value)}
                             />
                          </div>
                           <div className="relative">
                              <LinkIcon className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-700" size={14} />
                              <input 
                                placeholder="ACTION TARGET (URL/ID)" className="glass-input-sm w-full pl-10" 
                                value={banner.actionValue} onChange={e => updateBanner(banner.id, 'actionValue', e.target.value)}
                              />
                           </div>
                           <div className="relative">
                              <select
                                className="glass-input-sm w-full pl-3 appearance-none cursor-pointer"
                                value={banner.actionType || 'none'}
                                onChange={e => updateBanner(banner.id, 'actionType', e.target.value)}
                                style={{background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '12px', padding: '10px 12px', color: '#fff', fontSize: '12px', fontWeight: 600}}
                              >
                                <option value="none">None (Decorative)</option>
                                <option value="recharge">Recharge → /wallet</option>
                                <option value="room">Join Room → actionValue = roomId</option>
                                <option value="room_support">Room Support → /room-support</option>
                                <option value="recharge_event">Recharge Event → /recharge-event-detail</option>
                                <option value="profile">View Profile → actionValue = uid</option>
                                <option value="external_url">External URL → actionValue = url</option>
                              </select>
                           </div>
                       </div>
                    </div>
                  ))}
               </div>
            </div>

            {/* Game Config Card */}
            <div className="card-glass bg-slate-900/40 p-8 border-white/5 space-y-6">
               <h4 className="text-xs font-black text-[#00E5FF] tracking-[0.2em] uppercase flex items-center gap-2">
                  <Gamepad2 size={14} /> Jackpot Logic
               </h4>
               <div className="space-y-4">
                  <div className="flex items-center justify-between">
                     <span className="text-[10px] font-bold text-slate-500 uppercase">Spin Luck %</span>
                     <input type="number" step="0.01" className="glass-input-sm w-24 text-right" value={config.gameOdds?.spinWheel} onChange={e => setConfig({...config, gameOdds: {...config.gameOdds, spinWheel: parseFloat(e.target.value)}})} />
                  </div>
                  <div className="flex items-center justify-between">
                     <span className="text-[10px] font-bold text-slate-500 uppercase">Draw Luck %</span>
                     <input type="number" step="0.01" className="glass-input-sm w-24 text-right" value={config.gameOdds?.luckyDraw} onChange={e => setConfig({...config, gameOdds: {...config.gameOdds, luckyDraw: parseFloat(e.target.value)}})} />
                  </div>
               </div>
            </div>

        </div>

      </div>
    </div>
  );
};

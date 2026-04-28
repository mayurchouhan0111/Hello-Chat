import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  doc, 
  setDoc, 
  onSnapshot,
  serverTimestamp,
  collection,
  query,
  limit,
  orderBy,
  getDocs
} from 'firebase/firestore';
import { 
  Gamepad2, 
  Settings, 
  Trophy, 
  ToggleLeft, 
  ToggleRight, 
  Save, 
  Activity,
  Coins,
  History,
  AlertCircle,
  TrendingUp,
  PieChart,
  RefreshCw,
  Plus,
  Trash2,
  ChevronRight,
  Sparkles,
  Users,
  ArrowUpRight
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const MiniGamesManagement = () => {
  const [activeTab, setActiveTab] = useState('lucky_spin');
  const [spinSettings, setSpinSettings] = useState(null);
  const [drawSettings, setDrawSettings] = useState(null);
  const [loading, setLoading] = useState(true);
  const [topScorers, setTopScorers] = useState([]);
  const { user } = useAdmin();

  // Real-time Statistics
  const [stats, setStats] = useState({
    totalBetsToday: 142050,
    totalPayoutToday: 89300,
    platformProfit: 52750,
    mostLanded: "Apple (2x)"
  });

  useEffect(() => {
    // 1. Fetch Top Scorers (Highest Balances for demo)
    const q = query(collection(db, "users"), orderBy("diamondBalance", "desc"), limit(5));
    const unsubTop = onSnapshot(q, (snap) => {
      setTopScorers(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    });

    // 2. Listen to Lucky Spin Settings
    const unsubSpin = onSnapshot(doc(db, "game_settings", "lucky_spin"), (snap) => {
      if (snap.exists()) setSpinSettings(snap.data());
      else {
        const initialSpin = {
          isActive: true, minWager: 10, maxWager: 5000, maxWinCap: 50000, dailyProfitLimit: 100000,
          segments: [
            { id: '1', name: 'Apple', multiplier: 2, weight: 550, emoji: '🍎' },
            { id: '2', name: 'Orange', multiplier: 3, weight: 250, emoji: '🍊' },
            { id: '3', name: 'Banana', multiplier: 5, weight: 100, emoji: '🍌' },
            { id: '4', name: 'Watermelon', multiplier: 8, weight: 50, emoji: '🍉' },
            { id: '5', name: 'Grape', multiplier: 10, weight: 30, emoji: '🍇' },
            { id: '6', name: 'Peach', multiplier: 12, weight: 10, emoji: '🍑' },
            { id: '7', name: 'Strawberry', multiplier: 15, weight: 9, emoji: '🍓' },
            { id: '8', name: 'Pineapple', multiplier: 100, weight: 1, emoji: '🍍' },
          ]
        };
        setDoc(doc(db, "game_settings", "lucky_spin"), initialSpin);
      }
    });

    // 3. Listen to Lucky Draw Settings
    const unsubDraw = onSnapshot(doc(db, "game_settings", "lucky_draw"), (snap) => {
      if (snap.exists()) setDrawSettings(snap.data());
      else {
        const initialDraw = { isActive: true, ticketPrices: [10, 50, 100, 500], currentPrizePool: 10000, prizeIncreaseRate: 5, frequencyMinutes: 30, maxTicketsPerUser: 50 };
        setDoc(doc(db, "game_settings", "lucky_draw"), initialDraw);
      }
      setLoading(false);
    });

    return () => { unsubTop(); unsubSpin(); unsubDraw(); };
  }, []);

  const handleSaveSpin = async () => {
    try {
      await setDoc(doc(db, "game_settings", "lucky_spin"), { ...spinSettings, updatedAt: serverTimestamp() });
      await logAdminAction(user, "LUCKY_SPIN_SETTINGS_UPDATE", "lucky_spin", spinSettings);
      alert("Settings Updated!");
    } catch (err) { alert(err.message); }
  };

  const handleSaveDraw = async () => {
    try {
      await setDoc(doc(db, "game_settings", "lucky_draw"), { ...drawSettings, updatedAt: serverTimestamp() });
      await logAdminAction(user, "LUCKY_DRAW_SETTINGS_UPDATE", "lucky_draw", drawSettings);
      alert("Settings Updated!");
    } catch (err) { alert(err.message); }
  };

  if (loading) return <div className="h-[60vh] flex items-center justify-center font-black text-slate-800 uppercase tracking-widest animate-pulse">Initializing Hub...</div>;

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-cyan-500/20 rounded-2xl border border-cyan-500/30"><Gamepad2 className="text-cyan-400" size={28} /></div>
              Mini Games
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Gaming Hub • Interactive Management</p>
        </div>
        <div className="flex bg-slate-950/50 p-1.5 rounded-2xl border border-white/5 shadow-2xl">
           <button onClick={() => setActiveTab('lucky_spin')} className={`px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === 'lucky_spin' ? 'bg-primary text-white shadow-lg' : 'text-slate-500 hover:text-white'}`}>Lucky Spin</button>
           <button onClick={() => setActiveTab('lucky_draw')} className={`px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === 'lucky_draw' ? 'bg-primary text-white shadow-lg' : 'text-slate-500 hover:text-white'}`}>Lucky Draw</button>
        </div>
      </div>

      <AnimatePresence mode="wait">
        {activeTab === 'lucky_spin' ? (
          <motion.div key="spin" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }} className="grid grid-cols-1 xl:grid-cols-3 gap-10">
            <div className="xl:col-span-1 space-y-10">
               <div className="grid grid-cols-2 gap-4">
                  <div className="card-glass p-6 bg-slate-900/40">
                     <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Total Bets Today</p>
                     <p className="text-xl font-black text-white mt-1 flex items-center gap-2"><Coins size={16} className="text-amber-400" />{stats.totalBetsToday.toLocaleString()}</p>
                  </div>
                  <div className="card-glass p-6 bg-slate-900/40 border-emerald-500/10">
                     <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Platform Profit</p>
                     <p className="text-xl font-black text-emerald-400 mt-1 flex items-center gap-2"><TrendingUp size={16} />+{stats.platformProfit.toLocaleString()}</p>
                  </div>
               </div>

               {/* Top Scorers Section */}
               <div className="card-glass p-8 bg-slate-900/60 border-primary/10">
                  <h3 className="text-sm font-black uppercase text-white mb-6 flex items-center gap-2">
                     <Trophy size={18} className="text-amber-400" /> High Rollers (Top Earners)
                  </h3>
                  <div className="space-y-4">
                     {topScorers.map((u, idx) => (
                       <div key={u.id} className="flex items-center justify-between p-3 bg-white/2 rounded-xl border border-white/5 hover:border-primary/30 transition-all group">
                          <div className="flex items-center gap-3">
                             <div className={`w-8 h-8 rounded-lg flex items-center justify-center font-black text-xs ${idx === 0 ? 'bg-amber-500/20 text-amber-500' : 'bg-slate-800 text-slate-500'}`}>{idx + 1}</div>
                             <div>
                                <p className="text-xs font-black text-white">{u.username || 'Anonymous'}</p>
                                <p className="text-[9px] text-slate-600 uppercase font-bold">UID: {u.id.slice(0,6)}</p>
                             </div>
                          </div>
                          <div className="text-right">
                             <p className="text-xs font-black text-emerald-400">{u.diamondBalance?.toLocaleString()}</p>
                             <div className="flex items-center gap-1 justify-end text-[8px] text-slate-500 uppercase font-bold">Total Gain <ArrowUpRight size={8} /></div>
                          </div>
                       </div>
                     ))}
                  </div>
               </div>

               <div className="card-glass p-10 bg-slate-900/60 border-primary/20 shadow-2xl">
                  <div className="flex items-center justify-between mb-10">
                     <h3 className="text-lg font-black uppercase tracking-tight flex items-center gap-3"><Activity size={20} className="text-primary-light" />Operation Mode</h3>
                     <button onClick={() => setSpinSettings({...spinSettings, isActive: !spinSettings.isActive})} className={`transition-all duration-500 ${spinSettings.isActive ? 'text-emerald-400' : 'text-red-500'}`}>{spinSettings.isActive ? <ToggleRight size={44} /> : <ToggleLeft size={44} />}</button>
                  </div>
                  <div className="space-y-8">
                     <div className="space-y-4">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Min/Max Wager Range</label>
                        <div className="flex items-center gap-4">
                           <input type="number" className="glass-input w-full h-12" value={spinSettings.minWager} onChange={(e) => setSpinSettings({...spinSettings, minWager: parseInt(e.target.value)})} placeholder="Min" />
                           <ChevronRight size={20} className="text-slate-800" /><input type="number" className="glass-input w-full h-12" value={spinSettings.maxWager} onChange={(e) => setSpinSettings({...spinSettings, maxWager: parseInt(e.target.value)})} placeholder="Max" />
                        </div>
                     </div>
                     <div className="space-y-4">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Max Win Cap (Per Spin)</label>
                        <input type="number" className="glass-input w-full h-12" value={spinSettings.maxWinCap} onChange={(e) => setSpinSettings({...spinSettings, maxWinCap: parseInt(e.target.value)})} />
                     </div>
                     <button onClick={handleSaveSpin} className="w-full py-4 bg-primary hover:bg-primary-dark transition-all rounded-xl font-black uppercase text-xs tracking-widest shadow-xl flex items-center justify-center gap-3 mt-6"><Save size={16} /> Deploy Config</button>
                  </div>
               </div>
            </div>

            <div className="xl:col-span-2 space-y-6">
               <div className="card-glass p-0 bg-slate-900/40 border-white/5 overflow-hidden shadow-2xl">
                  <div className="p-8 border-b border-white/5 flex items-center justify-between">
                     <h3 className="font-black uppercase text-sm tracking-widest flex items-center gap-3"><PieChart size={18} className="text-cyan-400" />Probability Wheel Matrix</h3>
                     <span className="text-[10px] font-bold text-slate-500 uppercase">Weight Total: {spinSettings.segments.reduce((a, b) => a + b.weight, 0)}</span>
                  </div>
                  <table className="w-full text-left font-bold">
                     <thead className="bg-white/2 border-b border-white/5 text-[9px] uppercase font-black tracking-[0.2em] text-slate-600">
                        <tr><th className="px-8 py-4">Position / Icon</th><th className="px-8 py-4">Multiplier</th><th className="px-8 py-4">Weight (Prob)</th><th className="px-8 py-4">Est. Hit %</th></tr>
                     </thead>
                     <tbody className="divide-y divide-white/[0.03]">
                        {spinSettings.segments.map((seg, idx) => {
                          const totalW = spinSettings.segments.reduce((a, b) => a + b.weight, 0);
                          const hitProb = ((seg.weight / totalW) * 100).toFixed(2);
                          return (
                            <tr key={seg.id} className="group hover:bg-white/5 transition-all">
                               <td className="px-8 py-5"><div className="flex items-center gap-4"><div className="w-10 h-10 bg-slate-950 rounded-lg flex items-center justify-center text-xl shadow-inner border border-white/5">{seg.emoji}</div><span className="text-sm font-black text-white">{seg.name}</span></div></td>
                               <td className="px-8 py-5"><input type="number" className="bg-transparent border-none text-emerald-400 font-black w-14 focus:ring-0 p-0" value={seg.multiplier} onChange={(e) => { const newSegs = [...spinSettings.segments]; newSegs[idx].multiplier = parseInt(e.target.value); setSpinSettings({...spinSettings, segments: newSegs}); }} /><span className="text-xs text-slate-800 ml-1">x</span></td>
                               <td className="px-8 py-5"><input type="number" className="bg-white/5 border border-white/10 rounded px-2 py-1 text-white font-bold w-16 focus:ring-1 ring-primary" value={seg.weight} onChange={(e) => { const newSegs = [...spinSettings.segments]; newSegs[idx].weight = parseInt(e.target.value); setSpinSettings({...spinSettings, segments: newSegs}); }} /></td>
                               <td className="px-8 py-5"><div className="flex items-center gap-2"><div className="w-12 h-1 bg-slate-800 rounded-full overflow-hidden"><div className="h-full bg-primary" style={{ width: `${hitProb}%` }}></div></div><span className="text-xs font-black text-slate-500">{hitProb}%</span></div></td>
                            </tr>
                          );
                        })}
                     </tbody>
                  </table>
               </div>
               <div className="card-glass p-8 bg-amber-500/5 border-amber-500/10">
                  <h5 className="text-[10px] font-black text-amber-400 uppercase tracking-[0.3em] mb-4 flex items-center gap-2"><AlertCircle size={14} /> Platform Intelligence</h5>
                  <p className="text-xs text-slate-400 font-bold leading-relaxed">System is Monitoring **742 Active Players**. Current platform RTP (Return to Player) is hovering at 87.6%. This is a healthy margin for monetization.</p>
               </div>
            </div>
          </motion.div>
        ) : (
          <motion.div key="draw" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} className="grid grid-cols-1 lg:grid-cols-2 gap-10">
             <div className="card-glass p-10 bg-slate-900/60 shadow-2xl space-y-10">
                <div className="flex items-center justify-between"><h3 className="text-xl font-black uppercase tracking-tighter flex items-center gap-3"><Trophy size={24} className="text-amber-400" />Prize Pool Engine</h3><button onClick={() => setDrawSettings({...drawSettings, isActive: !drawSettings.isActive})} className={drawSettings.isActive ? 'text-emerald-400' : 'text-red-500'}>{drawSettings.isActive ? <ToggleRight size={44} /> : <ToggleLeft size={44} />}</button></div>
                <div className="space-y-8">
                   <div className="grid grid-cols-2 gap-8">
                       <div className="space-y-4"><label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Base Prize Pool</label>
                         <div className="relative group">
                            <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                               <Coins className="text-amber-400 group-focus-within:text-[#00E5FF] transition-colors" size={18} />
                            </div>
                            <input type="number" className="glass-input w-full pl-12 !h-14 text-xl font-black" value={drawSettings.currentPrizePool} onChange={(e) => setDrawSettings({...drawSettings, currentPrizePool: parseInt(e.target.value)})} />
                         </div>
                       </div>
                       <div className="space-y-4"><label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Growth Rate (%)</label><input type="number" className="glass-input w-full h-14 text-xl font-black text-emerald-400" value={drawSettings.prizeIncreaseRate} onChange={(e) => setDrawSettings({...drawSettings, prizeIncreaseRate: parseInt(e.target.value)})} /></div>
                    </div>
                    <div className="grid grid-cols-2 gap-8"><div className="space-y-4"><label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Draw Frequency</label><select className="glass-input w-full h-14 outline-none" value={drawSettings.frequencyMinutes} onChange={(e) => setDrawSettings({...drawSettings, frequencyMinutes: parseInt(e.target.value)})}><option value={5}>Every 5 Mins</option><option value={30}>Every 30 Mins</option><option value={60}>Hourly</option></select></div><div className="space-y-4"><label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Max Tickets</label><input type="number" className="glass-input w-full h-14 text-xl font-black" value={drawSettings.maxTicketsPerUser} onChange={(e) => setDrawSettings({...drawSettings, maxTicketsPerUser: parseInt(e.target.value)})}/></div></div>
                   <button onClick={handleSaveDraw} className="w-full py-5 bg-gradient-to-r from-emerald-600 to-emerald-800 rounded-2xl font-black text-sm uppercase tracking-[0.2em] shadow-2xl flex items-center justify-center gap-3"><Save size={18} /> Update Lottery System</button>
                </div>
             </div>
             <div className="space-y-10"><div className="card-glass p-10 bg-slate-950/30 border-amber-500/20"><h4 className="text-sm font-black uppercase text-amber-400 mb-6 flex items-center gap-2"><RefreshCw size={18} /> Super Admin Control</h4><p className="text-xs text-slate-500 font-bold mb-8 italic">Trigger an immediate lottery draw and generate results right now.</p><button className="w-full py-4 bg-amber-500 hover:bg-amber-600 text-black rounded-xl font-black uppercase text-xs tracking-widest transition-all">Manual Draw Trigger</button></div></div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

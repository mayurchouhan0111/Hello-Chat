import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  onSnapshot,
  where,
  limit,
  orderBy
} from 'firebase/firestore';
import { 
  Users, 
  Volume2, 
  Diamond, 
  ShieldAlert, 
  TrendingUp, 
  Activity,
  Flame,
  ArrowUpRight,
  ArrowDownRight
} from 'lucide-react';
import { motion } from 'framer-motion';

export const DashboardHome = () => {
  const [stats, setStats] = useState({
    totalUsers: 0,
    activeRooms: 0,
    totalDiamonds: 0,
    recentReports: []
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // 1. Snapshot for Users Count (Simulated for speed, in production use Cloud Function aggregates)
    const unsubUsers = onSnapshot(collection(db, "users"), (snap) => {
      setStats(prev => ({ ...prev, totalUsers: snap.size }));
    });

    // 2. Snapshot for Active Rooms
    const unsubRooms = onSnapshot(collection(db, "rooms"), (snap) => {
      setStats(prev => ({ ...prev, activeRooms: snap.size }));
    });

    // 3. Snapshot for Recent Reports
    const qReports = query(collection(db, "reports"), orderBy("createdAt", "desc"), limit(4));
    const unsubReports = onSnapshot(qReports, (snap) => {
      setStats(prev => ({ 
        ...prev, 
        recentReports: snap.docs.map(d => ({ id: d.id, ...d.data() })) 
      }));
      setLoading(false);
    });

    return () => {
      unsubUsers();
      unsubRooms();
      unsubReports();
    };
  }, []);

  const cards = [
    { label: 'Total Users', value: stats.totalUsers.toLocaleString(), icon: Users, color: 'from-blue-600 to-indigo-600', growth: '+12%' },
    { label: 'Live Rooms', value: stats.activeRooms.toLocaleString(), icon: Volume2, color: 'from-cyan-500 to-blue-500', growth: '+5%' },
    { label: 'Economic Load', value: 'Syncing...', icon: Diamond, color: 'from-amber-500 to-yellow-500', growth: 'Stable' }
  ];

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Welcome Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              Hello, Admin 👋
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Platform Orchestration Hub • Real-Time Telemetry</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="bg-emerald-500/10 px-6 py-3 rounded-2xl border border-emerald-500/20 backdrop-blur-md shadow-2xl flex items-center gap-3">
              <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse shadow-[0_0_10px_#10b981]"></div>
              <span className="text-emerald-400 font-black tracking-widest text-[10px] uppercase">Ecosystem Healthy</span>
           </div>
        </div>
      </div>

      {/* Main Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        {cards.map((stat, i) => (
          <motion.div 
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className={`bg-gradient-to-br ${stat.color} p-10 rounded-[40px] shadow-2xl border border-white/10 relative overflow-hidden group hover:scale-[1.02] transition-all duration-500`}
          >
            <div className="absolute top-0 right-0 p-10 bg-white/10 rounded-full blur-[40px] translate-x-1/2 -translate-y-1/2 group-hover:scale-125 transition-transform duration-700"></div>
            
            <stat.icon className="text-white/20 absolute right-8 bottom-8" size={80} />
            
            <p className="text-white/70 font-black uppercase tracking-[0.2em] text-[10px] mb-4">{stat.label}</p>
            <h3 className="text-5xl font-black text-white mb-6 tracking-tighter">{stat.value}</h3>
            
            <div className="flex items-center gap-2">
               <span className="bg-white/20 px-4 py-2 rounded-2xl text-[10px] font-black tracking-widest uppercase flex items-center gap-2">
                 {stat.growth.startsWith('+') ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                 {stat.growth} this week
               </span>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Secondary HUD */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
        
        {/* Moderated Feed */}
        <div className="card-glass border-white/5 bg-slate-900/60 p-10 shadow-2xl">
           <div className="flex items-center justify-between mb-10 border-b border-white/5 pb-6">
              <h4 className="text-xl font-black text-white tracking-tight flex items-center gap-4">
                 <ShieldAlert className="text-red-500 animate-pulse" size={24} />
                 Live Risk Stream
              </h4>
              <button className="text-[10px] font-black text-slate-500 hover:text-white uppercase tracking-widest transition-colors">View All Reports</button>
           </div>
           
           <div className="space-y-6">
              {stats.recentReports.length > 0 ? stats.recentReports.map(report => (
                <div key={report.id} className="flex items-center justify-between p-6 bg-white/5 rounded-3xl border border-white/5 hover:bg-white/10 transition-all group cursor-pointer shadow-xl">
                   <div className="flex items-center gap-5">
                      <div className="w-14 h-14 bg-red-500/10 rounded-2xl flex items-center justify-center border border-red-500/20 group-hover:rotate-12 transition-transform shadow-lg">
                         <Flame className={report.status === 'pending' ? 'text-red-500' : 'text-slate-600'} size={24} />
                      </div>
                      <div>
                         <p className="text-sm font-black text-white capitalize">{report.reason || 'User Report'}</p>
                         <p className="text-[10px] uppercase font-black tracking-widest text-slate-500 pt-1 flex items-center gap-2">
                            <Activity size={10} /> Room: {report.roomId?.slice(0,12)} • Just Now
                         </p>
                      </div>
                   </div>
                   <button className="text-[9px] font-black text-primary-light bg-primary/10 px-5 py-2.5 rounded-xl border border-primary/20 hover:bg-primary hover:text-white transition-all shadow-lg">INVESTIGATE</button>
                </div>
              )) : (
                <div className="p-20 text-center border-2 border-dashed border-white/5 rounded-[40px] flex flex-col items-center gap-4">
                   <ShieldAlert className="text-slate-800" size={48} />
                   <p className="text-slate-700 font-black uppercase tracking-widest text-[10px]">Zero Critical Alerts Reported</p>
                </div>
              )}
           </div>
        </div>

        {/* Activity Telemetry */}
        <div className="card-glass border-white/5 bg-slate-900/60 p-10 shadow-2xl">
           <div className="flex items-center justify-between mb-10 border-b border-white/5 pb-6">
              <h4 className="text-xl font-black text-white tracking-tight flex items-center gap-4">
                 <TrendingUp className="text-emerald-400" size={24} />
                 Platform Velocity
              </h4>
              <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest">7-Day Engagement Cycle</p>
           </div>
           
           <div className="h-64 flex items-end justify-between px-6 pb-6 bg-slate-950/50 rounded-[40px] border border-white/5 shadow-inner relative overflow-hidden group">
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-blue-500/5 via-transparent to-transparent"></div>
              {[40, 70, 45, 90, 65, 80, 55].map((h, i) => (
                <div key={i} style={{ height: `${h}%` }} className="w-10 bg-gradient-to-t from-primary to-cyan-400 rounded-2xl opacity-80 hover:opacity-100 transition-all cursor-pointer relative group-hover:shadow-[0_0_20px_rgba(34,211,238,0.2)]">
                   <div className="absolute -top-12 left-1/2 -translate-x-1/2 bg-white text-slate-900 text-[9px] font-black px-3 py-1.5 rounded-xl opacity-0 hover:opacity-100 transition-all shadow-2xl z-20 pointer-events-none">
                     {h * 150} REQ/s
                   </div>
                </div>
              ))}
           </div>
           
           <div className="flex justify-between mt-6 px-4">
              {['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d) => (
                <span key={d} className="text-[10px] font-black uppercase text-slate-600 tracking-[0.2em]">{d}</span>
              ))}
           </div>
        </div>

      </div>
    </div>
  );
};

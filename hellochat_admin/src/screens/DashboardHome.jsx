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
  ArrowDownRight,
  ArrowRightLeft
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useAdmin } from '../context/AdminContext';
import { motion } from 'framer-motion';

export const DashboardHome = () => {
  const { isAdmin, isAgencyOwner, loading: authLoading } = useAdmin();
  const navigate = useNavigate();
  const [stats, setStats] = useState({
    totalUsers: 0,
    activeRooms: 0,
    totalDiamonds: 0,
    activePKs: 0,
    totalRevenue: 0,
    recentReports: [],
    velocityData: [0, 0, 0, 0, 0, 0, 0]
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!authLoading && isAgencyOwner && !isAdmin) {
      navigate('/agencies');
    }
  }, [isAgencyOwner, isAdmin, authLoading, navigate]);

  useEffect(() => {
    // Real-time telemetry snapshots
    const unsubUsers = onSnapshot(collection(db, "users"), (snap) => {
      setStats(prev => ({ ...prev, totalUsers: snap.size }));
    });

    const unsubRooms = onSnapshot(collection(db, "rooms"), (snap) => {
      setStats(prev => ({ ...prev, activeRooms: snap.size }));
    });

    const unsubPKs = onSnapshot(query(collection(db, "rooms"), where("pkActive", "==", true)), (snap) => {
      setStats(prev => ({ ...prev, activePKs: snap.size }));
    });

    const unsubRevenue = onSnapshot(query(collection(db, "recharges"), where("status", "==", "approved")), (snap) => {
      let rev = 0;
      snap.docs.forEach(d => {
        const data = d.data();
        rev += data.price || (data.amount / 100);
      });
      setStats(prev => ({ ...prev, totalRevenue: rev }));
    });

    const qReports = query(collection(db, "reports"), limit(10)); // Fetch more for manual sorting
    const unsubReports = onSnapshot(qReports, (snap) => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      list.sort((a, b) => {
        const timeA = a.createdAt?.toDate?.() || a.timestamp?.toDate?.() || 0;
        const timeB = b.createdAt?.toDate?.() || b.timestamp?.toDate?.() || 0;
        return timeB - timeA;
      });
      setStats(prev => ({ 
        ...prev, 
        recentReports: list.slice(0, 4) 
      }));
    });

    // Velocity Data (Last 7 Days Registrations)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    const qVelocity = query(
      collection(db, "users"), 
      where("createdAt", ">=", sevenDaysAgo)
    );

    const unsubVelocity = onSnapshot(qVelocity, (snap) => {
      const counts = [0, 0, 0, 0, 0, 0, 0];
      const now = new Date();
      
      snap.docs.forEach(doc => {
        const date = doc.data().createdAt?.toDate();
        if (date) {
          const diff = Math.floor((now - date) / (1000 * 60 * 60 * 24));
          if (diff >= 0 && diff < 7) {
            counts[6 - diff]++;
          }
        }
      });
      
      setStats(prev => ({ ...prev, velocityData: counts }));
      setLoading(false);
    });

    return () => {
      unsubUsers();
      unsubRooms();
      unsubPKs();
      unsubRevenue();
      unsubReports();
      unsubVelocity();
    };
  }, []);

  const metricCards = [
    { label: 'Platform Revenue', value: `$${stats.totalRevenue.toLocaleString()}`, icon: TrendingUp, color: 'border-emerald-500/20', glow: 'shadow-emerald-500/5', growth: 'LIVE' },
    { label: 'Ecosystem Users', value: stats.totalUsers.toLocaleString(), icon: Users, color: 'border-blue-500/20', glow: 'shadow-blue-500/5', growth: '+12.4%' },
    { label: 'Active PK Battles', value: stats.activePKs.toLocaleString(), icon: Flame, color: 'border-yellow-500/20', glow: 'shadow-yellow-500/5', growth: 'HIGH' },
    { label: 'Global Live Rooms', value: stats.activeRooms.toLocaleString(), icon: Volume2, color: 'border-purple-500/20', glow: 'shadow-purple-500/5', growth: '+5.2%' },
  ];

  return (
    <div className="space-y-12 animate-in fade-in duration-1000">
      {/* 🚀 Hero Section */}
      <section className="flex flex-col md:flex-row md:items-end justify-between gap-8">
        <div>
           <div className="flex items-center gap-3 mb-4">
              <span className="w-2 h-2 bg-[#B4E0A2] rounded-full animate-ping"></span>
              <span className="text-[10px] font-black tracking-[0.4em] text-[#B4E0A2] uppercase">System Operational</span>
           </div>
           <h1 className="text-5xl font-black text-white tracking-tighter leading-none">
              DASHBOARD <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#B4E0A2] to-[#8DBB7E]">COMMAND</span>
           </h1>
           <p className="text-gray-500 font-bold text-xs uppercase tracking-widest mt-4">Real-time platform telemetry & user engagement metrics</p>
        </div>

        <div className="flex items-center gap-4 bg-white/[0.02] p-2 rounded-3xl border border-white/[0.05]">
          {['24H', '7D', '30D', 'ALL'].map((t) => (
            <button key={t} className={`px-6 py-2.5 rounded-2xl text-[10px] font-black transition-all ${t === '7D' ? 'bg-[#B4E0A2] text-black shadow-lg shadow-[#B4E0A2]/20' : 'text-gray-500 hover:text-white'}`}>
              {t}
            </button>
          ))}
        </div>
      </section>

      {/* 📊 High-Level Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-8">
        {metricCards.map((card, i) => (
          <motion.div 
            key={card.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className={`card-premium border-l-4 ${card.color} ${card.glow} relative group cursor-default`}
          >
            <div className="flex justify-between items-start mb-6">
              <div className="p-4 bg-white/[0.03] rounded-2xl group-hover:scale-110 transition-transform">
                <card.icon className="text-white/40" size={24} />
              </div>
              <span className="text-[10px] font-black text-[#B4E0A2] bg-[#B4E0A2]/10 px-3 py-1.5 rounded-full tracking-wider">{card.growth}</span>
            </div>
            
            <p className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-1">{card.label}</p>
            <h3 className="text-4xl font-black text-white tracking-tighter">{card.value}</h3>
            
            <div className="mt-8 h-1 bg-white/[0.03] rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-[#B4E0A2] to-[#8DBB7E] w-2/3"></div>
            </div>
          </motion.div>
        ))}
      </div>

      {/* 🛡️ Risk & Activity HUD */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
        
        {/* Live Security Stream */}
        <div className="card-premium relative overflow-hidden group">
           <div className="absolute top-0 right-0 p-20 bg-red-500/5 blur-[100px] pointer-events-none"></div>
           
           <div className="flex items-center justify-between mb-10">
              <div className="flex items-center gap-4">
                 <div className="w-12 h-12 bg-red-500/10 rounded-2xl flex items-center justify-center border border-red-500/20">
                    <ShieldAlert className="text-red-500" size={24} />
                 </div>
                 <div>
                    <h4 className="text-lg font-black text-white tracking-tight">Security Alerts</h4>
                    <p className="text-[10px] font-bold text-gray-500 uppercase tracking-widest mt-1">Pending Investigations</p>
                 </div>
              </div>
              <button onClick={() => navigate('/reports')} className="btn-primary-neon !px-4 !py-2 !text-[9px] uppercase tracking-widest">Global Audit</button>
           </div>
           
           <div className="space-y-4">
              {stats.recentReports.length > 0 ? stats.recentReports.map((report, i) => (
                <motion.div 
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.4 + (i * 0.1) }}
                  key={report.id} 
                  className="flex items-center justify-between p-5 bg-white/[0.01] rounded-2xl border border-white/[0.03] hover:bg-white/[0.03] transition-all group cursor-pointer"
                >
                   <div className="flex items-center gap-5">
                      <div className="w-2 h-2 bg-red-500 rounded-full shadow-[0_0_8px_#ef4444]"></div>
                      <div>
                         <p className="text-sm font-bold text-white leading-none">{report.reason || 'Anomalous Behavior'}</p>
                         <p className="text-[10px] font-bold text-gray-600 mt-2 tracking-wider flex items-center gap-2 uppercase">
                            <Activity size={10} /> Room ID: {report.roomId?.slice(0,8)}...
                         </p>
                      </div>
                   </div>
                   <ArrowRightLeft size={16} className="text-gray-700 group-hover:text-[#B4E0A2] group-hover:translate-x-1 transition-all" />
                </motion.div>
              )) : (
                <div className="py-20 text-center border-2 border-dashed border-white/[0.02] rounded-[40px]">
                   <ShieldAlert className="mx-auto text-gray-800 mb-4" size={40} />
                   <p className="text-gray-700 font-black uppercase tracking-[0.3em] text-[10px]">Perimeter Secured • No Threats</p>
                </div>
              )}
           </div>
        </div>

        {/* 📈 Engagement Analytics */}
        <div className="card-premium relative overflow-hidden group">
           <div className="absolute top-0 right-0 p-20 bg-[#B4E0A2]/5 blur-[100px] pointer-events-none"></div>
           
           <div className="flex items-center justify-between mb-10">
              <div className="flex items-center gap-4">
                 <div className="w-12 h-12 bg-[#B4E0A2]/10 rounded-2xl flex items-center justify-center border border-[#B4E0A2]/20">
                    <TrendingUp className="text-[#B4E0A2]" size={24} />
                 </div>
                 <div>
                    <h4 className="text-lg font-black text-white tracking-tight">Ecosystem Growth</h4>
                    <p className="text-[10px] font-bold text-gray-500 uppercase tracking-widest mt-1">Platform Velocity Index</p>
                 </div>
              </div>
           </div>
           
           <div className="h-64 flex items-end justify-between px-6 pb-6 bg-black/40 rounded-[32px] border border-white/[0.03] shadow-inner relative overflow-hidden group/chart">
              <div className="absolute inset-0 bg-gradient-to-t from-[#B4E0A2]/5 to-transparent"></div>
              {stats.velocityData.map((val, i) => {
                const max = Math.max(...stats.velocityData, 1);
                const h = (val / max) * 80 + 10; // min 10% height
                return (
                  <div 
                    key={i} 
                    style={{ height: `${h}%` }} 
                    className="w-12 bg-gradient-to-t from-[#B4E0A2] to-[#8DBB7E] rounded-t-2xl opacity-60 hover:opacity-100 transition-all cursor-pointer relative group-hover/chart:shadow-[0_0_30px_rgba(180,224,162,0.1)]"
                  >
                     <div className="absolute -top-12 left-1/2 -translate-x-1/2 bg-white text-black text-[9px] font-black px-3 py-1.5 rounded-xl opacity-0 hover:opacity-100 transition-all shadow-2xl z-20 pointer-events-none">
                       {val} NEW USERS
                     </div>
                  </div>
                );
              })}
           </div>
           
           <div className="flex justify-between mt-8 px-6">
              {Array.from({ length: 7 }).map((_, i) => {
                const d = new Date();
                d.setDate(d.getDate() - (6 - i));
                const label = d.toLocaleDateString('en-US', { weekday: 'short' });
                return (
                  <span key={i} className="text-[10px] font-black uppercase text-gray-600 tracking-widest">{label}</span>
                );
              })}
           </div>
        </div>

      </div>
    </div>
  );
};

import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, getDocs, doc, deleteDoc, orderBy, limit, onSnapshot, writeBatch } from 'firebase/firestore';
import { 
  Trash2, 
  Image as ImageIcon, 
  MessageSquare, 
  Heart, 
  Search, 
  RefreshCcw,
  AlertCircle,
  Clock,
  User
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const MomentsManagement = () => {
  const [moments, setMoments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const { user } = useAdmin();

  useEffect(() => {
    const q = query(collection(db, "moments"), orderBy("createdAt", "desc"), limit(100));
    const unsubscribe = onSnapshot(q, (snap) => {
      setMoments(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleDelete = async (moment) => {
    if (!window.confirm("Delete this moment permanently?")) return;
    
    try {
      await deleteDoc(doc(db, "moments", moment.id));
      await logAdminAction(user, "DELETE_MOMENT", "MODERATION", { 
        momentId: moment.id, 
        authorId: moment.userId,
        caption: moment.caption?.slice(0, 30)
      });
    } catch (err) {
      alert("Error deleting moment: " + err.message);
    }
  };

  const deleteFakeMoments = async () => {
    const count = moments.filter(m => m.id.startsWith('test_moment_')).length;
    if (count === 0) return alert("No fake moments found in the current view.");
    if (!window.confirm(`Delete ${count} fake moments?`)) return;

    try {
      const batch = writeBatch(db);
      moments.forEach(m => {
        if (m.id.startsWith('test_moment_')) {
          batch.delete(doc(db, "moments", m.id));
        }
      });
      await batch.commit();
      await logAdminAction(user, "PURGE_FAKE_MOMENTS", "MODERATION", { count });
      alert(`Successfully deleted ${count} moments.`);
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const filteredMoments = moments.filter(m => 
    m.caption?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    m.userId?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-indigo-500/20 rounded-2xl border border-indigo-500/30">
                 <ImageIcon className="text-indigo-400" size={28} />
              </div>
              Moments Moderation
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Content Governance • {moments.length} Recent Posts</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group w-96">
              <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                 <Search className="text-slate-600 group-focus-within:text-[#00E5FF] transition-colors" size={18} />
              </div>
              <input 
                type="text" 
                placeholder="Search caption or user ID..." 
                className="glass-input w-full pl-12 !py-3.5"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
           </div>
           <button 
             onClick={deleteFakeMoments}
             className="h-14 px-6 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-2xl border border-red-500/20 transition-all font-black text-xs uppercase tracking-widest flex items-center gap-3"
           >
             <Trash2 size={16} />
             Purge Fake
           </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col items-center justify-center py-40 space-y-4">
           <RefreshCcw className="text-indigo-400 animate-spin" size={40} />
           <p className="text-slate-500 font-black uppercase tracking-[0.2em] text-xs">Syncing with Grid...</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
           <AnimatePresence>
             {filteredMoments.map((moment) => (
               <motion.div 
                 key={moment.id}
                 layout
                 initial={{ opacity: 0, y: 20 }}
                 animate={{ opacity: 1, y: 0 }}
                 exit={{ opacity: 0, scale: 0.9 }}
                 className="card-glass group overflow-hidden flex flex-col bg-slate-900/40 border-white/5 hover:border-indigo-500/30 transition-all"
               >
                 {/* Post Image */}
                 <div className="aspect-square relative overflow-hidden bg-slate-950">
                    <img 
                      src={moment.imageUrl} 
                      alt="" 
                      className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
                    />
                    <div className="absolute top-4 right-4 flex gap-2">
                       <button 
                         onClick={() => handleDelete(moment)}
                         className="p-3 bg-red-500 text-white rounded-xl shadow-2xl opacity-0 group-hover:opacity-100 transform translate-y-2 group-hover:translate-y-0 transition-all duration-300"
                       >
                          <Trash2 size={18} />
                       </button>
                    </div>
                    {moment.id.startsWith('test_moment_') && (
                       <div className="absolute top-4 left-4 px-3 py-1 bg-amber-500 text-slate-950 text-[10px] font-black uppercase rounded-lg">
                          Fake Account
                       </div>
                    )}
                 </div>

                 {/* Post Info */}
                 <div className="p-6 space-y-4 flex-1 flex flex-col">
                    <div className="flex items-center gap-3">
                       <div className="w-8 h-8 rounded-lg bg-indigo-500/20 flex items-center justify-center">
                          <User size={14} className="text-indigo-400" />
                       </div>
                       <div className="flex-1 min-w-0">
                          <p className="text-[10px] font-black text-slate-500 uppercase tracking-tighter">Contributor UID</p>
                          <p className="text-xs font-bold text-white truncate">{moment.userId}</p>
                       </div>
                    </div>

                    <p className="text-xs text-slate-400 leading-relaxed italic flex-1">
                       "{moment.caption || 'No caption provided'}"
                    </p>

                    <div className="pt-4 border-t border-white/5 flex items-center justify-between">
                       <div className="flex items-center gap-4">
                          <div className="flex items-center gap-1.5">
                             <Heart size={12} className="text-rose-500" />
                             <span className="text-[10px] font-black">{moment.likesCount || 0}</span>
                          </div>
                          <div className="flex items-center gap-1.5">
                             <MessageSquare size={12} className="text-indigo-400" />
                             <span className="text-[10px] font-black">{moment.commentsCount || 0}</span>
                          </div>
                       </div>
                       <div className="flex items-center gap-1 text-slate-600">
                          <Clock size={10} />
                          <span className="text-[9px] font-black">
                            {moment.createdAt?.toDate().toLocaleDateString() || 'Recent'}
                          </span>
                       </div>
                    </div>
                 </div>
               </motion.div>
             ))}
           </AnimatePresence>

           {filteredMoments.length === 0 && (
             <div className="col-span-full py-40 text-center border-2 border-dashed border-white/5 rounded-[40px] space-y-4">
                <AlertCircle className="mx-auto text-slate-800" size={64} />
                <p className="text-slate-600 font-black uppercase tracking-widest text-lg">No Moments Found</p>
                <p className="text-slate-700 text-xs font-bold">Try adjusting your search criteria</p>
             </div>
           )}
        </div>
      )}
    </div>
  );
};

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
  serverTimestamp,
  deleteDoc
} from 'firebase/firestore';
import { 
  Building2, 
  Plus, 
  Users, 
  TrendingUp, 
  Percent, 
  UserPlus, 
  History, 
  Trash2,
  Edit3,
  Network,
  Save,
  Search,
  CheckCircle,
  FileText
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export const AgencyManagement = () => {
  const [agencies, setAgencies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingAgency, setEditingAgency] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');

  // New Agency State
  const [newAgency, setNewAgency] = useState({
    name: '',
    ownerUid: '',
    commissionRate: 5, // Default 5%
    description: '',
    isActive: true
  });

  useEffect(() => {
    const q = query(collection(db, "agencies"), orderBy("name", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setAgencies(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    const data = editingAgency || newAgency;
    const agencyId = editingAgency ? editingAgency.id : doc(collection(db, "agencies")).id;
    
    try {
      await setDoc(doc(db, "agencies", agencyId), {
        ...data,
        updatedAt: serverTimestamp()
      }, { merge: true });
      
      setEditingAgency(null);
      setNewAgency({ name: '', ownerUid: '', commissionRate: 5, description: '', isActive: true });
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const deleteAgency = async (id) => {
    if (!window.confirm("Permanently dissolve this agency? This will unlink all hosts.")) return;
    await deleteDoc(doc(db, "agencies", id));
  };

  const filteredAgencies = agencies.filter(a => 
    a.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    a.ownerUid?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-cyan-500/20 rounded-2xl border border-cyan-500/30">
                 <Building2 className="text-cyan-400" size={28} />
              </div>
              Agency Hierarchy
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Platform Guild Orchestration • {agencies.length} Licensed Nodes</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group">
              <Search className="absolute left-4 top-4 text-slate-500 group-focus-within:text-cyan-400" size={20} />
              <input 
                type="text" 
                placeholder="Search agencies..." 
                className="input-field w-64 pl-12 bg-slate-950/50 border-white/5"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
           </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        
        {/* Agency List */}
        <div className="lg:col-span-2 space-y-8">
           <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {loading ? (
                <div className="col-span-full py-20 text-center animate-pulse py-40 font-black text-slate-700 uppercase tracking-widest Tracking... Hierarchy">Hierarchy Mapping...</div>
              ) : filteredAgencies.map((agency) => (
                <motion.div 
                  key={agency.id}
                  whileHover={{ scale: 1.02 }}
                  className="card-glass p-8 bg-slate-900/60 border-white/5 hover:border-cyan-500/30 transition-all flex flex-col justify-between group shadow-2xl relative overflow-hidden"
                >
                   <div className="absolute top-0 right-0 p-10 bg-cyan-500/5 rounded-full blur-2xl group-hover:scale-125 transition-transform"></div>
                   
                   <div className="flex items-center justify-between mb-8 relative">
                      <div className="p-3 bg-white/5 rounded-2xl border border-white/10 group-hover:border-cyan-400/30 transition-all">
                         <Network className="text-cyan-400" size={24} />
                      </div>
                      <div className="text-right">
                         <span className="text-[10px] font-black px-2 py-0.5 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded uppercase tracking-widest">
                            {agency.commissionRate}% RATE
                         </span>
                      </div>
                   </div>

                   <div className="relative">
                      <h3 className="text-2xl font-black text-white group-hover:text-cyan-400 transition-colors uppercase tracking-tight">{agency.name}</h3>
                      <p className="text-[10px] font-bold text-slate-500 mt-2 uppercase flex items-center gap-2 tracking-widest italic">
                         <Users size={12} className="text-slate-800" /> OWNER: @{agency.ownerUid?.slice(0,10)}
                      </p>
                      
                      <div className="flex gap-4 mt-8 pt-6 border-t border-white/5">
                         <button 
                          onClick={() => setEditingAgency(agency)}
                          className="flex-1 flex items-center justify-center gap-2 p-3 bg-white/5 hover:bg-white/10 text-[10px] font-black uppercase tracking-widest text-slate-400 rounded-xl border border-white/10 transition-all"
                         >
                            <Edit3 size={14} /> Configure
                         </button>
                         <button 
                          onClick={() => deleteAgency(agency.id)}
                          className="p-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-xl border border-red-500/20 transition-all"
                         >
                            <Trash2 size={14} />
                         </button>
                      </div>
                   </div>
                </motion.div>
              ))}
           </div>
        </div>

        {/* Editor HUb */}
        <div className="space-y-8">
           <div className="card-glass p-10 bg-slate-900/80 border-cyan-500/30 shadow-cyan-500/10 shadow-2xl relative overflow-hidden">
              <div className="absolute top-0 right-0 p-10 bg-cyan-500/10 rounded-full blur-3xl -translate-x-1/2 -translate-y-1/2"></div>
              
              <div className="flex items-center justify-between mb-8 border-b border-white/5 pb-6 relative">
                 <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4">
                    {editingAgency ? <Edit3 size={20} className="text-cyan-400" /> : <Plus size={20} className="text-cyan-400" />}
                    {editingAgency ? 'Modify Agency' : 'Register Agency'}
                 </h3>
                 {editingAgency && <button onClick={() => setEditingAgency(null)} className="text-slate-500 hover:text-white uppercase font-black text-[10px] bg-white/5 px-2 py-1 rounded transition-colors">Abort</button>}
              </div>

              <form onSubmit={handleSave} className="space-y-6 relative">
                 <div className="space-y-3">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Company Name</label>
                    <input 
                      required
                      className="input-field w-full h-14 bg-slate-950/50"
                      value={editingAgency ? editingAgency.name : newAgency.name}
                      onChange={(e) => editingAgency ? setEditingAgency({...editingAgency, name: e.target.value}) : setNewAgency({...newAgency, name: e.target.value})}
                    />
                 </div>

                 <div className="space-y-3">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Owner Uid (Firebase Uid)</label>
                    <input 
                      required
                      className="input-field w-full h-14 bg-slate-950/50 italic"
                      value={editingAgency ? editingAgency.ownerUid : newAgency.ownerUid}
                      onChange={(e) => editingAgency ? setEditingAgency({...editingAgency, ownerUid: e.target.value}) : setNewAgency({...newAgency, ownerUid: e.target.value})}
                    />
                 </div>

                 <div className="space-y-3">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Commission Rate (%)</label>
                    <div className="relative">
                       <Percent className="absolute left-4 top-4 text-slate-800" size={18} />
                       <input 
                         required type="number" 
                         className="input-field w-full h-14 bg-slate-950/50 pl-12"
                         value={editingAgency ? editingAgency.commissionRate : newAgency.commissionRate}
                         onChange={(e) => editingAgency ? setEditingAgency({...editingAgency, commissionRate: parseInt(e.target.value)}) : setNewAgency({...newAgency, commissionRate: parseInt(e.target.value)})}
                       />
                    </div>
                 </div>

                 <button 
                  type="submit"
                  className="w-full flex items-center justify-center gap-3 py-5 bg-cyan-500 hover:bg-cyan-600 text-slate-950 rounded-2xl font-black uppercase text-xs tracking-[0.2em] shadow-2xl transition-all transform active:scale-[0.98] mt-4 shadow-cyan-500/20"
                 >
                    <Save size={18} /> {editingAgency ? 'Synchronize Nodes' : 'Deploy Agency'}
                 </button>
              </form>
           </div>

           <div className="card-glass p-8 bg-cyan-500/5 border-cyan-500/10">
              <h5 className="text-[10px] font-black text-cyan-400 uppercase tracking-[0.3em] mb-4 flex items-center gap-2">
                 <History size={14} /> Audit Trail
              </h5>
              <p className="text-xs text-slate-400 font-bold leading-relaxed italic">
                 "Platform data linkage: Agencies govern host settlements. Linkage ensures correct bean distribution during month-end settlements."
              </p>
           </div>
        </div>

      </div>
    </div>
  );
};

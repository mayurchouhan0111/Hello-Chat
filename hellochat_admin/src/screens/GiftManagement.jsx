import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  doc, 
  setDoc, 
  deleteDoc, 
  onSnapshot,
  orderBy,
  serverTimestamp
} from 'firebase/firestore';
import { 
  Gift, 
  Plus, 
  Trash2, 
  Edit3, 
  Eye, 
  EyeOff, 
  Search, 
  Filter,
  Coins,
  Layers,
  Sparkles,
  Link as LinkIcon,
  Save,
  X
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Player } from '@lottiefiles/react-lottie-player';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const GiftManagement = () => {
  const [gifts, setGifts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [editingGift, setEditingGift] = useState(null);
  const { user } = useAdmin();
  
  // New Gift State
  const [newGift, setNewGift] = useState({
    name: '',
    priceInDiamonds: 0,
    category: 'small',
    imageUrl: '',
    lottieAssetPath: '',
    isActive: true,
    sortOrder: 0
  });

  useEffect(() => {
    const q = query(collection(db, "gifts"), orderBy("priceInDiamonds", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setGifts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    const data = editingGift || newGift;
    const giftId = editingGift ? editingGift.id : doc(collection(db, "gifts")).id;
    
    try {
      await setDoc(doc(db, "gifts", giftId), {
        ...data,
        giftId,
        updatedAt: serverTimestamp()
      }, { merge: true });
      
      await logAdminAction(user, editingGift ? "GIFT_UPDATE" : "GIFT_ADD", giftId, { name: data.name, price: data.priceInDiamonds });

      setEditingGift(null);
      setNewGift({
        name: '',
        priceInDiamonds: 0,
        category: 'small',
        imageUrl: '',
        lottieAssetPath: '',
        isActive: true,
        sortOrder: 0
      });
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const toggleActive = async (gift) => {
    await setDoc(doc(db, "gifts", gift.id), { isActive: !gift.isActive }, { merge: true });
    await logAdminAction(user, "GIFT_TOGGLE", gift.id, { isActive: !gift.isActive });
  };

  const deleteGift = async (id) => {
    if (!window.confirm("Permanently delete this gift? This cannot be undone.")) return;
    await deleteDoc(doc(db, "gifts", id));
    await logAdminAction(user, "GIFT_DELETE", id);
  };

  const filteredGifts = gifts.filter(g => 
    g.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    g.category?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-[#B4E0A2]/20 rounded-2xl border border-[#B4E0A2]/30">
                 <Gift className="text-[#B4E0A2]" size={28} />
              </div>
              Gift Catalog
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Monetization Hub • {gifts.length} Assets in Store</p>
        </div>

        <div className="flex items-center gap-4">
           <div className="relative group w-64">
              <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                 <Search className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
              </div>
              <input 
                type="text" 
                placeholder="Search gifts..." 
                className="glass-input w-full pl-12 !py-3.5"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
           </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        
        {/* Gift List Table */}
        <div className="lg:col-span-2 space-y-6">
           <div className="card-glass p-0 bg-[#18181B]/40 border-white/5 overflow-hidden shadow-2xl">
              <table className="w-full text-left">
                 <thead className="bg-white/5 border-b border-white/5 text-[10px] uppercase font-black tracking-widest text-slate-500">
                    <tr>
                       <th className="px-8 py-5">Gift Info</th>
                       <th className="px-8 py-5">Category</th>
                       <th className="px-8 py-5">Price</th>
                       <th className="px-8 py-5 text-right">Actions</th>
                    </tr>
                 </thead>
                 <tbody className="divide-y divide-white/[0.03]">
                    {loading ? (
                      <tr><td colSpan="4" className="p-20 text-center animate-pulse py-40 font-black text-slate-700 uppercase tracking-widest">Inventory Synchronizing...</td></tr>
                    ) : filteredGifts.map((gift) => (
                      <tr key={gift.id} className="group hover:bg-white/5 transition-all">
                         <td className="px-8 py-6">
                            <div className="flex items-center gap-4">
                               <div className="w-14 h-14 bg-white/5 rounded-2xl border border-white/10 flex items-center justify-center relative shadow-lg">
                                  {gift.lottieAssetPath ? (
                                     <div className="w-10 h-10">
                                        <Player 
                                          src={gift.lottieAssetPath} 
                                          loop 
                                          autoplay 
                                          style={{ height: '40px', width: '40px' }}
                                        />
                                     </div>
                                  ) : gift.imageUrl ? (
                                     <img 
                                       src={gift.imageUrl} 
                                       className="w-10 h-10 object-contain" 
                                       onError={(e) => {
                                         e.target.onerror = null;
                                         e.target.src = "https://cdn-icons-png.flaticon.com/512/833/833544.png";
                                       }}
                                     />
                                  ) : (
                                     <Sparkles className="text-slate-800" size={24} />
                                  )}
                               </div>
                               <div>
                                  <p className="text-sm font-black text-white">{gift.name}</p>
                                  <p className="text-[10px] font-bold text-slate-600 uppercase mt-1 flex items-center gap-2">
                                   ID: {gift.id.slice(0,8)}
                                   {gift.lottieAssetPath && <span className="w-1.5 h-1.5 bg-[#B4E0A2] rounded-full animate-pulse shadow-[0_0_5px_rgba(180,224,162,0.5)]"></span>}
                                </p>
                               </div>
                            </div>
                         </td>
                         <td className="px-8 py-6">
                            <span className={`px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-widest ${gift.category === 'luxury' ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30 shadow-[0_0_15px_rgba(245,158,11,0.2)]' : 'bg-white/5 text-slate-400 border border-white/10'}`}>
                               {gift.category}
                            </span>
                         </td>
                         <td className="px-8 py-6">
                            <div className="flex items-center gap-2 text-emerald-400 font-black">
                               <Coins size={14} />
                               <span className="text-sm">{gift.priceInDiamonds?.toLocaleString()}</span>
                            </div>
                         </td>
                         <td className="px-8 py-6">
                            <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                               <button 
                                onClick={() => toggleActive(gift)}
                                className={`p-2 rounded-xl transition-all ${gift.isActive ? 'text-emerald-400 hover:bg-emerald-500/10' : 'text-slate-600 hover:bg-white/5'}`}
                               >
                                  {gift.isActive ? <Eye size={18} /> : <EyeOff size={18} />}
                               </button>
                               <button 
                                onClick={() => setEditingGift(gift)}
                                className="p-2 text-[#B4E0A2] hover:bg-[#B4E0A2]/10 rounded-xl transition-all"
                               >
                                  <Edit3 size={18} />
                               </button>
                               <button 
                                onClick={() => deleteGift(gift.id)}
                                className="p-2 text-red-500 hover:bg-red-500/10 rounded-xl transition-all"
                               >
                                  <Trash2 size={18} />
                               </button>
                            </div>
                         </td>
                      </tr>
                    ))}
                 </tbody>
              </table>
           </div>
        </div>

        {/* Editor Form */}
        <div className="space-y-8">
           <div className="card-glass p-10 bg-[#18181B]/60 border-white/5 shadow-[#B4E0A2]/5 shadow-2xl relative overflow-hidden group">
              <div className="absolute top-0 right-0 p-10 bg-[#B4E0A2]/10 rounded-full blur-3xl -translate-x-1/2 -translate-y-1/2"></div>
              
              <div className="flex items-center justify-between mb-8">
                 <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-3">
                    {editingGift ? <Edit3 size={20} className="text-[#B4E0A2]" /> : <Plus size={20} className="text-[#B4E0A2]" />}
                    {editingGift ? 'Edit Gift' : 'Add New Gift'}
                 </h3>
                 {editingGift && <button onClick={() => setEditingGift(null)} className="text-slate-500 hover:text-white transition-colors"><X size={20} /></button>}
              </div>

              {/* Asset Preview Section */}
              <div className="mb-10 flex justify-center">
                 <div className="relative group">
                    <div className="w-32 h-32 bg-white/[0.02] border border-white/5 rounded-3xl flex items-center justify-center relative overflow-hidden shadow-2xl">
                       {/* Priority 1: Lottie Animation */}
                       {(editingGift?.lottieAssetPath || newGift.lottieAssetPath) ? (
                          <div className="w-28 h-28 z-10">
                            <Player 
                              key={editingGift ? editingGift.lottieAssetPath : newGift.lottieAssetPath}
                              src={editingGift ? editingGift.lottieAssetPath : newGift.lottieAssetPath} 
                              loop 
                              autoplay
                              style={{ height: '112px', width: '112px' }}
                            />
                          </div>
                       ) : (editingGift?.imageUrl || newGift.imageUrl) ? (
                          <img 
                            src={editingGift ? editingGift.imageUrl : newGift.imageUrl} 
                            className="w-24 h-24 object-contain z-10" 
                            alt="Preview"
                          />
                       ) : (
                          <Sparkles className="text-slate-800" size={48} />
                       )}
                       
                       {/* Static Icon Overlay (if both exist) */}
                       {(editingGift?.lottieAssetPath || newGift.lottieAssetPath) && (editingGift?.imageUrl || newGift.imageUrl) && (
                          <div className="absolute bottom-2 right-2 w-8 h-8 bg-slate-900/80 rounded-lg border border-white/10 p-1 z-20">
                             <img src={editingGift ? editingGift.imageUrl : newGift.imageUrl} className="w-full h-full object-contain" />
                          </div>
                       )}
                    </div>
                    <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 px-4 py-1 bg-[#18181B] border border-white/10 rounded-full text-[8px] font-black uppercase tracking-widest text-[#B4E0A2]">
                       Live Asset Preview
                    </div>
                 </div>
              </div>

              <form onSubmit={handleSave} className="space-y-6">
                 <div className="space-y-3">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Name of Gift</label>
                    <input 
                      required
                      placeholder="e.g. Diamond Heart"
                      className="glass-input w-full"
                      value={editingGift ? editingGift.name : newGift.name}
                      onChange={(e) => editingGift ? setEditingGift({...editingGift, name: e.target.value}) : setNewGift({...newGift, name: e.target.value})}
                    />
                 </div>

                 <div className="grid grid-cols-2 gap-6">
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Cost (Diamonds)</label>
                       <div className="relative">
                          <Coins className="absolute left-4 top-1/2 -translate-y-1/2 text-emerald-400" size={16} />
                          <input 
                            required type="number"
                            className="glass-input w-full pl-12"
                            value={editingGift ? editingGift.priceInDiamonds : newGift.priceInDiamonds}
                            onChange={(e) => editingGift ? setEditingGift({...editingGift, priceInDiamonds: parseInt(e.target.value)}) : setNewGift({...newGift, priceInDiamonds: parseInt(e.target.value)})}
                          />
                       </div>
                    </div>
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Category</label>
                       <select 
                         className="glass-input w-full outline-none appearance-none"
                         value={editingGift ? editingGift.category : newGift.category}
                         onChange={(e) => editingGift ? setEditingGift({...editingGift, category: e.target.value}) : setNewGift({...newGift, category: e.target.value})}
                       >
                          <option value="Normal">Normal</option>
                          <option value="Vip">Vip</option>
                          <option value="Luxury">Luxury</option>
                          <option value="Animated">Animated</option>
                       </select>
                    </div>
                 </div>

                 <div className="space-y-3">
                     <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Icon URL (Static PNG)</label>
                     <div className="relative group">
                        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                           <LinkIcon className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
                        </div>
                        <input 
                          placeholder="https://..."
                          className="glass-input w-full pl-12"
                          value={editingGift ? editingGift.imageUrl : newGift.imageUrl}
                          onChange={(e) => editingGift ? setEditingGift({...editingGift, imageUrl: e.target.value}) : setNewGift({...newGift, imageUrl: e.target.value})}
                        />
                     </div>
                  </div>

                  <div className="space-y-3">
                     <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Special Effect URL (Lottie JSON)</label>
                     <div className="relative group">
                        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                           <Sparkles className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
                        </div>
                        <input 
                          className="glass-input w-full pl-12 placeholder:italic"
                          placeholder="Optional .json animation url..."
                          value={editingGift ? editingGift.lottieAssetPath : newGift.lottieAssetPath}
                          onChange={(e) => editingGift ? setEditingGift({...editingGift, lottieAssetPath: e.target.value}) : setNewGift({...newGift, lottieAssetPath: e.target.value})}
                        />
                     </div>
                  </div>

                  <button 
                   type="submit"
                   className="w-full flex items-center justify-center gap-3 py-5 bg-[#B4E0A2] hover:bg-[#8DBB7E] text-black rounded-[32px] font-black uppercase text-xs tracking-[0.2em] shadow-lg shadow-[#B4E0A2]/20 transition-all transform active:scale-[0.98] mt-4"
                  >
                     <Save size={18} /> {editingGift ? 'Update Inventory' : 'Add to Catalog'}
                  </button>
              </form>
           </div>

           <div className="card-glass p-8 bg-emerald-500/5 border-emerald-500/10">
              <h5 className="text-[10px] font-black text-emerald-400 uppercase tracking-[0.3em] mb-4 flex items-center gap-2">
                 <Sparkles size={14} /> Performance Notice
              </h5>
              <p className="text-xs text-slate-400 font-bold leading-relaxed">
                 Use **JSON (Lottie)** for animations instead of GIFs. Lottie files are vectors and stay sharp on all screen sizes while being 10x smaller in size.
              </p>
           </div>
        </div>

      </div>
    </div>
  );
};

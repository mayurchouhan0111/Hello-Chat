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
  ShoppingBag, 
  Diamond, 
  Plus, 
  Trash2, 
  Save, 
  Image as ImageIcon,
  Clock,
  Sparkles,
  Search,
  CheckCircle2,
  XCircle
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const EliteBoutiqueManagement = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingItem, setEditingItem] = useState(null);
  const [creating, setCreating] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const { user } = useAdmin();

  useEffect(() => {
    const q = query(collection(db, "prestige_items"), orderBy("name", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setItems(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...editingItem,
        updatedAt: serverTimestamp(),
        isActive: editingItem.isActive ?? true
      };
      const itemId = editingItem.id || editingItem.name.toLowerCase().replaceAll(' ', '_');
      await setDoc(doc(db, "prestige_items", itemId), data, { merge: true });
      await logAdminAction(user, "PRESTIGE_ITEM_UPDATE", itemId, { name: data.name, price: data.price });
      setEditingItem(null);
      setCreating(false);
      alert("Item Synced to Boutique Repository!");
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleDelete = async (id) => {
    if(!window.confirm("Delete this exclusive item from the Boutique?")) return;
    try {
      await deleteDoc(doc(db, "prestige_items", id));
      await logAdminAction(user, "PRESTIGE_ITEM_DELETE", id);
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleSeedBoutique = async () => {
    if(!window.confirm("CRITICAL: This will feed the Boutique with default high-prestige items. Continue?")) return;
    setLoading(true);
    try {
      const defaultItems = [
        { name: 'Nebula Frame', price: 500, category: 'frame', imageUrl: 'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=400&h=400&fit=crop', validityDays: 30, isActive: true },
        { name: 'Royal Crown', price: 1200, category: 'frame', imageUrl: 'https://images.unsplash.com/photo-1590494165264-1ebe3602eb80?w=400&h=400&fit=crop', validityDays: 7, isActive: true },
        { name: 'Crystal Bubble', price: 300, category: 'bubble', imageUrl: 'https://images.unsplash.com/photo-1518063311540-06a91f47cbe6?w=400&h=400&fit=crop', validityDays: 15, isActive: true },
        { name: 'Dragon Steed', price: 15000, category: 'mount', imageUrl: 'https://images.unsplash.com/photo-1519003300449-43c2c192d6e3?w=400&h=400&fit=crop', validityDays: 30, isActive: true },
        { name: 'Cyber Car', price: 50000, category: 'mount', imageUrl: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=400&h=400&fit=crop', validityDays: 365, isActive: true },
      ];

      const batch = defaultItems.map(item => {
        const id = item.name.toLowerCase().replaceAll(' ', '_');
        return setDoc(doc(db, "prestige_items", id), { ...item, createdAt: serverTimestamp() });
      });

      await Promise.all(batch);
      await logAdminAction(user, "BOUTIQUE_FEED_DATA", "system");
      alert("Boutique Repository Initialized with Elite Data!");
    } catch (err) {
      alert("Seed Error: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  const createNewItem = () => {
    setEditingItem({
      name: '',
      price: 0,
      category: 'frame',
      imageUrl: '',
      validityDays: 30,
      isActive: true
    });
    setCreating(true);
  };

  const filteredItems = items.filter(item => 
    item.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    item.category.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-teal-500/20 rounded-2xl border border-teal-500/30 shadow-teal-500/10 shadow-lg">
                 <ShoppingBag className="text-teal-400" size={28} />
              </div>
              Elite Boutique
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">Prop & Mount Repository Management • {items.length} Items</p>
        </div>
        <div className="flex items-center gap-3">
          <button 
            onClick={handleSeedBoutique}
            className="px-6 py-3 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white border border-red-500/20 rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all"
          >
            Feed Default Items
          </button>
          <button 
            onClick={createNewItem}
            className="px-6 py-3 bg-teal-500/10 hover:bg-teal-500 hover:text-slate-950 text-teal-500 border border-teal-500/20 rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all"
          >
            <Plus size={14} className="inline mr-2" /> New Boutique Item
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        
        {/* Items List */}
        <div className="lg:col-span-7 space-y-8">
            <div className="flex items-center justify-between px-2 bg-slate-900/40 p-4 rounded-2xl border border-white/5">
                <div className="flex items-center gap-4 flex-1">
                    <Search className="text-slate-600" size={18} />
                    <input 
                        type="text" 
                        placeholder="SEARCH FRAMES, MOUNTS, BUBBLES..." 
                        className="bg-transparent border-none focus:ring-0 text-sm font-bold w-full text-slate-300 placeholder:text-slate-700"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              {loading ? (
                <div className="col-span-full py-40 text-center animate-pulse font-black text-slate-700 uppercase tracking-widest">Boutique Stream Syncing...</div>
              ) : filteredItems.map((item) => (
                <motion.div 
                  key={item.id}
                  whileHover={{ scale: 1.02, y: -5 }}
                  onClick={() => setEditingItem(item)}
                  className={`card-glass p-6 cursor-pointer transition-all border shadow-2xl relative overflow-hidden group ${editingItem?.id === item.id ? 'border-teal-400/50 bg-teal-500/10' : 'bg-slate-900/60 border-white/5'}`}
                >
                   <div className="flex items-center justify-between mb-6 relative">
                      <div className="w-16 h-16 bg-white/5 rounded-2xl border border-white/10 flex items-center justify-center shadow-lg group-hover:border-teal-400/30 transition-all p-2 overflow-hidden">
                         <img src={item.imageUrl} alt="" className="max-w-full max-h-full object-contain" onError={(e) => e.target.src = "https://placehold.co/60x60?text=Item"} />
                      </div>
                      <div className="text-right">
                         <p className="text-sm font-black text-teal-400 tracking-tighter uppercase flex items-center gap-2 justify-end">
                            <Diamond size={12} /> {item.price?.toLocaleString() || '---'}
                         </p>
                         <p className={`text-[9px] font-black uppercase mt-1 ${item.isActive ? 'text-emerald-500' : 'text-rose-500'}`}>
                            {item.isActive ? 'IN STOCK' : 'HIDDEN'}
                         </p>
                      </div>
                   </div>
                   <h3 className="text-md font-black text-white uppercase tracking-tight">{item.name}</h3>
                   <div className="flex gap-2 mt-4 items-center justify-between">
                      <span className="text-[9px] font-black px-2 py-0.5 bg-white/5 text-slate-500 border border-white/10 rounded uppercase tracking-widest">{item.category}</span>
                      <div className="flex gap-2">
                        <button onClick={(e) => { e.stopPropagation(); handleDelete(item.id); }} className="p-2 bg-rose-500/10 text-rose-500 hover:bg-rose-500 hover:text-white rounded-lg transition-all opacity-0 group-hover:opacity-100">
                            <Trash2 size={12} />
                        </button>
                      </div>
                   </div>
                </motion.div>
              ))}
            </div>
        </div>

        {/* Editor HUD */}
        <div className="lg:col-span-5 space-y-6">
           <AnimatePresence mode="wait">
             {editingItem ? (
               <motion.div 
                 key="editor"
                 initial={{ opacity: 0, x: 20 }}
                 animate={{ opacity: 1, x: 0 }}
                 exit={{ opacity: 0, x: 20 }}
                 className="card-glass p-8 bg-slate-900/80 border-teal-500/30 shadow-teal-500/10 shadow-2xl sticky top-8"
               >
                  <div className="flex items-center justify-between mb-8 border-b border-white/5 pb-6">
                     <h3 className="text-lg font-black text-white tracking-tight uppercase flex items-center gap-4">
                        <Sparkles className="text-teal-400" size={20} /> 
                        {creating ? 'NEW ITEM' : `CONFIGURE ${editingItem.name}`}
                     </h3>
                     <button onClick={() => { setEditingItem(null); setCreating(false); }} className="px-3 py-1 bg-white/5 text-slate-500 rounded hover:text-white uppercase font-black text-[9px] transition-colors">Close</button>
                  </div>

                  <form onSubmit={handleSave} className="space-y-6">
                     <div className="space-y-3">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Item Display Name</label>
                        <input 
                          required type="text" 
                          className="input-field w-full h-12 bg-slate-950/50 text-white font-bold"
                          value={editingItem.name || ''}
                          onChange={(e) => setEditingItem({...editingItem, name: e.target.value})}
                          placeholder="EX: DRAGON MOUNT"
                        />
                     </div>

                     <div className="grid grid-cols-2 gap-6">
                        <div className="space-y-3">
                           <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Category</label>
                           <select 
                             className="input-field w-full h-12 bg-slate-950/50 text-white font-bold px-4"
                             value={editingItem.category || 'frame'}
                             onChange={(e) => setEditingItem({...editingItem, category: e.target.value})}
                           >
                             <option value="frame">Frame</option>
                             <option value="bubble">Bubble</option>
                             <option value="mount">Mount</option>
                             <option value="effect">Effect</option>
                           </select>
                        </div>
                        <div className="space-y-3">
                           <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Price (Diamonds)</label>
                           <div className="relative">
                                <Diamond className="absolute left-4 top-3.5 text-teal-500" size={14} />
                                <input 
                                required type="number" 
                                className="input-field w-full h-12 bg-slate-950/50 text-white pl-10 font-black"
                                value={editingItem.price || 0}
                                onChange={(e) => setEditingItem({...editingItem, price: parseInt(e.target.value)})}
                                />
                           </div>
                        </div>
                     </div>

                     <div className="space-y-3">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Asset Image URL</label>
                        <div className="relative">
                            <ImageIcon className="absolute left-4 top-3.5 text-slate-700" size={16} />
                            <input 
                            required type="text" 
                            className="input-field w-full h-12 bg-slate-950/50 pl-12 text-xs font-mono"
                            value={editingItem.imageUrl || ''}
                            onChange={(e) => setEditingItem({...editingItem, imageUrl: e.target.value})}
                            placeholder="HTTPS://I.IBB.CO/..."
                            />
                        </div>
                     </div>

                     <div className="space-y-3">
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Validity Logic</label>
                        <div className="relative">
                            <Clock className="absolute left-4 top-3.5 text-slate-700" size={16} />
                            <input 
                            required type="number" 
                            className="input-field w-full h-12 bg-slate-950/50 pl-12 font-bold"
                            value={editingItem.validityDays || 30}
                            onChange={(e) => setEditingItem({...editingItem, validityDays: parseInt(e.target.value)})}
                            placeholder="30"
                            />
                            <span className="absolute right-4 top-3.5 text-[10px] font-black text-slate-700 uppercase">DAYS</span>
                        </div>
                     </div>

                     <div className="flex items-center gap-6 pt-4">
                        <label className="flex items-center gap-3 cursor-pointer group">
                             <div className={`w-10 h-6 rounded-full transition-all relative ${editingItem.isActive ? 'bg-teal-500' : 'bg-slate-800'}`} onClick={() => setEditingItem({...editingItem, isActive: !editingItem.isActive})}>
                                <div className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-all ${editingItem.isActive ? 'right-1' : 'left-1'}`}></div>
                             </div>
                             <span className="text-xs font-bold text-slate-400 group-hover:text-white transition-colors uppercase">Store Visibility</span>
                        </label>
                     </div>

                     <button 
                      type="submit"
                      className="w-full flex items-center justify-center gap-3 py-4 bg-teal-500 hover:bg-teal-600 text-slate-950 rounded-2xl font-black uppercase text-xs tracking-[0.2em] shadow-2xl transition-all transform active:scale-[0.98] mt-6 shadow-teal-500/20"
                     >
                        <Save size={18} /> SYNC TO BOUTIQUE
                     </button>
                  </form>
               </motion.div>
             ) : (
               <div className="p-20 text-center border-2 border-dashed border-white/5 rounded-[40px] flex flex-col items-center gap-4 bg-slate-900/20 h-full justify-center min-h-[500px]">
                  <ShoppingBag className="text-slate-800 mb-2" size={48} />
                  <p className="text-slate-700 font-bold uppercase tracking-widest text-xs">Select an item to modify inventory</p>
               </div>
             )}
           </AnimatePresence>
        </div>

      </div>
    </div>
  );
};

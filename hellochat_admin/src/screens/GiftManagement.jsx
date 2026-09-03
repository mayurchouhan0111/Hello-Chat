import { useState, useEffect } from 'react';
import { db, storage } from '../firebase';
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
  ref, 
  uploadBytesResumable, 
  getDownloadURL 
} from 'firebase/storage';
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
  X,
  Upload,
  Loader2,
  Video
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Player } from '@lottiefiles/react-lottie-player';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const GiftManagement = () => {
  const [gifts, setGifts] = useState([]);
  const [pendingCustomGifts, setPendingCustomGifts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [editingGift, setEditingGift] = useState(null);
  const [uploadingField, setUploadingField] = useState(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const { user } = useAdmin();
  
  // New Gift State
  const [newGift, setNewGift] = useState({
    name: '',
    priceInDiamonds: 0,
    category: 'Normal',
    imageUrl: '',
    lottieAssetPath: '',
    soundUrl: '',
    animationFormat: 'json', // json, svga, mp4, vpa, image, sound
    minSvipLevel: 0,
    isActive: true,
    sortOrder: 0
  });

  useEffect(() => {
    const q = query(collection(db, "gifts"), orderBy("priceInDiamonds", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setGifts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });

    const unsubCustom = onSnapshot(collection(db, "custom_gift_requests"), (snap) => {
      setPendingCustomGifts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    return () => { unsub(); unsubCustom(); };
  }, []);

  const handleApproveCustom = async (req, price) => {
    try {
      const giftId = `custom_${req.userId}_${Date.now()}`;
      await setDoc(doc(db, "gifts", giftId), {
        giftId,
        name: req.giftName || `${req.userName || 'User'}'s Custom Gift`,
        priceInDiamonds: Number(price || 10000),
        category: 'Custom',
        imageUrl: req.thumbnailUrl || req.videoUrl || '',
        lottieAssetPath: req.videoUrl || '',
        soundUrl: req.soundUrl || '',
        animationFormat: 'mp4',
        isActive: true,
        sortOrder: 1,
        creatorUid: req.userId,
        createdAt: serverTimestamp()
      });
      await setDoc(doc(db, "custom_gift_requests", req.id), { status: 'approved', approvedAt: serverTimestamp() }, { merge: true });
      await logAdminAction(user, "CUSTOM_GIFT_APPROVE", req.id, { name: req.giftName, price });
      alert("✅ Custom Gift approved and added to store!");
    } catch (e) {
      alert("Approval Error: " + e.message);
    }
  };

  const handleRejectCustom = async (reqId) => {
    if (!window.confirm("Reject this Custom Gift request?")) return;
    await setDoc(doc(db, "custom_gift_requests", reqId), { status: 'rejected', rejectedAt: serverTimestamp() }, { merge: true });
    await logAdminAction(user, "CUSTOM_GIFT_REJECT", reqId);
  };

  const handleFileUpload = async (e, fieldType) => {
    const file = e.target.files[0];
    if (!file) return;

    const currentForm = editingGift || newGift;
    const format = currentForm.animationFormat || 'json';
    const ext = file.name.split('.').pop().toLowerCase();

    // Format validation
    if (fieldType === 'image') {
      if (!['png', 'jpg', 'jpeg', 'webp', 'gif'].includes(ext)) {
        alert("❌ Invalid Image Format! Only PNG, JPG, JPEG, GIF, and WEBP are supported.");
        return;
      }
    } else if (fieldType === 'sound') {
      if (!['mp3', 'wav', 'aac', 'm4a', 'ogg'].includes(ext)) {
        alert("❌ Invalid Audio Format! Only MP3, WAV, AAC, M4A, and OGG are supported.");
        return;
      }
    } else if (fieldType === 'animation') {
      if (format === 'svga' && ext !== 'svga') {
        alert("❌ Format Mismatch! Selected format is SVGA (.svga), but uploaded file is ." + ext);
        return;
      } else if (format === 'mp4' && ext !== 'mp4') {
        alert("❌ Format Mismatch! Selected format is MP4 (.mp4), but uploaded file is ." + ext);
        return;
      } else if (format === 'json' && ext !== 'json') {
        alert("❌ Format Mismatch! Selected format is Lottie JSON (.json), but uploaded file is ." + ext);
        return;
      } else if (format === 'image' && !['png', 'jpg', 'jpeg', 'gif', 'webp'].includes(ext)) {
        alert("❌ Format Mismatch! Selected format is Image/GIF.");
        return;
      }
    }

    setUploadingField(fieldType);
    setUploadProgress(0);

    const storageRef = ref(storage, `gifts/${fieldType}_${Date.now()}_${file.name}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        setUploadProgress(progress);
      },
      (error) => {
        alert("Upload Failed: " + error.message);
        setUploadingField(null);
      },
      () => {
        getDownloadURL(uploadTask.snapshot.ref).then((downloadURL) => {
          if (editingGift) {
            setEditingGift(prev => ({
              ...prev,
              [fieldType === 'image' ? 'imageUrl' : 'lottieAssetPath']: downloadURL
            }));
          } else {
            setNewGift(prev => ({
              ...prev,
              [fieldType === 'image' ? 'imageUrl' : 'lottieAssetPath']: downloadURL
            }));
          }
          setUploadingField(null);
        });
      }
    );
  };

  const handleSave = async (e) => {
    e.preventDefault();
    const data = editingGift || newGift;
    const giftId = editingGift ? editingGift.id : doc(collection(db, "gifts")).id;
    
    try {
      await setDoc(doc(db, "gifts", giftId), {
        ...data,
        giftId,
        sortOrder: Number(data.sortOrder || 0),
        priceInDiamonds: Number(data.priceInDiamonds || 0),
        minSvipLevel: Number(data.minSvipLevel || 0),
        animationFormat: data.animationFormat || 'json',
        updatedAt: serverTimestamp()
      }, { merge: true });
      
      await logAdminAction(user, editingGift ? "GIFT_UPDATE" : "GIFT_ADD", giftId, { name: data.name, price: data.priceInDiamonds });

      setEditingGift(null);
      setNewGift({
        name: '',
        priceInDiamonds: 0,
        category: 'Normal',
        imageUrl: '',
        lottieAssetPath: '',
        animationFormat: 'json',
        minSvipLevel: 0,
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
           {/* Level 50 Custom Gift Applications Queue */}
           {pendingCustomGifts.filter(r => r.status === 'pending').length > 0 && (
             <div className="card-glass p-6 bg-amber-500/10 border-amber-500/30 rounded-2xl space-y-4">
               <div className="flex items-center justify-between">
                 <h3 className="text-sm font-black text-amber-400 uppercase tracking-widest flex items-center gap-2">
                   <Sparkles size={16} /> Level 50+ Custom Gift Submissions ({pendingCustomGifts.filter(r => r.status === 'pending').length})
                 </h3>
               </div>
               <div className="space-y-3">
                 {pendingCustomGifts.filter(r => r.status === 'pending').map((req) => (
                   <div key={req.id} className="p-4 bg-slate-900/80 rounded-xl border border-white/10 flex flex-col md:flex-row md:items-center justify-between gap-4">
                     <div>
                       <p className="text-xs font-black text-white">{req.giftName || 'Custom Video Gift'}</p>
                       <p className="text-[10px] text-slate-400 font-bold">User: {req.userName || req.userId} (Lv.{req.userLevel || 50})</p>
                       {req.videoUrl && (
                         <video src={req.videoUrl} controls className="w-48 h-28 object-cover rounded-lg mt-2 border border-white/10" />
                       )}
                     </div>
                     <div className="flex items-center gap-2">
                       <input 
                         type="number" 
                         placeholder="Price (Diamonds)" 
                         id={`price_${req.id}`}
                         defaultValue={10000}
                         className="glass-input !w-32 !py-2 text-xs"
                       />
                       <button 
                         onClick={() => {
                           const priceVal = document.getElementById(`price_${req.id}`).value;
                           handleApproveCustom(req, priceVal);
                         }}
                         className="px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-black font-black text-[10px] uppercase rounded-xl"
                       >
                         Approve
                       </button>
                       <button 
                         onClick={() => handleRejectCustom(req.id)}
                         className="px-4 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 font-black text-[10px] uppercase rounded-xl border border-red-500/30"
                       >
                         Reject
                       </button>
                     </div>
                   </div>
                 ))}
               </div>
             </div>
           )}

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
                         className="glass-input w-full outline-none appearance-none cursor-pointer bg-slate-900 text-white border border-white/10 rounded-xl px-4 h-12"
                         value={editingGift ? editingGift.category : newGift.category}
                         onChange={(e) => editingGift ? setEditingGift({...editingGift, category: e.target.value}) : setNewGift({...newGift, category: e.target.value})}
                       >
                          <option value="Normal">Normal Gift</option>
                          <option value="Gift">Standard Gift</option>
                          <option value="Luxury">Luxury Gift (Full Screen)</option>
                          <option value="Lucky">Lucky Gift (Random Rewards)</option>
                          <option value="Lucky fruit">Lucky fruit Gift</option>
                          <option value="Relationship">Relationship Gift</option>
                          <option value="VIP">VIP Gift (VIP Only)</option>
                          <option value="SVIP">SVIP Gift (SVIP Only)</option>
                       </select>
                    </div>
                 </div>

                 <div className="grid grid-cols-2 gap-6">
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Animation Format</label>
                       <select 
                         className="glass-input w-full outline-none appearance-none cursor-pointer bg-slate-900 text-white border border-white/10 rounded-xl px-4 h-12"
                         value={editingGift ? editingGift.animationFormat || 'json' : newGift.animationFormat || 'json'}
                         onChange={(e) => editingGift ? setEditingGift({...editingGift, animationFormat: e.target.value}) : setNewGift({...newGift, animationFormat: e.target.value})}
                       >
                          <option value="json">Lottie JSON (.json)</option>
                          <option value="svga">SVGA (.svga)</option>
                          <option value="mp4">MP4 Video (.mp4)</option>
                          <option value="vpa">VPA Luxury (.vpa)</option>
                       </select>
                    </div>
                    <div className="space-y-3">
                       <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Display Order (Sort)</label>
                       <input 
                         type="number" min="0" placeholder="0"
                         className="glass-input w-full h-12"
                         value={editingGift ? editingGift.sortOrder || 0 : newGift.sortOrder || 0}
                         onChange={(e) => editingGift ? setEditingGift({...editingGift, sortOrder: parseInt(e.target.value)}) : setNewGift({...newGift, sortOrder: parseInt(e.target.value)})}
                       />
                    </div>
                 </div>

                 {/* Image File Upload & URL */}
                 <div className="space-y-3">
                     <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Gift Icon (PNG, JPG, WEBP)</label>
                     <div className="flex gap-3">
                        <div className="relative group flex-1">
                           <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                              <LinkIcon className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
                           </div>
                           <input 
                             placeholder="Icon URL or upload file..."
                             className="glass-input w-full pl-12"
                             value={editingGift ? editingGift.imageUrl : newGift.imageUrl}
                             onChange={(e) => editingGift ? setEditingGift({...editingGift, imageUrl: e.target.value}) : setNewGift({...newGift, imageUrl: e.target.value})}
                           />
                        </div>
                        <div className="relative">
                          <input 
                            type="file" accept="image/png,image/jpeg,image/webp"
                            onChange={(e) => handleFileUpload(e, 'image')}
                            className="absolute inset-0 opacity-0 w-full h-full cursor-pointer z-10"
                            disabled={uploadingField === 'image'}
                          />
                          <button type="button" className="h-12 px-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl flex items-center gap-2 text-xs font-bold text-slate-300">
                             {uploadingField === 'image' ? <Loader2 className="animate-spin text-[#B4E0A2]" size={16} /> : <Upload size={16} className="text-[#B4E0A2]" />}
                             <span>Upload Icon</span>
                          </button>
                        </div>
                     </div>
                  </div>

                  {/* Animation File Upload & URL */}
                  <div className="space-y-3">
                     <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                        Animation File ({(editingGift?.animationFormat || newGift.animationFormat || 'json').toUpperCase()})
                     </label>
                     <div className="flex gap-3">
                        <div className="relative group flex-1">
                           <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                              <Sparkles className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
                           </div>
                           <input 
                             className="glass-input w-full pl-12 placeholder:italic"
                             placeholder="Animation URL or upload file..."
                             value={editingGift ? editingGift.lottieAssetPath : newGift.lottieAssetPath}
                             onChange={(e) => editingGift ? setEditingGift({...editingGift, lottieAssetPath: e.target.value}) : setNewGift({...newGift, lottieAssetPath: e.target.value})}
                           />
                        </div>
                        <div className="relative">
                          <input 
                            type="file" 
                            accept=".svga,.mp4,.json,.vpa"
                            onChange={(e) => handleFileUpload(e, 'animation')}
                            className="absolute inset-0 opacity-0 w-full h-full cursor-pointer z-10"
                            disabled={uploadingField === 'animation'}
                          />
                          <button type="button" className="h-12 px-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl flex items-center gap-2 text-xs font-bold text-slate-300">
                             {uploadingField === 'animation' ? <Loader2 className="animate-spin text-[#B4E0A2]" size={16} /> : <Upload size={16} className="text-[#B4E0A2]" />}
                             <span>Upload Anim</span>
                          </button>
                        </div>
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

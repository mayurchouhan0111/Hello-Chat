import { useState, useEffect } from 'react';
import { db, storage } from '../firebase';
import { 
  collection, 
  query, 
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
  Coins,
  Sparkles,
  Link as LinkIcon,
  Save,
  X,
  Upload,
  Loader2,
  PlayCircle,
  AlertTriangle
} from 'lucide-react';
// eslint-disable-next-line no-unused-vars
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
  const [previewingGift, setPreviewingGift] = useState(null);
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
    animationFormat: 'json', // json, svga, mp4, vpa, pag, image, sound
    tier: '',                 // '' = derive from category | NORMAL | MEDIUM | LUXURY
    durationMs: 0,            // 0 = auto (asset-derived)
    minSvipLevel: 0,
    isActive: true,
    sortOrder: 0
  });

  // Shelf categories shown in the app's gift box, in client-specified order.
  const GIFT_CATEGORIES = ['Normal', 'Lucky', 'Medium', 'Luxury', 'CP', 'SVGA', 'VAP', 'Custom', 'Family Battle', 'VIP', 'SVIP'];

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
      const giftId = `custom_${req.userId}_${req.id}`;
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
      } else if (format === 'vap' && !['vap', 'mp4', 'zip', 'vpa'].includes(ext)) {
        alert("❌ Format Mismatch! Selected format is VAP (.vap, .mp4, .zip), but uploaded file is ." + ext);
        return;
      } else if (format === 'vpa' && !['vpa', 'vap', 'mp4'].includes(ext)) {
        alert("❌ Format Mismatch! Selected format is VPA (.vpa), but uploaded file is ." + ext);
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

    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
    const storageRef = ref(storage, `gifts/${fieldType}_${safeName}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = Math.round((snapshot.bytesTransferred / snapshot.totalBytes) * 100);
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
          setUploadProgress(100);
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
        tier: data.tier || '',
        durationMs: Number(data.durationMs || 0),
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
        soundUrl: '',
        animationFormat: 'json',
        tier: '',
        durationMs: 0,
        minSvipLevel: 0,
        isActive: true,
        sortOrder: 0
      });
    } catch (err) {
      alert("Error saving gift: " + err.message);
    }
  };

  const toggleActive = async (gift) => {
    const nextState = !gift.isActive;
    await setDoc(doc(db, "gifts", gift.id), { isActive: nextState }, { merge: true });
    await logAdminAction(user, "GIFT_TOGGLE", gift.id, { isActive: nextState });
  };

  const deleteGift = async (gift) => {
    const id = gift.id;
    const msg = `WARNING: Permanently deleting "${gift.name || id}" can break past transaction ledgers and financial audit logs referencing this gift ID.\n\nRecommended: Toggle the gift to INACTIVE instead to remove it from the user store while preserving financial records.\n\nType DELETE to confirm permanent deletion:`;
    const input = window.prompt(msg);
    if (input !== 'DELETE') return;
    
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
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Monetization Hub • {gifts.length} Assets in Store • Safe Financial Ledger Protection
          </p>
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
                        className="px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-black font-black text-[10px] uppercase rounded-xl cursor-pointer"
                      >
                        Approve
                      </button>
                      <button 
                        onClick={() => handleRejectCustom(req.id)}
                        className="px-4 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 font-black text-[10px] uppercase rounded-xl border border-red-500/30 cursor-pointer"
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
                  <th className="px-8 py-5">Category & Format</th>
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
                        <div 
                          onClick={() => setPreviewingGift(gift)}
                          className="w-14 h-14 bg-white/5 rounded-2xl border border-white/10 flex items-center justify-center relative shadow-lg cursor-pointer hover:border-[#B4E0A2]/50 transition-colors"
                          title="Click to preview animation"
                        >
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
                              alt={gift.name}
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
                            <span className={`px-1.5 py-0.5 rounded text-[8px] font-bold ${gift.isActive ? 'bg-emerald-500/20 text-emerald-400' : 'bg-slate-700 text-slate-400'}`}>
                              {gift.isActive ? 'ACTIVE' : 'INACTIVE'}
                            </span>
                            {gift.lottieAssetPath && <span className="w-1.5 h-1.5 bg-[#B4E0A2] rounded-full animate-pulse shadow-[0_0_5px_rgba(180,224,162,0.5)]" />}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-8 py-6">
                      <div className="flex flex-col gap-1">
                        <span className={`px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest w-fit ${((gift.category || '').toLowerCase() === 'luxury' || gift.tier === 'LUXURY') ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' : gift.tier === 'MEDIUM' ? 'bg-violet-500/20 text-violet-400 border border-violet-500/30' : 'bg-white/5 text-slate-400 border border-white/10'}`}>
                          {gift.category}{gift.tier ? ` · ${gift.tier}` : ''}
                        </span>
                        <span className="text-[9px] font-mono text-slate-500 uppercase ml-1">
                          Format: {gift.animationFormat || 'json'}
                        </span>
                      </div>
                    </td>
                    <td className="px-8 py-6">
                      <div className="flex items-center gap-2 text-emerald-400 font-black">
                        <Coins size={14} />
                        <span className="text-sm">{gift.priceInDiamonds?.toLocaleString()}</span>
                      </div>
                    </td>
                    <td className="px-8 py-6">
                      <div className="flex items-center justify-end gap-2 opacity-80 group-hover:opacity-100 transition-opacity">
                        <button 
                          onClick={() => setPreviewingGift(gift)}
                          className="p-2 text-indigo-400 hover:bg-indigo-500/10 rounded-xl transition-all cursor-pointer"
                          title="Preview Animation"
                        >
                          <PlayCircle size={18} />
                        </button>
                        <button 
                          onClick={() => toggleActive(gift)}
                          className={`p-2 rounded-xl transition-all cursor-pointer ${gift.isActive ? 'text-emerald-400 hover:bg-emerald-500/10' : 'text-slate-600 hover:bg-white/5'}`}
                          title={gift.isActive ? "Deactivate Gift (Preserves financial history)" : "Activate Gift"}
                        >
                          {gift.isActive ? <Eye size={18} /> : <EyeOff size={18} />}
                        </button>
                        <button 
                          onClick={() => setEditingGift(gift)}
                          className="p-2 text-[#B4E0A2] hover:bg-[#B4E0A2]/10 rounded-xl transition-all cursor-pointer"
                          title="Edit Gift Details"
                        >
                          <Edit3 size={18} />
                        </button>
                        <button 
                          onClick={() => deleteGift(gift)}
                          className="p-2 text-red-500 hover:bg-red-500/10 rounded-xl transition-all cursor-pointer"
                          title="Delete Gift"
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
          <div className="card-glass p-8 bg-[#18181B]/60 border-white/5 shadow-2xl relative overflow-hidden group">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-3">
                {editingGift ? <Edit3 size={20} className="text-[#B4E0A2]" /> : <Plus size={20} className="text-[#B4E0A2]" />}
                {editingGift ? 'Edit Gift' : 'Add New Gift'}
              </h3>
              {editingGift && (
                <button onClick={() => setEditingGift(null)} className="text-slate-500 hover:text-white transition-colors cursor-pointer">
                  <X size={20} />
                </button>
              )}
            </div>

            {/* Live Asset Preview Button / Card */}
            <div className="mb-8 flex flex-col items-center gap-3">
              <div 
                onClick={() => setPreviewingGift(editingGift || newGift)}
                className="w-32 h-32 bg-white/[0.02] border border-white/10 hover:border-[#B4E0A2]/50 rounded-3xl flex items-center justify-center relative overflow-hidden shadow-2xl cursor-pointer group/prev transition-all"
                title="Click to launch full preview player"
              >
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
                
                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/prev:opacity-100 flex items-center justify-center transition-opacity z-30">
                  <PlayCircle size={28} className="text-[#B4E0A2]" />
                </div>
              </div>
              <button
                type="button"
                onClick={() => setPreviewingGift(editingGift || newGift)}
                className="text-[9px] font-black uppercase tracking-widest text-[#B4E0A2] hover:underline flex items-center gap-1 cursor-pointer"
              >
                <PlayCircle size={12} /> Test / Preview Animation
              </button>
            </div>

            <form onSubmit={handleSave} className="space-y-5">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Name of Gift</label>
                <input 
                  required
                  placeholder="e.g. Diamond Heart"
                  className="glass-input w-full"
                  value={editingGift ? editingGift.name : newGift.name}
                  onChange={(e) => editingGift ? setEditingGift({...editingGift, name: e.target.value}) : setNewGift({...newGift, name: e.target.value})}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Cost (Diamonds)</label>
                  <div className="relative">
                    <Coins className="absolute left-4 top-1/2 -translate-y-1/2 text-emerald-400" size={16} />
                    <input 
                      required type="number"
                      className="glass-input w-full pl-12"
                      value={editingGift ? editingGift.priceInDiamonds : newGift.priceInDiamonds}
                      onChange={(e) => editingGift ? setEditingGift({...editingGift, priceInDiamonds: parseInt(e.target.value) || 0}) : setNewGift({...newGift, priceInDiamonds: parseInt(e.target.value) || 0})}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Category</label>
                  <select 
                    className="glass-input w-full outline-none appearance-none cursor-pointer bg-slate-900 text-white border border-white/10 rounded-xl px-4 h-12"
                    value={editingGift ? editingGift.category : newGift.category}
                    onChange={(e) => editingGift ? setEditingGift({...editingGift, category: e.target.value}) : setNewGift({...newGift, category: e.target.value})}
                  >
                    {GIFT_CATEGORIES.map(c => (
                      <option key={c} value={c}>{c} Gift</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Animation Format</label>
                  <select 
                    className="glass-input w-full outline-none appearance-none cursor-pointer bg-slate-900 text-white border border-white/10 rounded-xl px-4 h-12"
                    value={editingGift ? editingGift.animationFormat || 'json' : newGift.animationFormat || 'json'}
                    onChange={(e) => editingGift ? setEditingGift({...editingGift, animationFormat: e.target.value}) : setNewGift({...newGift, animationFormat: e.target.value})}
                  >
                    <option value="json">Lottie JSON (.json)</option>
                    <option value="svga">SVGA (.svga)</option>
                    <option value="mp4">MP4 Video (.mp4)</option>
                    <option value="vap">VAP (.vap, .mp4, .zip)</option>
                    <option value="vpa">VPA (.vpa)</option>
                  </select>
                </div>

                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Animation Tier</label>
                  <select 
                    className="glass-input w-full outline-none appearance-none cursor-pointer bg-slate-900 text-white border border-white/10 rounded-xl px-4 h-12"
                    value={(editingGift ? editingGift.tier : newGift.tier) || ''}
                    onChange={(e) => editingGift ? setEditingGift({...editingGift, tier: e.target.value}) : setNewGift({...newGift, tier: e.target.value})}
                  >
                    <option value="">Auto (derived)</option>
                    <option value="NORMAL">NORMAL</option>
                    <option value="MEDIUM">MEDIUM</option>
                    <option value="LUXURY">LUXURY</option>
                  </select>
                </div>
              </div>

              {/* Image Icon File Upload & URL */}
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Gift Icon (PNG, JPG, WEBP)</label>
                <div className="flex gap-2">
                  <div className="relative group flex-1">
                    <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                      <LinkIcon className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={16} />
                    </div>
                    <input 
                      placeholder="Icon URL or upload..."
                      className="glass-input w-full pl-10 text-xs"
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
                    <button type="button" className="h-12 px-3 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl flex items-center gap-1.5 text-xs font-bold text-slate-300">
                      {uploadingField === 'image' ? <Loader2 className="animate-spin text-[#B4E0A2]" size={14} /> : <Upload size={14} className="text-[#B4E0A2]" />}
                      <span>Upload</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* Animation File Upload & URL */}
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Animation Asset ({(editingGift?.animationFormat || newGift.animationFormat || 'json').toUpperCase()})
                </label>
                <div className="flex gap-2">
                  <div className="relative group flex-1">
                    <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                      <Sparkles className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={16} />
                    </div>
                    <input 
                      className="glass-input w-full pl-10 text-xs placeholder:italic"
                      placeholder="Animation asset URL or upload..."
                      value={editingGift ? editingGift.lottieAssetPath : newGift.lottieAssetPath}
                      onChange={(e) => editingGift ? setEditingGift({...editingGift, lottieAssetPath: e.target.value}) : setNewGift({...newGift, lottieAssetPath: e.target.value})}
                    />
                  </div>
                  <div className="relative">
                    <input 
                      type="file" 
                      accept=".svga,.mp4,.json,.vpa,.vap"
                      onChange={(e) => handleFileUpload(e, 'animation')}
                      className="absolute inset-0 opacity-0 w-full h-full cursor-pointer z-10"
                      disabled={uploadingField === 'animation'}
                    />
                    <button type="button" className="h-12 px-3 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl flex items-center gap-1.5 text-xs font-bold text-slate-300">
                      {uploadingField === 'animation' ? <Loader2 className="animate-spin text-[#B4E0A2]" size={14} /> : <Upload size={14} className="text-[#B4E0A2]" />}
                      <span>Upload</span>
                    </button>
                  </div>
                </div>
              </div>

              {uploadingField && (
                <div className="p-3 bg-white/5 rounded-xl border border-white/10">
                  <div className="flex justify-between text-xs text-slate-400 mb-1">
                    <span>Uploading {uploadingField}...</span>
                    <span>{uploadProgress}%</span>
                  </div>
                  <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                    <div className="bg-[#B4E0A2] h-full transition-all duration-300" style={{ width: `${uploadProgress}%` }} />
                  </div>
                </div>
              )}

              <button 
                type="submit"
                className="w-full flex items-center justify-center gap-3 py-4 bg-[#B4E0A2] hover:bg-[#8DBB7E] text-black rounded-[24px] font-black uppercase text-xs tracking-[0.2em] shadow-lg shadow-[#B4E0A2]/20 transition-all cursor-pointer mt-2"
              >
                <Save size={16} /> {editingGift ? 'Update Inventory' : 'Add to Catalog'}
              </button>
            </form>
          </div>

          <div className="card-glass p-6 bg-amber-500/5 border-amber-500/10 rounded-2xl space-y-2">
            <h5 className="text-[10px] font-black text-amber-400 uppercase tracking-widest flex items-center gap-2">
              <AlertTriangle size={14} /> Ledger Protection Policy
            </h5>
            <p className="text-xs text-slate-400 font-medium leading-relaxed">
              Toggling a gift to Inactive preserves complete historical transaction records and ledger balances for all hosts and agencies. Never hard-delete active or historically sent gifts.
            </p>
          </div>
        </div>
      </div>

      {/* Animation Preview Modal Before Activation */}
      <AnimatePresence>
        {previewingGift && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md">
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-[#121214] border border-white/[0.08] w-full max-w-lg rounded-[32px] p-8 shadow-2xl relative text-white"
            >
              <button
                onClick={() => setPreviewingGift(null)}
                className="absolute top-6 right-6 p-2 text-gray-400 hover:text-white rounded-xl hover:bg-white/[0.05] transition-all cursor-pointer"
              >
                <X size={20} />
              </button>

              <div className="flex items-center gap-3 mb-6">
                <div className="p-3 bg-[#B4E0A2]/10 text-[#B4E0A2] rounded-2xl border border-[#B4E0A2]/20">
                  <PlayCircle size={24} />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white">Gift Animation Preview</h2>
                  <p className="text-gray-400 text-xs mt-0.5">
                    {previewingGift.name || 'Gift Preview'} • {previewingGift.priceInDiamonds || 0} 💎
                  </p>
                </div>
              </div>

              {/* Preview Player Surface */}
              <div className="w-full h-64 bg-black/60 border border-white/10 rounded-2xl flex items-center justify-center relative overflow-hidden mb-6">
                {previewingGift.lottieAssetPath && (previewingGift.animationFormat === 'json' || previewingGift.lottieAssetPath.endsWith('.json')) ? (
                  <div className="w-48 h-48">
                    <Player
                      src={previewingGift.lottieAssetPath}
                      loop
                      autoplay
                      style={{ height: '192px', width: '192px' }}
                    />
                  </div>
                ) : (previewingGift.lottieAssetPath && (previewingGift.animationFormat === 'mp4' || previewingGift.lottieAssetPath.includes('.mp4'))) ? (
                  <video
                    src={previewingGift.lottieAssetPath}
                    controls
                    autoPlay
                    loop
                    className="w-full h-full object-contain"
                  />
                ) : previewingGift.imageUrl ? (
                  <img
                    src={previewingGift.imageUrl}
                    className="w-32 h-32 object-contain"
                    alt={previewingGift.name}
                  />
                ) : (
                  <div className="text-slate-600 text-xs">No previewable animation asset available</div>
                )}
              </div>

              <div className="grid grid-cols-2 gap-4 text-xs bg-white/[0.02] p-4 rounded-xl border border-white/5 mb-6">
                <div>
                  <span className="text-slate-500 uppercase block text-[10px]">Tier</span>
                  <span className="font-bold text-white">{previewingGift.tier || 'NORMAL'}</span>
                </div>
                <div>
                  <span className="text-slate-500 uppercase block text-[10px]">Format</span>
                  <span className="font-mono text-white">{previewingGift.animationFormat || 'json'}</span>
                </div>
                <div>
                  <span className="text-slate-500 uppercase block text-[10px]">Category</span>
                  <span className="font-bold text-white">{previewingGift.category || 'Normal'}</span>
                </div>
                <div>
                  <span className="text-slate-500 uppercase block text-[10px]">Store Status</span>
                  <span className={`font-bold ${previewingGift.isActive ? 'text-emerald-400' : 'text-slate-400'}`}>
                    {previewingGift.isActive ? 'Active (Live)' : 'Inactive (Draft)'}
                  </span>
                </div>
              </div>

              <div className="flex justify-end gap-3 border-t border-white/5 pt-4">
                <button
                  type="button"
                  onClick={() => setPreviewingGift(null)}
                  className="px-5 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-black uppercase text-slate-300 transition-all cursor-pointer"
                >
                  Close Preview
                </button>
                {previewingGift.id && (
                  <button
                    type="button"
                    onClick={async () => {
                      await toggleActive(previewingGift);
                      setPreviewingGift(prev => ({ ...prev, isActive: !prev.isActive }));
                    }}
                    className={`px-6 py-3 rounded-xl text-xs font-black uppercase tracking-wider transition-all cursor-pointer ${
                      previewingGift.isActive
                        ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30 hover:bg-amber-500/30'
                        : 'bg-emerald-500 text-black hover:bg-emerald-400'
                    }`}
                  >
                    {previewingGift.isActive ? 'Deactivate Gift' : 'Activate Gift'}
                  </button>
                )}
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

import { useState, useEffect } from 'react';
import { 
  doc, 
  setDoc, 
  onSnapshot,
  serverTimestamp
} from 'firebase/firestore';
import { 
  ref, 
  uploadBytesResumable, 
  getDownloadURL 
} from 'firebase/storage';
import { db, storage } from '../firebase';
import { 
  ShieldCheck, 
  Heart, 
  Upload, 
  Save, 
  Loader2, 
  CheckCircle, 
  Image as ImageIcon,
  Sparkles,
  Users,
  Award
} from 'lucide-react';
import { motion } from 'framer-motion';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const RoleFrameManagement = () => {
  const { user } = useAdmin();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingField, setUploadingField] = useState(null);
  const [uploadProgress, setUploadProgress] = useState(0);

  const [roleFrames, setRoleFrames] = useState({
    'super-admin': {
      name: 'Super Admin Frame',
      frameUrl: 'assets/Helo chat/Superadmin.svga',
      isEnabled: true,
      roleKey: 'SuperAdmin'
    },
    'admin': {
      name: 'Admin Frame',
      frameUrl: 'assets/images/super/admin.svga',
      isEnabled: true,
      roleKey: 'Admin'
    },
    'agency': {
      name: 'Agency Frame',
      frameUrl: 'assets/Helo chat/Agency.svga',
      isEnabled: true,
      roleKey: 'Agency'
    },
    'official': {
      name: 'Official ID Frame',
      frameUrl: 'assets/Helo chat/Official.svga',
      isEnabled: true,
      roleKey: 'Official'
    },
    'reseller': {
      name: 'Reseller Frame',
      frameUrl: 'assets/images/super/reseller.svga',
      isEnabled: true,
      roleKey: 'Reseller'
    },
    'cp': {
      name: 'Couple Pair (CP) Frame',
      frameUrl: 'assets/Helo chat/1.svga',
      isEnabled: true,
      roleKey: 'CP'
    }
  });

  useEffect(() => {
    const unsub = onSnapshot(doc(db, "system_configs", "admin_frames"), (snap) => {
      if (snap.exists() && snap.data().roleFrames) {
        setRoleFrames(prev => ({
          ...prev,
          ...snap.data().roleFrames
        }));
      }
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleUrlChange = (key, value) => {
    setRoleFrames(prev => ({
      ...prev,
      [key]: {
        ...prev[key],
        frameUrl: value
      }
    }));
  };

  const handleToggle = (key) => {
    setRoleFrames(prev => ({
      ...prev,
      [key]: {
        ...prev[key],
        isEnabled: !prev[key].isEnabled
      }
    }));
  };

  const handleFileUpload = async (e, key) => {
    const file = e.target.files[0];
    if (!file) return;

    setUploadingField(key);
    setUploadProgress(0);

    const storageRef = ref(storage, `role_frames/${key}_${Date.now()}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        setUploadProgress(progress);
      },
      (error) => {
        alert("Upload failed: " + error.message);
        setUploadingField(null);
      },
      () => {
        getDownloadURL(uploadTask.snapshot.ref).then((downloadURL) => {
          setRoleFrames(prev => ({
            ...prev,
            [key]: {
              ...prev[key],
              frameUrl: downloadURL
            }
          }));
          setUploadingField(null);
        });
      }
    );
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      // Simple map of URLs for quick flutter lookups
      const framesMap = {};
      Object.keys(roleFrames).forEach(k => {
        framesMap[k] = roleFrames[k].frameUrl;
      });

      await setDoc(doc(db, "system_configs", "admin_frames"), {
        frames: framesMap,
        roleFrames: roleFrames,
        updatedAt: serverTimestamp(),
        updatedBy: user?.email || 'admin'
      }, { merge: true });

      await logAdminAction(user, "ROLE_FRAMES_UPDATE", "admin_frames", { count: Object.keys(roleFrames).length });
      alert("Role & CP Frames configuration saved successfully.");
    } catch (err) {
      alert("Save Error: " + err.message);
    } finally {
      setSaving(false);
    }
  };

  const roleCards = [
    { key: 'super-admin', title: 'Super Admin Frame', icon: ShieldCheck, color: 'from-amber-500 to-orange-600', badge: 'SUPER ADMIN' },
    { key: 'admin', title: 'Admin Frame', icon: Award, color: 'from-[#6366F1] to-blue-600', badge: 'ADMIN' },
    { key: 'agency', title: 'Agency Frame', icon: Users, color: 'from-emerald-500 to-teal-600', badge: 'AGENCY OWNER' },
    { key: 'official', title: 'Official ID Frame', icon: Sparkles, color: 'from-cyan-500 to-blue-500', badge: 'OFFICIAL ID' },
    { key: 'reseller', title: 'Reseller Frame', icon: ShieldCheck, color: 'from-purple-500 to-indigo-600', badge: 'RESELLER' },
    { key: 'cp', title: 'Couple Pair (CP) Frame', icon: Heart, color: 'from-pink-500 to-rose-600', badge: 'ACTIVE CP' },
  ];

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-pink-500/20 rounded-2xl border border-pink-500/30">
              <ShieldCheck className="text-pink-400" size={28} />
            </div>
            Role & CP Frame System
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Real-time Exclusive Privilege & Role-Based Frame Management
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={saving || loading}
          className="flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 text-white rounded-2xl font-black uppercase text-xs tracking-widest shadow-xl shadow-pink-500/20 transition-all disabled:opacity-50"
        >
          {saving ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
          {saving ? 'Saving...' : 'Save Frame System'}
        </button>
      </div>

      {loading ? (
        <div className="py-35 text-center text-slate-600 font-black tracking-widest uppercase animate-pulse">
          Loading Role Frame Configuration...
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {roleCards.map(({ key, title, icon: Icon, color, badge }) => {
            const item = roleFrames[key] || { frameUrl: '', isEnabled: true };
            return (
              <motion.div
                key={key}
                whileHover={{ y: -4 }}
                className="bg-[#18181B]/80 border border-white/10 rounded-3xl p-6 shadow-2xl relative overflow-hidden flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between border-b border-white/5 pb-4 mb-6">
                    <div className="flex items-center gap-3">
                      <div className={`p-2.5 rounded-xl bg-gradient-to-br ${color} text-white`}>
                        <Icon size={20} />
                      </div>
                      <div>
                        <h3 className="font-black text-white text-base tracking-tight">{title}</h3>
                        <span className="text-[9px] font-black text-slate-400 tracking-widest uppercase">
                          {badge}
                        </span>
                      </div>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        checked={item.isEnabled !== false}
                        onChange={() => handleToggle(key)}
                        className="sr-only peer"
                      />
                      <div className="w-11 h-6 bg-slate-800 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-pink-500"></div>
                    </label>
                  </div>

                  {/* Frame Preview Container */}
                  <div className="relative h-40 w-full bg-slate-950/80 rounded-2xl border border-white/5 flex items-center justify-center overflow-hidden mb-6 group">
                    <div className="w-16 h-16 rounded-full bg-slate-800 border-2 border-white/20 flex items-center justify-center overflow-hidden relative">
                      <ImageIcon className="text-slate-600" size={24} />
                      {item.frameUrl && (
                        <div className="absolute inset-0 flex items-center justify-center">
                          {item.frameUrl.endsWith('.svga') ? (
                            <div className="text-[8px] font-black text-pink-400 uppercase bg-black/60 px-2 py-1 rounded">
                              SVGA ANIMATED
                            </div>
                          ) : (
                            <img
                              src={item.frameUrl}
                              alt="Frame preview"
                              className="w-full h-full object-contain scale-125"
                            />
                          )}
                        </div>
                      )}
                    </div>

                    <div className="absolute bottom-2 left-2 right-2 text-center text-[9px] font-black text-slate-500 uppercase tracking-widest truncate bg-slate-900/80 py-1 px-2 rounded-lg border border-white/5">
                      {item.frameUrl || 'No Frame Asset Set'}
                    </div>
                  </div>

                  {/* URL Input */}
                  <div className="space-y-3 mb-4">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                      Frame Asset URL / Path
                    </label>
                    <input
                      type="text"
                      placeholder="assets/... or https://..."
                      value={item.frameUrl || ''}
                      onChange={(e) => handleUrlChange(key, e.target.value)}
                      className="w-full h-11 bg-slate-950/60 border border-white/10 rounded-xl px-4 text-xs font-mono text-white focus:outline-none focus:border-pink-500 transition-colors"
                    />
                  </div>
                </div>

                {/* Upload Button */}
                <div className="relative mt-2">
                  <input
                    type="file"
                    accept="image/*,.svga"
                    onChange={(e) => handleFileUpload(e, key)}
                    className="absolute inset-0 opacity-0 w-full h-full cursor-pointer z-10"
                    disabled={uploadingField === key}
                  />
                  <div className="w-full py-3 bg-white/5 hover:bg-white/10 text-slate-300 rounded-xl font-bold uppercase text-[10px] tracking-widest border border-white/10 flex items-center justify-center gap-2 transition-all">
                    {uploadingField === key ? (
                      <>
                        <Loader2 className="animate-spin text-pink-400" size={14} />
                        <span>Uploading ({Math.round(uploadProgress)}%)</span>
                      </>
                    ) : (
                      <>
                        <Upload size={14} className="text-pink-400" />
                        <span>Upload New PNG / SVGA</span>
                      </>
                    )}
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
};

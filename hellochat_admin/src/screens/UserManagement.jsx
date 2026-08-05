import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  where, 
  doc, 
  limit, 
  orderBy,
  writeBatch, 
  serverTimestamp, 
  deleteDoc,
  getDoc,
  updateDoc
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { 
  Search, 
  Ban, 
  CheckCircle, 
  Coins, 
  X,
  Plus,
  Minus,
  Diamond,
  Zap,
  Trash2,
  UserPlus,
  ShieldCheck,
  RefreshCw,
  Building2,
  Store,
  Star
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const BalanceAdjustmentModal = ({ user, onClose, onUpdate }) => {
  const [amount, setAmount] = useState('100');
  const [currency, setCurrency] = useState('Diamonds');
  const [reason, setReason] = useState('Admin Adjustment');
  const [isProcessing, setIsProcessing] = useState(false);

  const handleAdjust = async (isAdding) => {
    setIsProcessing(true);
    try {
      const finalAmount = isAdding ? parseInt(amount) : -parseInt(amount);
      const functionName = currency === 'Diamonds' ? 'adminAdjustBalance' : 'adminAdjustBeans';
      
      const balanceAdjust = httpsCallable(functions, functionName);
      await balanceAdjust({ 
        targetUid: user.id || user.uid, 
        amount: finalAmount, 
        reason 
      });
      
      alert(`Successfully ${isAdding ? 'added' : 'subtracted'} ${amount} ${currency}`);
      onUpdate();
      onClose();
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#18181B] border border-white/10 w-full max-w-md rounded-[32px] p-8 shadow-2xl">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-[#B4E0A2]/20 text-[#B4E0A2] rounded-xl">
              <Coins size={24} />
            </div>
            <div>
              <h2 className="text-xl font-black text-white uppercase tracking-widest">Adjust Ledger</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">
                Ref: {(user.id || user.uid).slice(0, 15)}...
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4">
            <button 
              onClick={() => setCurrency('Diamonds')}
              className={`p-4 rounded-2xl border transition-all ${currency === 'Diamonds' ? 'bg-[#B4E0A2]/20 border-[#B4E0A2]/50 text-[#B4E0A2]' : 'bg-white/5 border-white/5 text-slate-500'}`}
            >
              <div className="flex flex-col items-center gap-2">
                <Diamond size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest">Diamonds</span>
              </div>
            </button>
            <button 
              onClick={() => setCurrency('Beans')}
              className={`p-4 rounded-2xl border transition-all ${currency === 'Beans' ? 'bg-amber-500/20 border-amber-500/50 text-amber-500' : 'bg-white/5 border-white/5 text-slate-500'}`}
            >
              <div className="flex flex-col items-center gap-2">
                <div className="w-6 h-6 border-2 border-amber-500/50 rounded-full flex items-center justify-center">
                   <div className="w-2 h-2 bg-amber-500 rounded-full"></div>
                </div>
                <span className="text-[10px] font-black uppercase tracking-widest">Beans</span>
              </div>
            </button>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Delta Value</label>
            <input 
              type="number" 
              className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-2xl text-center focus:border-[#B4E0A2] outline-none"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-2 gap-4 mt-8">
            <button 
              disabled={isProcessing}
              onClick={() => handleAdjust(false)}
              className="flex items-center justify-center gap-2 p-5 bg-red-500/10 text-red-500 font-black text-xs uppercase tracking-widest rounded-[32px] hover:bg-red-500 hover:text-white transition-all disabled:opacity-50"
            >
              <Minus size={16} /> Subtract
            </button>
            <button 
              disabled={isProcessing}
              onClick={() => handleAdjust(true)}
              className="flex items-center justify-center gap-2 p-5 bg-[#B4E0A2] text-black font-black text-xs uppercase tracking-widest rounded-[32px] hover:scale-[1.02] active:scale-95 transition-all disabled:opacity-50"
            >
              <Plus size={16} /> Reward
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const SVIPManagementModal = ({ user, onClose, onUpdate }) => {
  const [level, setLevel] = useState(user.svipLevel || 0);
  const [points, setPoints] = useState(user.svipPoints || 0);
  const [isProcessing, setIsProcessing] = useState(false);

  const handleUpdate = async () => {
    setIsProcessing(true);
    try {
      const userRef = doc(db, "users", user.id || user.uid);
      await setDoc(userRef, {
        svipLevel: parseInt(level),
        svipPoints: parseInt(points),
        svipUpdatedAt: serverTimestamp()
      }, { merge: true });
      
      alert(`Successfully updated SVIP status for ${user.displayName}`);
      onUpdate();
      onClose();
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-md rounded-3xl p-8 shadow-2xl">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-rose-500/20 text-rose-400 rounded-xl">
              <Star size={24} />
            </div>
            <div>
              <h2 className="text-xl font-black text-white uppercase tracking-widest">SVIP Privilege</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">
                Identity: {(user.id || user.uid).slice(0, 15)}...
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        <div className="space-y-6">
          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Tier Level (0-7)</label>
            <select 
              className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black outline-none focus:border-rose-500"
              value={level}
              onChange={(e) => setLevel(e.target.value)}
            >
              <option value={0}>None (Civilian)</option>
              {[1, 2, 3, 4, 5, 6, 7].map(l => (
                <option key={l} value={l}>SVIP {l}</option>
              ))}
            </select>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Cumulative Points</label>
            <input 
              type="number" 
              className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-xl focus:border-rose-500 outline-none"
              value={points}
              onChange={(e) => setPoints(e.target.value)}
              placeholder="Total Spend/Recharge points"
            />
          </div>

          <button 
            disabled={isProcessing}
            onClick={handleUpdate}
            className="w-full flex items-center justify-center gap-2 p-5 bg-rose-600 text-white font-black text-xs uppercase tracking-widest rounded-2xl hover:bg-rose-700 transition-all disabled:opacity-50 mt-4"
          >
            {isProcessing ? 'Synchronizing...' : 'Grant SVIP Status'}
          </button>
        </div>
      </div>
    </div>
  );
};
const UserEditModal = ({ user, onClose, onUpdate }) => {
  const [formData, setFormData] = useState({
    displayName: user.displayName || '',
    username: user.username || '',
    diamondBalance: user.diamondBalance || 0,
    beansBalance: user.beansBalance || 0,
    walletBalance: user.walletBalance || 0.0,
    level: user.level || 1,
    vipTier: user.vipTier || 'none',
    nobleTier: user.nobleTier || 'none',
    isBanned: user.isBanned || false,
    email: user.email || '',
    phoneNumber: user.phoneNumber || '',
    country: user.country || '',
    gender: user.gender || 'male',
    isReseller: user.isReseller || false,
    isAgencyOwner: user.isAgencyOwner || false,
    isVerified: user.isVerified || false,
    verificationStatus: user.verificationStatus || 'none',
    idPhotoUrl: user.idPhotoUrl || '',
    referralCode: user.referralCode || '',
    referredBy: user.referredBy || '',
    totalReferralEarnings: user.totalReferralEarnings || 0.0,
    agencyId: user.agencyId || ''
  });
  
  const [tagsInput, setTagsInput] = useState((user.tags || []).join(', '));
  const [isProcessing, setIsProcessing] = useState(false);

  const handleResellerToggle = (checked) => {
    let updatedTags = tagsInput.split(',').map(t => t.trim()).filter(t => t.length > 0);
    if (checked) {
      if (!updatedTags.includes('Reseller')) updatedTags.push('Reseller');
    } else {
      updatedTags = updatedTags.filter(t => t !== 'Reseller');
    }
    setTagsInput(updatedTags.join(', '));
    setFormData({
      ...formData,
      isReseller: checked
    });
  };

  const handleAgencyToggle = (checked) => {
    let updatedTags = tagsInput.split(',').map(t => t.trim()).filter(t => t.length > 0);
    if (checked) {
      if (!updatedTags.includes('Agency')) updatedTags.push('Agency');
    } else {
      updatedTags = updatedTags.filter(t => t !== 'Agency');
    }
    setTagsInput(updatedTags.join(', '));
    setFormData({
      ...formData,
      isAgencyOwner: checked
    });
  };

  const handleVerificationStatusChange = (status) => {
    setFormData({
      ...formData,
      verificationStatus: status,
      isVerified: status === 'verified'
    });
  };

  const handleIsVerifiedToggle = (checked) => {
    setFormData({
      ...formData,
      isVerified: checked,
      verificationStatus: checked ? 'verified' : 'none'
    });
  };

  const handleUpdate = async (e) => {
    e.preventDefault();
    setIsProcessing(true);
    try {
      const userRef = doc(db, "users", user.id || user.uid);
      const finalTags = tagsInput
        .split(',')
        .map(t => t.trim())
        .filter(t => t.length > 0);
        
      await updateDoc(userRef, {
        ...formData,
        tags: finalTags,
        updatedAt: serverTimestamp()
      });
      
      alert(`Successfully updated profile for ${formData.displayName}`);
      onUpdate();
      onClose();
    } catch (err) {
      alert(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-4xl rounded-[40px] p-10 shadow-2xl max-h-[90vh] overflow-y-auto animate-fade-in">
        <div className="flex justify-between items-center mb-8">
          <div className="flex items-center gap-4">
            <div className="p-4 bg-indigo-500/20 text-indigo-400 rounded-2xl border border-indigo-500/10">
              <RefreshCw size={28} />
            </div>
            <div>
              <h2 className="text-2xl font-black text-white uppercase tracking-widest">Master Profile Edit</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">
                Identity: {(user.id || user.uid)}
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-white/5 rounded-full transition-colors">
            <X size={24} className="text-slate-500" />
          </button>
        </div>

        <form onSubmit={handleUpdate} className="space-y-8 text-left">
          
          {/* SECTION 1: Core Profile */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">Core Profile</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Display Name</label>
                <input 
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.displayName}
                  onChange={(e) => setFormData({...formData, displayName: e.target.value})}
                  required
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Username (@)</label>
                <input 
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.username}
                  onChange={(e) => setFormData({...formData, username: e.target.value})}
                  required
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Prestige Level</label>
                <input 
                  type="number"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-indigo-400 font-black"
                  value={formData.level}
                  onChange={(e) => setFormData({...formData, level: parseInt(e.target.value) || 1})}
                />
              </div>
            </div>
          </div>

          {/* SECTION 2: Contact & Identity */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">Contact & Identity</h3>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Email Address</label>
                <input 
                  type="email"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.email}
                  onChange={(e) => setFormData({...formData, email: e.target.value})}
                  placeholder="name@domain.com"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Phone Number</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.phoneNumber}
                  onChange={(e) => setFormData({...formData, phoneNumber: e.target.value})}
                  placeholder="+123456789"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Country Code</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.country}
                  onChange={(e) => setFormData({...formData, country: e.target.value.toUpperCase()})}
                  placeholder="US"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Gender</label>
                <select 
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black outline-none"
                  value={formData.gender}
                  onChange={(e) => setFormData({...formData, gender: e.target.value})}
                >
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                  <option value="other">Other</option>
                </select>
              </div>
            </div>
          </div>

          {/* SECTION 3: Economic Ledgers */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">Economic Ledgers</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Diamond Balance</label>
                <input 
                  type="number"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-emerald-400 font-black"
                  value={formData.diamondBalance}
                  onChange={(e) => setFormData({...formData, diamondBalance: parseInt(e.target.value) || 0})}
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Beans Balance</label>
                <input 
                  type="number"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-amber-500 font-black"
                  value={formData.beansBalance}
                  onChange={(e) => setFormData({...formData, beansBalance: parseInt(e.target.value) || 0})}
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Wallet Balance ($ USD)</label>
                <input 
                  type="number"
                  step="0.01"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-emerald-400 font-black"
                  value={formData.walletBalance}
                  onChange={(e) => setFormData({...formData, walletBalance: parseFloat(e.target.value) || 0.0})}
                />
              </div>
            </div>
          </div>

          {/* SECTION 4: Memberships & Affiliations */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">Memberships & Affiliations</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">VIP Membership</label>
                <select 
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black outline-none"
                  value={formData.vipTier}
                  onChange={(e) => setFormData({...formData, vipTier: e.target.value})}
                >
                  <option value="none">NONE</option>
                  {['VIP 1', 'VIP 2', 'VIP 3', 'VIP 4', 'VIP 5', 'VIP 6', 'VIP 7'].map(v => <option key={v} value={v}>{v}</option>)}
                </select>
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Noble Title</label>
                <select 
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black outline-none"
                  value={formData.nobleTier}
                  onChange={(e) => setFormData({...formData, nobleTier: e.target.value})}
                >
                  <option value="none">NONE</option>
                  {['Knight', 'Viscount', 'Earl', 'Marquis', 'Duke', 'King', 'Emperor'].map(n => <option key={n} value={n}>{n}</option>)}
                </select>
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Agency ID</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.agencyId}
                  onChange={(e) => setFormData({...formData, agencyId: e.target.value})}
                  placeholder="Enter Agency ID"
                />
              </div>
            </div>
          </div>

          {/* SECTION 5: KYC Verification */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">KYC Identity Verification</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Verification Status</label>
                <select 
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black outline-none"
                  value={formData.verificationStatus}
                  onChange={(e) => handleVerificationStatusChange(e.target.value)}
                >
                  <option value="none">None / Unsubmitted</option>
                  <option value="pending">Pending Review</option>
                  <option value="verified">Verified / Approved</option>
                  <option value="rejected">Rejected / Denied</option>
                </select>
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">ID Document Photo URL</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.idPhotoUrl}
                  onChange={(e) => setFormData({...formData, idPhotoUrl: e.target.value})}
                  placeholder="https://bucket/photo.jpg"
                />
              </div>
              <div className="flex items-center gap-4 px-6 bg-[#B4E0A2]/5 rounded-2xl border border-[#B4E0A2]/10 h-[60px] self-end mb-1">
                 <input 
                    type="checkbox"
                    id="edit-isVerified"
                    className="w-5 h-5 rounded bg-black border-white/10 text-indigo-500 focus:ring-0 cursor-pointer"
                    checked={formData.isVerified}
                    onChange={(e) => handleIsVerifiedToggle(e.target.checked)}
                 />
                 <label htmlFor="edit-isVerified" className="text-xs font-black text-[#B4E0A2] uppercase cursor-pointer">Account Verified</label>
              </div>
            </div>
          </div>

          {/* SECTION 6: Referral Program */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">Referral & Rewards</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Personal Referral Code</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.referralCode}
                  onChange={(e) => setFormData({...formData, referralCode: e.target.value.toUpperCase()})}
                  placeholder="REFCODE"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Referred By Code</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={formData.referredBy}
                  onChange={(e) => setFormData({...formData, referredBy: e.target.value})}
                  placeholder="SPONSOR"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Referral Earnings ($ USD)</label>
                <input 
                  type="number"
                  step="0.01"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-emerald-400 font-black"
                  value={formData.totalReferralEarnings}
                  onChange={(e) => setFormData({...formData, totalReferralEarnings: parseFloat(e.target.value) || 0.0})}
                />
              </div>
            </div>
          </div>

          {/* SECTION 7: System Access & Tags */}
          <div>
            <h3 className="text-xs font-black text-indigo-400 uppercase tracking-wider mb-4 pb-2 border-b border-white/5">System Privileges & Security</h3>
            <div className="space-y-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Administrative & Role Tags (comma separated)</label>
                <input 
                  type="text"
                  className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black"
                  value={tagsInput}
                  onChange={(e) => setTagsInput(e.target.value)}
                  placeholder="e.g. Admin, SuperAdmin, Reseller, Agency"
                />
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="flex items-center gap-4 px-6 bg-[#B4E0A2]/5 rounded-2xl border border-[#B4E0A2]/10 h-[60px] cursor-pointer">
                   <input 
                      type="checkbox"
                      id="edit-isReseller"
                      className="w-5 h-5 rounded bg-black border-white/10 text-[#B4E0A2] focus:ring-0 cursor-pointer"
                      checked={formData.isReseller}
                      onChange={(e) => handleResellerToggle(e.target.checked)}
                   />
                   <label htmlFor="edit-isReseller" className="text-xs font-black text-slate-300 uppercase cursor-pointer">Appoint Reseller</label>
                </div>
                <div className="flex items-center gap-4 px-6 bg-indigo-500/5 rounded-2xl border border-indigo-500/10 h-[60px] cursor-pointer">
                   <input 
                      type="checkbox"
                      id="edit-isAgencyOwner"
                      className="w-5 h-5 rounded bg-black border-white/10 text-indigo-500 focus:ring-0 cursor-pointer"
                      checked={formData.isAgencyOwner}
                      onChange={(e) => handleAgencyToggle(e.target.checked)}
                   />
                   <label htmlFor="edit-isAgencyOwner" className="text-xs font-black text-slate-300 uppercase cursor-pointer">Appoint Agency Owner</label>
                </div>
                <div className="flex items-center gap-4 px-6 bg-red-500/5 rounded-2xl border border-red-500/10 h-[60px] cursor-pointer">
                   <input 
                      type="checkbox"
                      id="edit-isBanned"
                      className="w-5 h-5 rounded bg-black border-white/10 text-red-500 focus:ring-0 cursor-pointer"
                      checked={formData.isBanned}
                      onChange={(e) => setFormData({...formData, isBanned: e.target.checked})}
                   />
                   <label htmlFor="edit-isBanned" className="text-xs font-black text-red-500 uppercase cursor-pointer">Restrict Account (Ban)</label>
                </div>
              </div>
            </div>
          </div>

          <button 
            disabled={isProcessing}
            className="w-full flex items-center justify-center gap-2 p-6 bg-indigo-600 text-white font-black text-sm uppercase tracking-widest rounded-2xl hover:bg-indigo-700 transition-all disabled:opacity-50 mt-8"
          >
            {isProcessing ? 'Synchronizing Universe...' : 'Apply Master Updates'}
          </button>
        </form>
      </div>
    </div>
  );
};



export const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [svipUser, setSvipUser] = useState(null);
  const [editUser, setEditUser] = useState(null);
  const [isSeeding, setIsSeeding] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      // Fetch more users and order by newest first
      const q = query(
        collection(db, "users"), 
        orderBy("createdAt", "desc"), 
        limit(200)
      );
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
    } catch (err) {
      console.error("Fetching with order failed, falling back:", err);
      // Fallback query in case the index is still building
      const q = query(collection(db, "users"), limit(200));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
    } finally {
      setLoading(false);
    }
  };

  const handleCleanupEcosystem = async (user) => {
    const targetUid = user.id || user.uid;
    if (!window.confirm(`WIPE TEST DATA? This will remove all synth users associated with ${user.displayName}.`)) return;
    
    setIsSeeding(true);
    try {
      const batch = writeBatch(db);
      
      // Cleanup following
      const followingSnap = await getDocs(collection(db, "users", targetUid, "following"));
      for (const d of followingSnap.docs) {
        if (d.id.startsWith('test_')) {
          batch.delete(d.ref); // Remove link
          batch.delete(doc(db, "users", d.id)); // Remove synthetic user
          batch.delete(doc(db, "users", d.id, "followers", targetUid)); // Remove reverse link
        }
      }

      // Cleanup followers
      const followersSnap = await getDocs(collection(db, "users", targetUid, "followers"));
      for (const d of followersSnap.docs) {
        if (d.id.startsWith('test_')) {
          batch.delete(d.ref);
          batch.delete(doc(db, "users", d.id, "following", targetUid));
        }
      }

      await batch.commit();
      alert("Test data purged successfully.");
      fetchUsers();
    } catch (err) {
      alert("Cleanup Error: " + err.message);
    } finally {
      setIsSeeding(false);
    }
  };

  const handleFreshSeed = async (user) => {
    const targetUid = user.id || user.uid;
    setIsSeeding(true);
    try {
      const batch = writeBatch(db);
      const names = ["Arena Pro", "Battle King", "PK Ninja", "Stream Master", "Gamer God"];
      
      for (let i = 0; i < 5; i++) {
        const fakeUid = `test_synthetic_${i}_${Date.now()}`;
        const fakeUsername = `pro_player_${i}_${Math.floor(Math.random() * 999)}`;
        const fakeUserRef = doc(db, "users", fakeUid);
        
        batch.set(fakeUserRef, {
          uid: fakeUid,
          username: fakeUsername,
          username_lowercase: fakeUsername,
          displayName: names[i],
          bio: "100% Guaranteed PK Valid test profile.",
          profilePhotoUrl: `https://api.dicebear.com/7.x/avataaars/png?seed=${fakeUsername}`,
          gender: i % 2 === 0 ? 'male' : 'female',
          country: 'US',
          diamondBalance: 1000,
          beansBalance: 50,
          xp: 2000,
          benchXP: 1000,
          princeXP: 500,
          level: 15,
          followerCount: 1, 
          followingCount: 1, 
          friendsCount: 1,
          createdAt: serverTimestamp(),
          lastActive: serverTimestamp(),
          status: 'online',
          tags: ["TestUser", "Verified"],
          badges: ["pk_legend"],
          profileFrame: '',
          entryAnimation: '',
          vipTier: 'none',
          isBanned: false,
          blockedUids: [],
          referralCode: fakeUsername.toUpperCase(),
          totalReferralEarnings: 0,
          isAgencyOwner: false,
          lastVipClaim: '',
          cpLevel: 0,
          cpPoints: 0
        });

        // 100% Mutual Following for PK
        batch.set(doc(db, "users", targetUid, "following", fakeUid), { followedAt: serverTimestamp() });
        batch.set(doc(db, "users", fakeUid, "followers", targetUid), { followedAt: serverTimestamp() });
        batch.set(doc(db, "users", targetUid, "followers", fakeUid), { followedAt: serverTimestamp() });
        batch.set(doc(db, "users", fakeUid, "following", targetUid), { followedAt: serverTimestamp() });
      }

      await batch.commit();
      alert("Fresh Seeding Successful! 5 Pro-level opponents added.");
      fetchUsers();
    } catch (err) {
      alert("Seeding Error: " + err.message);
    } finally {
      setIsSeeding(false);
    }
  };

    const handleFullSync = async (user) => {
        if (!window.confirm("Perform Full Ecosystem Sync? This will wipe old test data and seed 5 fresh pro users.")) return;
        
        setIsSeeding(true);
        try {
            const targetUid = user.id || user.uid;
            const batch = writeBatch(db);

            // 1. Cleanup old ones (test_*)
            const followingSnap = await getDocs(collection(db, "users", targetUid, "following"));
            for (const d of followingSnap.docs) {
                if (d.id.startsWith('test_') || d.id.startsWith('fake_')) {
                    batch.delete(d.ref);
                    batch.delete(doc(db, "users", d.id));
                    batch.delete(doc(db, "users", d.id, "followers", targetUid));
                }
            }
            const followersSnap = await getDocs(collection(db, "users", targetUid, "followers"));
            for (const d of followersSnap.docs) {
                if (d.id.startsWith('test_') || d.id.startsWith('fake_')) {
                    batch.delete(d.ref);
                    batch.delete(doc(db, "users", d.id, "following", targetUid));
                }
            }

            // 2. Seed 5 New Pro Users
            const names = ["Shadow Assassin", "Blaze Warrior", "Vortex Mage", "Phantom Rogue", "Aether Knight"];
            for (let i = 0; i < 5; i++) {
                const fakeUid = `test_pro_v2_${i}_${Date.now()}`;
                const fakeUsername = `master_pk_${i}_${Math.floor(Math.random() * 999)}`;
                const fakeUserRef = doc(db, "users", fakeUid);
                
                batch.set(fakeUserRef, {
                    uid: fakeUid,
                    username: fakeUsername,
                    username_lowercase: fakeUsername,
                    displayName: names[i],
                    bio: "Ultimate PK Opponent v2.",
                    profilePhotoUrl: `https://api.dicebear.com/7.x/avataaars/png?seed=${fakeUsername}`,
                    gender: i % 2 === 0 ? 'male' : 'female',
                    country: 'PK',
                    diamondBalance: 9999,
                    beansBalance: 500,
                    xp: 5000,
                    benchXP: 2000,
                    princeXP: 1000,
                    level: 50,
                    followerCount: 200, 
                    followingCount: 150, 
                    friendsCount: 50,
                    createdAt: serverTimestamp(),
                    lastActive: serverTimestamp(),
                    status: 'online',
                    tags: ["TestUser", "Pro"],
                    badges: ["pk_elite_v2"],
                    profileFrame: '',
                    entryAnimation: '',
                    vipTier: 'none',
                    isBanned: false,
                    blockedUids: [],
                    referralCode: fakeUsername.toUpperCase(),
                    totalReferralEarnings: 0,
                    isAgencyOwner: false,
                    lastVipClaim: '',
                    cpLevel: 0,
                    cpPoints: 0
                });

                batch.set(doc(db, "users", targetUid, "following", fakeUid), { followedAt: serverTimestamp() });
                batch.set(doc(db, "users", fakeUid, "followers", targetUid), { followedAt: serverTimestamp() });
                batch.set(doc(db, "users", targetUid, "followers", fakeUid), { followedAt: serverTimestamp() });
                batch.set(doc(db, "users", fakeUid, "following", targetUid), { followedAt: serverTimestamp() });
            }

            await batch.commit();
            alert("Full Sync Complete! Your ecosystem is now fresh and ready for battle.");
            fetchUsers();
        } catch (err) {
            alert("Sync Error: " + err.message);
        } finally {
            setIsSeeding(false);
        }
    };

    const handleToggleAgencyStatus = async (user) => {
        const targetUid = user.id || user.uid;
        const isCurrentlyOwner = user.isAgencyOwner === true;
        const action = isCurrentlyOwner ? 'Revoke' : 'Appoint';
        
        if (!window.confirm(`${action} Agency Owner status for ${user.displayName}?`)) return;
        
        setIsSeeding(true);
        try {
            const userRef = doc(db, "users", targetUid);
            const userSnap = await getDoc(userRef);
            let tags = userSnap.data()?.tags || [];
            
            if (isCurrentlyOwner) {
                tags = tags.filter(t => t !== "Agency");
                await updateDoc(userRef, {
                    isAgencyOwner: false,
                    tags: tags
                });
                alert(`${user.displayName} is no longer an Agency Owner.`);
            } else {
                tags = Array.from(new Set([...tags, "Agency"]));
                await updateDoc(userRef, {
                    isAgencyOwner: true,
                    tags: tags
                });
                alert(`${user.displayName} is now a verified Agency Owner.`);
            }
            fetchUsers();
        } catch (err) {
            alert("Error: " + err.message);
        } finally {
            setIsSeeding(false);
        }
    };

    const handleToggleResellerStatus = async (user) => {
        const targetUid = user.id || user.uid;
        const isCurrentlyReseller = user.isReseller === true;
        const action = isCurrentlyReseller ? 'Revoke' : 'Appoint';
        
        if (!window.confirm(`${action} Reseller status for ${user.displayName}?`)) return;
        
        setIsSeeding(true);
        try {
            const setReseller = httpsCallable(functions, 'adminSetResellerStatus');
            await setReseller({ targetUid, isReseller: !isCurrentlyReseller });
            alert(`${user.displayName} status updated successfully.`);
            fetchUsers();
        } catch (err) {
            alert("Error: " + err.message);
        } finally {
            setIsSeeding(false);
        }
    };

  const handleSearch = async () => {
    const term = searchTerm.trim();
    if (!term) {
      fetchUsers();
      return;
    }

    setLoading(true);
    try {
      // 1. Try exact UID match
      const userRef = doc(db, "users", term);
      const userSnap = await getDoc(userRef);

      if (userSnap.exists()) {
        setUsers([{ id: userSnap.id, ...userSnap.data() }]);
      } else {
        // 2. Try numeric Hello ID match
        const numericId = parseInt(term);
        if (!isNaN(numericId)) {
          const qId = query(collection(db, "users"), where("helloId", "==", numericId), limit(1));
          const snapId = await getDocs(qId);
          if (!snapId.empty) {
            setUsers(snapId.docs.map(d => ({ id: d.id, ...d.data() })));
            return;
          }
        }

        // 3. Try username match (Exact or Lowercase)
        const qUsername = query(
          collection(db, "users"), 
          where("username_lowercase", "==", term.toLowerCase()),
          limit(1)
        );
        const snapUsername = await getDocs(qUsername);
        
        if (!snapUsername.empty) {
          setUsers(snapUsername.docs.map(d => ({ id: d.id, ...d.data() })));
        } else {
          // 4. Try displayName match (StartWith pattern)
          const qName = query(
            collection(db, "users"),
            orderBy("displayName"),
            where("displayName", ">=", term),
            where("displayName", "<=", term + '\uf8ff'),
            limit(20)
          );
          const snapName = await getDocs(qName);
          setUsers(snapName.docs.map(d => ({ id: d.id, ...d.data() })));
        }
      }
    } catch (err) {
      console.error("Search failed:", err);
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter(u => 
    u.displayName?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    u.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    (u.uid || u.id)?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-8 space-y-8 min-h-screen bg-black text-slate-200">
      {selectedUser && (
        <BalanceAdjustmentModal 
          user={selectedUser} 
          onClose={() => setSelectedUser(null)} 
          onUpdate={fetchUsers} 
        />
      )}

      {svipUser && (
        <SVIPManagementModal 
          user={svipUser} 
          onClose={() => setSvipUser(null)} 
          onUpdate={fetchUsers} 
        />
      )}

      {editUser && (
        <UserEditModal 
          user={editUser} 
          onClose={() => setEditUser(null)} 
          onUpdate={fetchUsers} 
        />
      )}

      {isSeeding && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-xl">
           <div className="flex flex-col items-center gap-6">
              <div className="relative">
                <Zap size={64} className="text-indigo-400 animate-pulse" />
                <div className="absolute inset-0 bg-indigo-500/20 blur-3xl animate-pulse"></div>
              </div>
              <p className="text-xs font-black text-indigo-300 uppercase tracking-[0.4em] animate-pulse">Processing Ecosystem Assets...</p>
           </div>
        </div>
      )}

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 pb-8 border-b border-white/5">
        <div className="flex items-center gap-6">
          <div>
            <h1 className="text-4xl font-black text-white tracking-widest uppercase">Seed Control</h1>
            <p className="text-slate-500 font-bold text-xs uppercase tracking-widest mt-2">Manage synthetic identities & accounts</p>
          </div>
          <button 
            onClick={fetchUsers}
            className="p-3 bg-white/5 hover:bg-white/10 rounded-2xl border border-white/5 text-slate-400 hover:text-[#B4E0A2] transition-all group"
            title="Refresh User List"
          >
            <RefreshCw size={20} className={loading ? 'animate-spin' : 'group-active:rotate-180 transition-transform duration-500'} />
          </button>
        </div>
        
        <div className="relative group w-80">
          <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
             <Search className="text-slate-600 group-focus-within:text-[#B4E0A2] transition-colors" size={18} />
          </div>
          <input 
            type="text" 
            placeholder="Search UID or Username (Enter to query)..."
            className="glass-input w-full pl-12 !py-3.5 focus:ring-1 ring-[#B4E0A2]"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <AnimatePresence>
          {filteredUsers.map((user) => (
            <motion.div 
              key={user.uid || user.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="bg-[#09090B] border border-white/5 rounded-3xl p-6 hover:bg-white/[0.02] transition-all group"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-5">
                  <div className="relative">
                    <img 
                      src={user.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${user.uid}`} 
                      className="w-16 h-16 rounded-2xl object-cover ring-2 ring-white/5" 
                    />
                    <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-green-500 border-4 border-[#09090B] rounded-full"></div>
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                       <h3 className="font-black text-white tracking-tight flex items-center gap-2">
                          {user.displayName}
                          {user.tags?.includes('Admin') && <ShieldCheck size={14} className="text-indigo-400" />}
                          {user.tags?.includes('SuperAdmin') && <ShieldCheck size={14} className="text-rose-400" />}
                       </h3>
                       {user.isAgencyOwner && (
                         <span className="bg-amber-500/20 text-amber-500 text-[8px] font-black uppercase px-2 py-0.5 rounded-md border border-amber-500/20">Agency</span>
                       )}
                       {user.isReseller && (
                         <span className="bg-emerald-500/20 text-emerald-500 text-[8px] font-black uppercase px-2 py-0.5 rounded-md border border-emerald-500/20">Reseller</span>
                       )}
                    </div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <p className="text-[10px] font-black uppercase text-slate-500 tracking-wider">@{user.username || 'Synthetic Identity'}</p>
                      <span className="text-[10px] text-slate-700 font-bold">•</span>
                      <span className="text-[10px] text-indigo-400 font-black tracking-tighter">ID: {user.helloId || 'N/A'}</span>
                    </div>
                    <div className="flex gap-4 mt-2">
                       <div className="flex items-center gap-1.5 pt-1">
                          <Diamond size={10} className="text-indigo-400" />
                          <span className="text-[10px] font-black text-slate-300">{user.diamondBalance || 0}</span>
                       </div>
                       <div className="flex items-center gap-1.5 pt-1" title="Total Diamonds Spent (SVIP Points)">
                          <Zap size={10} className="text-emerald-400" />
                          <span className="text-[10px] font-black text-emerald-400">{user.svipPoints || 0}</span>
                       </div>
                       <div className="flex items-center gap-1.5 pt-1" title="Wallet Balance">
                          <Coins size={10} className="text-emerald-400" />
                          <span className="text-[10px] font-black text-emerald-400">${(user.walletBalance || 0).toFixed(2)}</span>
                       </div>
                       {user.agencyId && (
                         <div className="flex items-center gap-1.5 pt-1">
                            <Building2 size={10} className="text-amber-500" />
                            <span className="text-[10px] font-black text-amber-500/80 uppercase tracking-tighter">Hosted</span>
                         </div>
                       )}
                       <div className="flex items-center gap-1.5 pt-1">
                          <UserPlus size={10} className="text-slate-500" />
                          <span className="text-[10px] font-black text-slate-300">{user.followerCount || 0} Foll.</span>
                       </div>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col gap-2">
                   <div className="flex gap-2">
                     <button 
                        onClick={() => handleCleanupEcosystem(user)}
                        className="p-2.5 bg-red-500/10 text-red-500 border border-red-500/10 rounded-xl hover:bg-red-500 hover:text-white transition-all"
                        title="Remove Test Followers (Trash)"
                     >
                       <Trash2 size={16} />
                     </button>
                     <button 
                        onClick={() => handleFullSync(user)}
                        className="p-2.5 bg-indigo-500/10 text-indigo-400 border border-indigo-500/10 rounded-xl hover:bg-indigo-500 hover:text-white transition-all"
                        title="ONE-CLICK SYNC (Clear old & Add 5 New)"
                     >
                       <RefreshCw size={16} />
                     </button>
                     <button 
                        onClick={() => handleFreshSeed(user)}
                        className="p-2.5 bg-emerald-500/10 text-emerald-400 border border-emerald-500/10 rounded-xl hover:bg-emerald-500 hover:text-white transition-all shadow-emerald-500/20 shadow-lg"
                        title="Add 5 New Pro Users (Zap)"
                     >
                       <Zap size={16} />
                     </button>
                      <button 
                         onClick={() => handleToggleAgencyStatus(user)}
                         className={`p-2.5 border rounded-xl transition-all shadow-lg ${user.isAgencyOwner ? 'bg-amber-500 text-white border-amber-400 shadow-amber-500/40' : 'bg-amber-500/10 text-amber-400 border-amber-500/10 shadow-amber-500/20'}`}
                         title={user.isAgencyOwner ? "Revoke Agency Status" : "Appoint as Agency Owner"}
                      >
                        <Building2 size={16} />
                      </button>
                      <button 
                         onClick={() => handleToggleResellerStatus(user)}
                         className={`p-2.5 border rounded-xl transition-all shadow-lg ${user.isReseller ? 'bg-emerald-500 text-white border-emerald-400 shadow-emerald-500/40' : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/10 shadow-emerald-500/20'}`}
                         title={user.isReseller ? "Revoke Reseller Status" : "Appoint as Reseller"}
                      >
                        <Store size={16} />
                      </button>
                   </div>
                   <div className="flex gap-2">
                      <button 
                          onClick={() => setSelectedUser(user)}
                          className="flex-1 flex items-center justify-center gap-2 p-2 bg-white/5 text-slate-400 border border-white/5 rounded-xl hover:bg-white/10 hover:text-white transition-all text-[10px] font-black uppercase"
                      >
                        <Coins size={12} /> Adjust
                      </button>
                      <button 
                          onClick={() => setSvipUser(user)}
                          className={`flex-1 flex items-center justify-center gap-2 p-2 border rounded-xl transition-all text-[10px] font-black uppercase ${user.svipLevel > 0 ? 'bg-rose-500 text-white border-rose-400 shadow-lg shadow-rose-500/20' : 'bg-rose-500/10 text-rose-400 border-rose-500/10'}`}
                      >
                        <Star size={12} /> SVIP
                      </button>
                      <button 
                          onClick={() => setEditUser(user)}
                          className="flex-1 flex items-center justify-center gap-2 p-2 bg-white/5 text-slate-400 border border-white/5 rounded-xl hover:bg-white/10 hover:text-white transition-all text-[10px] font-black uppercase"
                      >
                        <RefreshCw size={12} /> Edit
                      </button>
                    </div>
                </div>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </div>
  );
};

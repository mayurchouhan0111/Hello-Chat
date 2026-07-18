import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { 
  collection, 
  query, 
  orderBy, 
  onSnapshot, 
  addDoc, 
  updateDoc, 
  doc, 
  deleteDoc,
  writeBatch
} from 'firebase/firestore';
import { 
  Heart, 
  Layers, 
  Trophy, 
  Plus, 
  Trash2, 
  Edit2, 
  Save, 
  X, 
  Check,
  AlertCircle,
  Sparkles,
  Crown,
  MessageSquare,
  Frame,
  Mail,
  UserCheck,
  UserX
} from 'lucide-react';

const TABS = [
  { id: 'requests', label: 'Requests', icon: Mail },
  { id: 'levels', label: 'Level Config', icon: Layers },
  { id: 'rewards', label: 'Rewards', icon: Trophy },
  { id: 'actions', label: 'Actions', icon: Sparkles },
];

const REWARD_TYPES = [
  { value: 'badge', label: 'Badge', icon: '🛡️' },
  { value: 'frame', label: 'Profile Frame', icon: '🖼️' },
  { value: 'chat_bubble', label: 'Chat Bubble', icon: '💬' },
  { value: 'entrance_effect', label: 'Entrance Effect', icon: '✨' },
];

export const RelationshipManagement = () => {
  const [activeTab, setActiveTab] = useState('levels');
  const [levels, setLevels] = useState([]);
  const [rewards, setRewards] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState(null);
  const [requests, setRequests] = useState([]);
  const [processingId, setProcessingId] = useState(null);
  const [userNames, setUserNames] = useState({});

  const getUserName = async (uid) => {
    if (!uid || userNames[uid]) return;
    try {
      const snap = await db.collection("users").doc(uid).get();
      if (snap.exists) {
        const d = snap.data();
        setUserNames(prev => ({ ...prev, [uid]: d.displayName || d.username || uid }));
      }
    } catch (_) {}
  };

  useEffect(() => {
    requests.forEach(r => { getUserName(r.senderUid); getUserName(r.targetUid); });
  }, [requests]);

  const [editingLevel, setEditingLevel] = useState(null);
  const [levelForm, setLevelForm] = useState({
    level: 1, name: '', minIntimacy: 0, maxIntimacy: 999, badgeIcon: '', rewards: []
  });

  const [editingReward, setEditingReward] = useState(null);
  const [showRewardForm, setShowRewardForm] = useState(false);
  const [rewardForm, setRewardForm] = useState({
    type: 'badge', name: '', icon: '', requiredLevel: 1, isActive: true
  });

  useEffect(() => {
    setLoading(true);
    const levelsQuery = query(collection(db, 'relationship_levels'), orderBy('level', 'asc'));
    const unsubLevels = onSnapshot(levelsQuery, (snap) => {
      setLevels(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    const rewardsQuery = query(collection(db, 'relationship_rewards'));
    const unsubRewards = onSnapshot(rewardsQuery, (snap) => {
      setRewards(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    const requestsQuery = query(
      collection(db, 'relationship_requests'),
      orderBy('createdAt', 'desc')
    );
    const unsubRequests = onSnapshot(requestsQuery, (snap) => {
      setRequests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    setLoading(false);
    return () => { unsubLevels(); unsubRewards(); unsubRequests(); };
  }, []);

  const handleAcceptRequest = async (req) => {
    setProcessingId(req.id);
    try {
      const acceptFn = httpsCallable(functions, 'acceptFriendRequest');
      const result = await acceptFn({ requestId: req.id });
      showMsg(`✅ Accepted friend request from ${req.senderName || req.senderUid}`);
    } catch (err) {
      showMsg(`❌ ${err.message}`, 'error');
    }
    setProcessingId(null);
  };

  const handleRejectRequest = async (req) => {
    setProcessingId(req.id);
    try {
      const rejectFn = httpsCallable(functions, 'rejectFriendRequest');
      const result = await rejectFn({ requestId: req.id });
      showMsg(`🗑️ Rejected friend request from ${req.senderName || req.senderUid}`);
    } catch (err) {
      showMsg(`❌ ${err.message}`, 'error');
    }
    setProcessingId(null);
  };

  const getRequestStatusBadge = (status) => {
    const styles = {
      pending: 'bg-amber-600/20 text-amber-400 border-amber-600/20',
      accepted: 'bg-emerald-600/20 text-emerald-400 border-emerald-600/20',
      rejected: 'bg-rose-600/20 text-rose-400 border-rose-600/20',
    };
    return styles[status] || 'bg-slate-600/20 text-slate-400 border-slate-600/20';
  };

  const showMsg = (text, type = 'success') => {
    setMessage({ text, type });
    setTimeout(() => setMessage(null), 5000);
  };

  const handleSaveLevel = async (e) => {
    e.preventDefault();
    try {
      const data = {
        level: Number(levelForm.level),
        name: levelForm.name,
        minIntimacy: Number(levelForm.minIntimacy),
        maxIntimacy: Number(levelForm.maxIntimacy),
        badgeIcon: levelForm.badgeIcon,
        rewards: levelForm.rewards,
      };
      if (editingLevel) {
        await updateDoc(doc(db, 'relationship_levels', editingLevel), data);
        showMsg('✅ Level updated.');
      } else {
        await addDoc(collection(db, 'relationship_levels'), data);
        showMsg('✅ Level created.');
      }
      setEditingLevel(null);
    } catch (err) {
      showMsg('❌ Error: ' + err.message, 'error');
    }
  };

  const handleDeleteLevel = async (id) => {
    if (!window.confirm('Delete this level?')) return;
    try {
      await deleteDoc(doc(db, 'relationship_levels', id));
      showMsg('✅ Level deleted.');
    } catch (err) {
      showMsg('❌ Error: ' + err.message, 'error');
    }
  };

  const handleSaveReward = async (e) => {
    e.preventDefault();
    try {
      const data = {
        type: rewardForm.type,
        name: rewardForm.name,
        icon: rewardForm.icon,
        requiredLevel: Number(rewardForm.requiredLevel),
        isActive: rewardForm.isActive,
      };
      if (editingReward) {
        await updateDoc(doc(db, 'relationship_rewards', editingReward), data);
        showMsg('✅ Reward updated.');
      } else {
        await addDoc(collection(db, 'relationship_rewards'), data);
        showMsg('✅ Reward created.');
      }
      setShowRewardForm(false);
      setEditingReward(null);
    } catch (err) {
      showMsg('❌ Error: ' + err.message, 'error');
    }
  };

  const handleDeleteReward = async (id) => {
    if (!window.confirm('Delete this reward?')) return;
    try {
      await deleteDoc(doc(db, 'relationship_rewards', id));
      showMsg('✅ Reward deleted.');
    } catch (err) {
      showMsg('❌ Error: ' + err.message, 'error');
    }
  };

  const seedDefaultLevels = async () => {
    if (!window.confirm('This will create 5 default levels. Continue?')) return;
    try {
      const batch = writeBatch(db);
      const defaults = [
        { level: 1, name: 'Acquaintance', minIntimacy: 0, maxIntimacy: 999, badgeIcon: 'handshake', rewards: [{ type: 'badge', name: 'Acquaintance Badge' }] },
        { level: 2, name: 'Friend', minIntimacy: 1000, maxIntimacy: 4999, badgeIcon: 'star', rewards: [{ type: 'badge', name: 'Friend Badge' }] },
        { level: 3, name: 'Close Friend', minIntimacy: 5000, maxIntimacy: 19999, badgeIcon: 'heart', rewards: [{ type: 'badge', name: 'Close Friend Badge' }, { type: 'chat_bubble', name: 'Friendship Bubble' }] },
        { level: 4, name: 'Best Friend', minIntimacy: 20000, maxIntimacy: 49999, badgeIcon: 'sparkles', rewards: [{ type: 'badge', name: 'Best Friend Badge' }, { type: 'frame', name: 'Best Friend Frame' }] },
        { level: 5, name: 'Soulmate', minIntimacy: 50000, maxIntimacy: 999999, badgeIcon: 'crown', rewards: [{ type: 'badge', name: 'Soulmate Badge' }, { type: 'frame', name: 'Soulmate Frame' }, { type: 'entrance_effect', name: 'Soulmate Entrance' }] },
      ];
      for (const lvl of defaults) {
        const ref = doc(db, 'relationship_levels', `level_${lvl.level}`);
        batch.set(ref, lvl);
      }
      await batch.commit();
      showMsg('✅ Default levels seeded!');
    } catch (err) {
      showMsg('❌ Error: ' + err.message, 'error');
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-pink-500/20 rounded-2xl border border-pink-500/30">
              <Heart className="text-pink-400" size={28} />
            </div>
            Relationship System
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Manage friendship & CP levels, rewards, and rankings
          </p>
        </div>

        <div className="flex bg-[#111115] border border-white/[0.04] p-1.5 rounded-2xl">
          {TABS.map((tab) => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button key={tab.id} onClick={() => { setActiveTab(tab.id); setMessage(null); }}
                className={`flex items-center gap-2 px-5 py-3 rounded-xl text-xs font-black uppercase tracking-wider transition-all ${active ? 'bg-pink-600 text-white shadow-lg' : 'text-slate-400 hover:text-white'}`}>
                <Icon size={14} /> {tab.label}
              </button>
            );
          })}
        </div>
      </div>

      {message && (
        <div className={`p-4 rounded-2xl flex items-center gap-3 border ${message.type === 'error' ? 'bg-rose-500/10 border-rose-500/20 text-rose-400' : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'}`}>
          <AlertCircle size={18} />
          <p className="text-xs font-black uppercase tracking-wider">{message.text}</p>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="w-10 h-10 border-4 border-pink-500/20 border-t-pink-500 rounded-full animate-spin"></div>
        </div>
      ) : (
          <div>
            {/* REQUESTS TAB */}
            {activeTab === 'requests' && (
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  <p className="text-slate-400 text-sm">Manage pending friend requests across all users. Accept or reject on their behalf.</p>
                  <div className="flex items-center gap-3 text-sm">
                    <span className="text-slate-500">Total: <strong className="text-white">{requests.length}</strong></span>
                    <span className="text-amber-400">Pending: <strong>{requests.filter(r => r.status === 'pending').length}</strong></span>
                  </div>
                </div>

                <div className="bg-[#111115] border border-white/[0.04] rounded-3xl overflow-hidden shadow-2xl">
                  {requests.length === 0 ? (
                    <div className="p-16 text-center text-slate-500 uppercase font-black">No friend requests found.</div>
                  ) : (
                    <table className="w-full text-left border-collapse">
                      <thead>
                        <tr className="bg-white/[0.02] border-b border-white/[0.04] text-[10px] font-black text-slate-500 uppercase tracking-wider">
                          <th className="p-5">From</th>
                          <th className="p-5">To</th>
                          <th className="p-5">Status</th>
                          <th className="p-5">Created</th>
                          <th className="p-5 text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-white/[0.02] text-xs">
                        {requests.map((req) => (
                          <tr key={req.id} className="hover:bg-white/[0.01] transition-colors">
                            <td className="p-5">
                              <div className="text-white font-bold text-xs">{req.senderName || userNames[req.senderUid] || req.senderUid || '-'}</div>
                              <div className="text-slate-500 text-[10px] font-mono">{req.senderUid || ''}</div>
                            </td>
                            <td className="p-5">
                              <div className="text-white font-bold text-xs">{userNames[req.targetUid] || req.targetUid || '-'}</div>
                              <div className="text-slate-500 text-[10px] font-mono">{req.targetUid || ''}</div>
                            </td>
                            <td className="p-5">
                              <span className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-wider border ${getRequestStatusBadge(req.status)}`}>
                                {req.status || 'unknown'}
                              </span>
                            </td>
                            <td className="p-5 text-slate-500">
                              {req.createdAt?.toDate ? req.createdAt.toDate().toLocaleString() : req.createdAt || '-'}
                            </td>
                            <td className="p-5 text-right">
                              <div className="flex justify-end gap-2">
                                {req.status === 'pending' && (
                                  <>
                                    <button
                                      onClick={() => handleAcceptRequest(req)}
                                      disabled={processingId === req.id}
                                      className="flex items-center gap-2 px-4 py-2 bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-400 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all border border-emerald-600/20 disabled:opacity-50"
                                    >
                                      <UserCheck size={14} />
                                      Accept
                                    </button>
                                    <button
                                      onClick={() => handleRejectRequest(req)}
                                      disabled={processingId === req.id}
                                      className="flex items-center gap-2 px-4 py-2 bg-rose-600/20 hover:bg-rose-600/30 text-rose-400 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all border border-rose-600/20 disabled:opacity-50"
                                    >
                                      <UserX size={14} />
                                      Reject
                                    </button>
                                  </>
                                )}
                                {req.status === 'accepted' && (
                                  <span className="text-emerald-600/60 text-[10px] font-black uppercase tracking-wider px-2">Done</span>
                                )}
                                {req.status === 'rejected' && (
                                  <span className="text-rose-600/60 text-[10px] font-black uppercase tracking-wider px-2">Rejected</span>
                                )}
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>
            )}

            {/* LEVELS TAB */}
            {activeTab === 'levels' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <p className="text-slate-400 text-sm">Configure intimacy thresholds, names, and reward unlocks for each relationship level.</p>
                <div className="flex gap-3">
                  <button onClick={seedDefaultLevels} className="px-4 py-3 bg-amber-600/20 hover:bg-amber-600/30 text-amber-400 rounded-xl text-xs font-black uppercase tracking-wider transition-all border border-amber-600/20">
                    Seed Defaults
                  </button>
                </div>
              </div>

              <div className="bg-[#111115] border border-white/[0.04] rounded-3xl overflow-hidden shadow-2xl">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-white/[0.02] border-b border-white/[0.04] text-[10px] font-black text-slate-500 uppercase tracking-wider">
                      <th className="p-5">Level</th>
                      <th className="p-5">Name</th>
                      <th className="p-5">Min Intimacy</th>
                      <th className="p-5">Max Intimacy</th>
                      <th className="p-5">Badge Icon</th>
                      <th className="p-5">Rewards</th>
                      <th className="p-5 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/[0.02] text-xs">
                    {levels.length === 0 ? (
                      <tr><td colSpan="7" className="p-10 text-center text-slate-500 uppercase font-black">No levels configured. Click "Seed Defaults" or add manually.</td></tr>
                    ) : levels.map((lvl) => (
                      <tr key={lvl.id} className="hover:bg-white/[0.01] transition-colors">
                        <td className="p-5 font-black text-pink-400">{lvl.level}</td>
                        <td className="p-5 font-bold text-white">{lvl.name}</td>
                        <td className="p-5 text-slate-300 font-mono">{lvl.minIntimacy?.toLocaleString()}</td>
                        <td className="p-5 text-slate-300 font-mono">{lvl.maxIntimacy?.toLocaleString()}</td>
                        <td className="p-5 text-slate-400">{lvl.badgeIcon || '-'}</td>
                        <td className="p-5 text-slate-400 max-w-xs truncate">
                          {(lvl.rewards || []).map(r => r.name).join(', ') || '-'}
                        </td>
                        <td className="p-5 text-right">
                          <div className="flex justify-end gap-3">
                            <button onClick={() => { setLevelForm(lvl); setEditingLevel(lvl.id); }} className="p-2 hover:bg-pink-600/20 text-pink-400 rounded-lg transition-all border border-pink-500/10">
                              <Edit2 size={14} />
                            </button>
                            <button onClick={() => handleDeleteLevel(lvl.id)} className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg transition-all border border-rose-500/10">
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {editingLevel && (
                <form onSubmit={handleSaveLevel} className="bg-[#111115] border border-white/[0.04] p-8 rounded-3xl space-y-6">
                  <h3 className="text-lg font-bold border-b border-white/[0.04] pb-4 flex items-center justify-between">
                    <span>Edit Level {levelForm.level}</span>
                    <button type="button" onClick={() => setEditingLevel(null)} className="p-2 hover:bg-white/5 rounded-lg text-slate-400 hover:text-white"><X size={16} /></button>
                  </h3>
                  <div className="grid grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Level Number</label>
                      <input type="number" min="1" className="glass-input w-full h-14" value={levelForm.level} onChange={e => setLevelForm({...levelForm, level: e.target.value})} />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Level Name</label>
                      <input type="text" className="glass-input w-full h-14" value={levelForm.name} onChange={e => setLevelForm({...levelForm, name: e.target.value})} />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Min Intimacy</label>
                      <input type="number" min="0" className="glass-input w-full h-14" value={levelForm.minIntimacy} onChange={e => setLevelForm({...levelForm, minIntimacy: e.target.value})} />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Max Intimacy</label>
                      <input type="number" min="0" className="glass-input w-full h-14" value={levelForm.maxIntimacy} onChange={e => setLevelForm({...levelForm, maxIntimacy: e.target.value})} />
                    </div>
                  </div>
                  <div className="flex gap-4 pt-4 border-t border-white/[0.04]">
                    <button type="submit" className="px-8 h-12 bg-pink-600 hover:bg-pink-500 text-white rounded-xl text-xs font-black uppercase tracking-widest flex items-center gap-2"><Save size={16} /> Save Level</button>
                    <button type="button" onClick={() => setEditingLevel(null)} className="px-6 h-12 bg-white/5 hover:bg-white/10 text-white rounded-xl text-xs font-black uppercase tracking-widest">Cancel</button>
                  </div>
                </form>
              )}
            </div>
          )}

          {/* REWARDS TAB */}
          {activeTab === 'rewards' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <p className="text-slate-400 text-sm">Define rewards that unlock at specific relationship levels.</p>
                {!showRewardForm && (
                  <button onClick={() => { setRewardForm({ type: 'badge', name: '', icon: '', requiredLevel: 1, isActive: true }); setEditingReward(null); setShowRewardForm(true); }}
                    className="flex items-center gap-2 px-6 py-3 bg-pink-600 hover:bg-pink-500 text-white rounded-xl text-xs font-black uppercase tracking-wider transition-all">
                    <Plus size={16} /> Add Reward
                  </button>
                )}
              </div>

              {showRewardForm && (
                <form onSubmit={handleSaveReward} className="bg-[#111115] border border-white/[0.04] p-8 rounded-3xl space-y-6">
                  <h3 className="text-lg font-bold border-b border-white/[0.04] pb-4 flex items-center justify-between">
                    <span>{editingReward ? 'Edit Reward' : 'Create Reward'}</span>
                    <button type="button" onClick={() => { setShowRewardForm(false); setEditingReward(null); }} className="p-2 hover:bg-white/5 rounded-lg"><X size={16} /></button>
                  </h3>
                  <div className="grid grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Reward Type</label>
                      <select className="glass-input w-full h-14" value={rewardForm.type} onChange={e => setRewardForm({...rewardForm, type: e.target.value})}>
                        {REWARD_TYPES.map(t => <option key={t.value} value={t.value}>{t.icon} {t.label}</option>)}
                      </select>
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Reward Name</label>
                      <input type="text" className="glass-input w-full h-14" value={rewardForm.name} onChange={e => setRewardForm({...rewardForm, name: e.target.value})} />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Icon URL / Emoji</label>
                      <input type="text" className="glass-input w-full h-14" value={rewardForm.icon} onChange={e => setRewardForm({...rewardForm, icon: e.target.value})} />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Required Level</label>
                      <input type="number" min="1" className="glass-input w-full h-14" value={rewardForm.requiredLevel} onChange={e => setRewardForm({...rewardForm, requiredLevel: e.target.value})} />
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <input type="checkbox" className="w-5 h-5" checked={rewardForm.isActive} onChange={e => setRewardForm({...rewardForm, isActive: e.target.checked})} />
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Active</span>
                  </div>
                  <div className="flex gap-4 pt-4 border-t border-white/[0.04]">
                    <button type="submit" className="px-8 h-12 bg-pink-600 hover:bg-pink-500 text-white rounded-xl text-xs font-black uppercase tracking-widest flex items-center gap-2"><Save size={16} /> Save Reward</button>
                    <button type="button" onClick={() => { setShowRewardForm(false); setEditingReward(null); }} className="px-6 h-12 bg-white/5 hover:bg-white/10 text-white rounded-xl text-xs font-black uppercase tracking-widest">Cancel</button>
                  </div>
                </form>
              )}

              <div className="bg-[#111115] border border-white/[0.04] rounded-3xl overflow-hidden shadow-2xl">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-white/[0.02] border-b border-white/[0.04] text-[10px] font-black text-slate-500 uppercase tracking-wider">
                      <th className="p-5">Type</th>
                      <th className="p-5">Name</th>
                      <th className="p-5">Required Level</th>
                      <th className="p-5">Status</th>
                      <th className="p-5 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/[0.02] text-xs">
                    {rewards.length === 0 ? (
                      <tr><td colSpan="5" className="p-10 text-center text-slate-500 uppercase font-black">No rewards configured.</td></tr>
                    ) : rewards.map((rw) => (
                      <tr key={rw.id} className="hover:bg-white/[0.01] transition-colors">
                        <td className="p-5"><span className="px-3 py-1 rounded-full text-[9px] font-black bg-pink-500/10 text-pink-400 border border-pink-500/20 uppercase">{rw.type}</span></td>
                        <td className="p-5 font-bold text-white">{rw.name}</td>
                        <td className="p-5 text-slate-300">Level {rw.requiredLevel}</td>
                        <td className="p-5">
                          {rw.isActive ? (
                            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"><Check size={8} /> ACTIVE</span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-rose-500/10 text-rose-400 border border-rose-500/20">DISABLED</span>
                          )}
                        </td>
                        <td className="p-5 text-right">
                          <div className="flex justify-end gap-3">
                            <button onClick={() => { setRewardForm(rw); setEditingReward(rw.id); setShowRewardForm(true); }} className="p-2 hover:bg-pink-600/20 text-pink-400 rounded-lg border border-pink-500/10"><Edit2 size={14} /></button>
                            <button onClick={() => handleDeleteReward(rw.id)} className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg border border-rose-500/10"><Trash2 size={14} /></button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ACTIONS TAB */}
          {activeTab === 'actions' && (
            <div className="space-y-6">
              <p className="text-slate-400 text-sm">Admin utility actions for the relationship system.</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <button onClick={async () => {
                  try {
                    const { getFunctions, httpsCallable } = await import('firebase/functions');
                    const functions = getFunctions();
                    const calc = httpsCallable(functions, 'calculateRelationshipRankings');
                    await calc({ period: 'all_time' });
                    showMsg('✅ All-time rankings calculated!');
                  } catch (err) { showMsg('❌ Error: ' + err.message, 'error'); }
                }} className="p-8 bg-[#111115] border border-white/[0.04] rounded-3xl text-left hover:bg-white/[0.02] transition-all">
                  <Trophy className="text-amber-400 mb-4" size={32} />
                  <h3 className="text-lg font-bold text-white mb-2">Calculate Rankings</h3>
                  <p className="text-slate-400 text-sm">Recalculate all-time relationship rankings based on current intimacy.</p>
                </button>
                <button onClick={async () => {
                  try {
                    const { getFunctions, httpsCallable } = await import('firebase/functions');
                    const functions = getFunctions();
                    const seed = httpsCallable(functions, 'seedRelationshipLevels');
                    await seed();
                    showMsg('✅ Levels seeded via Cloud Function!');
                  } catch (err) { showMsg('❌ Error: ' + err.message, 'error'); }
                }} className="p-8 bg-[#111115] border border-white/[0.04] rounded-3xl text-left hover:bg-white/[0.02] transition-all">
                  <Sparkles className="text-purple-400 mb-4" size={32} />
                  <h3 className="text-lg font-bold text-white mb-2">Seed Levels (CF)</h3>
                  <p className="text-slate-400 text-sm">Run the Cloud Function to seed default relationship levels.</p>
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

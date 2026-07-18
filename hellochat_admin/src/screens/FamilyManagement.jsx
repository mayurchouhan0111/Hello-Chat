import { useState, useEffect } from 'react';
import { db, storage } from '../firebase';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import {
  collection, query, getDocs, doc, writeBatch, deleteDoc, getDoc, updateDoc, where, setDoc, addDoc, limit
} from 'firebase/firestore';
import {
  Search, Trash2, Users, Shield, Info, X, Plus, Zap, RefreshCw,
  MoreVertical, Activity, Trophy, User, Edit3, Check, ChevronDown,
  ChevronUp, Flag, Globe, Camera, Settings, UserCheck, UserX,
  Award, Target, DollarSign, Flame, Star, Crown
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const RANK_NAMES = ['Bronze', 'Silver', 'Gold', 'Diamond', 'Master', 'Challenger I', 'Challenger II', 'Challenger III', 'Supreme', 'Immortal'];

const RANK_THRESHOLDS = {
  'Bronze': 0, 'Silver': 20000, 'Gold': 100000, 'Diamond': 500000,
  'Master': 2000000, 'Challenger I': 5000000, 'Challenger II': 10000000,
  'Challenger III': 16000000, 'Supreme': 30000000, 'Immortal': 50000000,
};

const FamilyDetailsModal = ({ family, onClose, onUpdate }) => {
  const [tab, setTab] = useState('overview');
  const [members, setMembers] = useState([]);
  const [joinRequests, setJoinRequests] = useState([]);
  const [battleRequests, setBattleRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Edit state
  const [editName, setEditName] = useState(family.name || '');
  const [editTag, setEditTag] = useState(family.tag || '');
  const [editDescription, setEditDescription] = useState(family.description || '');
  const [editCountry, setEditCountry] = useState(family.country || '');
  const [editMonthlyTarget, setEditMonthlyTarget] = useState(family.monthlyTarget || 3000000);
  const [editCombatPoints, setEditCombatPoints] = useState(family.totalCombatPoints || 0);
  const [editBattlePoints, setEditBattlePoints] = useState(family.totalBattlePoints || 0);
  const [editLevel, setEditLevel] = useState(family.level || 1);
  const [editMemberLimit, setEditMemberLimit] = useState(family.memberLimit || 100);
  const [editRankName, setEditRankName] = useState(family.rankName || 'Bronze');
  const [newAvatarFile, setNewAvatarFile] = useState(null);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);

  const [selectedMember, setSelectedMember] = useState(null);
  const [editMemberLevel, setEditMemberLevel] = useState(1);
  const [editMemberCombat, setEditMemberCombat] = useState(0);
  const [editMemberRole, setEditMemberRole] = useState('member');

  useEffect(() => {
    fetchMembers();
    fetchJoinRequests();
    fetchBattleRequests();
  }, [family]);

  const fetchMembers = async () => {
    setLoading(true);
    try {
      // Try getting from members subcollection first
      let memberDetails = [];
      try {
        const membersSnap = await getDocs(collection(db, "families", family.id, "members"));
        if (!membersSnap.empty) {
          membersSnap.forEach(mDoc => {
            memberDetails.push({ id: mDoc.id, ...mDoc.data() });
          });
        }
      } catch (e) { /* subcollection might not exist */ }

      // If subcollection empty, fallback to memberUids
      if (memberDetails.length === 0 && family.memberUids) {
        for (const uid of family.memberUids) {
          const userDoc = await getDoc(doc(db, "users", uid));
          if (userDoc.exists()) {
            const userData = userDoc.data();
            memberDetails.push({
              id: uid,
              userId: uid,
              role: uid === family.ownerId ? 'owner' : 'member',
              combatPoints: userData.combatPoints || 0,
              memberLevel: userData.familyMemberLevel || 1,
              ...userData,
            });
          }
        }
      }
      setMembers(memberDetails);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchJoinRequests = async () => {
    try {
      const q = query(
        collection(db, "familyJoinRequests"),
        where("familyId", "==", family.id),
        where("status", "==", "pending")
      );
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setJoinRequests(list);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchBattleRequests = async () => {
    try {
      const q = query(
        collection(db, "familyBattleRequests"),
        where("opponentFamilyId", "==", family.id),
        where("status", "==", "pending")
      );
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setBattleRequests(list);
    } catch (err) {
      console.error(err);
    }
  };

  const handleAcceptBattle = async (req) => {
    try {
      await updateDoc(doc(db, "familyBattleRequests", req.id), { status: 'accepted' });
      // Create battle (mirrored in both families' subcollections)
      const familyADoc = await getDoc(doc(db, "families", req.challengerFamilyId));
      const familyBDoc = await getDoc(doc(db, "families", family.id));
      if (!familyADoc.exists() || !familyBDoc.exists()) { alert("Family not found"); return; }
      const familyA = { id: familyADoc.id, ...familyADoc.data() };
      const familyB = { id: familyBDoc.id, ...familyBDoc.data() };
      const now = new Date();
      const durationSeconds = 180;
      const battleData = {
        familyAId: req.challengerFamilyId,
        familyAName: familyA.name,
        familyAAvatar: familyA.avatarUrl || null,
        familyAPoints: 0,
        familyBId: family.id,
        familyBName: familyB.name,
        familyBAvatar: familyB.avatarUrl || null,
        familyBPoints: 0,
        startedAt: now,
        durationSeconds,
        status: 'active',
        winnerId: null,
      };
      const batch = writeBatch(db);
      const battleId = doc(collection(db, "families", req.challengerFamilyId, "battles")).id;
      const battleRefA = doc(db, "families", req.challengerFamilyId, "battles", battleId);
      const battleRefB = doc(db, "families", family.id, "battles", battleId);
      batch.set(battleRefA, { ...battleData, id: battleId });
      batch.set(battleRefB, { ...battleData, id: battleId });
      await batch.commit();
      alert(`Battle started between ${familyA.name} and ${familyB.name}!`);
      fetchBattleRequests();
      onUpdate();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleRejectBattle = async (reqId) => {
    try {
      await updateDoc(doc(db, "familyBattleRequests", reqId), { status: 'rejected' });
      fetchBattleRequests();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleSaveSettings = async () => {
    setSaving(true);
    try {
      let avatarUrl = family.avatarUrl;
      if (newAvatarFile) {
        const storageRef = ref(storage, `families/emblems/${Date.now()}_${newAvatarFile.name}`);
        const snapshot = await uploadBytesResumable(storageRef, newAvatarFile);
        avatarUrl = await getDownloadURL(snapshot.ref);
      }
      await updateDoc(doc(db, "families", family.id), {
        name: editName,
        tag: editTag,
        description: editDescription,
        country: editCountry,
        monthlyTarget: Number(editMonthlyTarget),
        totalCombatPoints: Number(editCombatPoints),
        totalBattlePoints: Number(editBattlePoints),
        level: Number(editLevel),
        memberLimit: Number(editMemberLimit),
        rankName: editRankName,
        ...(avatarUrl !== family.avatarUrl ? { avatarUrl } : {}),
      });
      setNewAvatarFile(null);
      alert("Family updated successfully.");
      onUpdate();
    } catch (err) {
      alert("Error: " + err.message);
    } finally {
      setSaving(false);
    }
  };

  const handleApproveRequest = async (req) => {
    try {
      const batch = writeBatch(db);
      batch.update(doc(db, "familyJoinRequests", req.id), { status: 'accepted' });
      batch.update(doc(db, "families", family.id), {
        memberUids: [...(family.memberUids || []), req.userId]
      });
      // Create member subcollection doc
      const memberRef = doc(db, "families", family.id, "members", req.userId);
      batch.set(memberRef, {
        userId: req.userId,
        familyId: family.id,
        role: 'member',
        memberLevel: 1,
        combatPoints: 0,
        contribution: 0,
        joinedAt: new Date(),
      });
      batch.update(doc(db, "users", req.userId), {
        familyId: family.id,
        isFamilyOwner: false,
      });
      await batch.commit();
      fetchJoinRequests();
      onUpdate();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleRejectRequest = async (reqId) => {
    try {
      await updateDoc(doc(db, "familyJoinRequests", reqId), { status: 'rejected' });
      fetchJoinRequests();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleRemoveMember = async (memberId) => {
    if (!window.confirm(`Remove this member?`)) return;
    try {
      const batch = writeBatch(db);
      const newMembers = (family.memberUids || []).filter(id => id !== memberId);
      batch.update(doc(db, "families", family.id), { memberUids: newMembers });
      batch.delete(doc(db, "families", family.id, "members", memberId));
      batch.update(doc(db, "users", memberId), { familyId: null, isFamilyOwner: false });
      await batch.commit();
      fetchMembers();
      onUpdate();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handlePromoteAdmin = async (memberId) => {
    try {
      const batch = writeBatch(db);
      batch.update(doc(db, "families", family.id, "members", memberId), { role: 'admin' });
      await batch.commit();
      fetchMembers();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleDemoteAdmin = async (memberId) => {
    try {
      await updateDoc(doc(db, "families", family.id, "members", memberId), { role: 'member' });
      fetchMembers();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleSaveMember = async (memberId) => {
    try {
      const batch = writeBatch(db);
      batch.update(doc(db, "families", family.id, "members", memberId), {
        memberLevel: Number(editMemberLevel),
        combatPoints: Number(editMemberCombat),
        role: editMemberRole,
      });
      batch.update(doc(db, "users", memberId), {
        familyMemberLevel: Number(editMemberLevel),
        combatPoints: Number(editMemberCombat),
      });
      await batch.commit();
      setSelectedMember(null);
      fetchMembers();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleAwardCombatPoints = async (points) => {
    if (!window.confirm(`Award ${points} combat points to ALL members?`)) return;
    try {
      const batch = writeBatch(db);
      (family.memberUids || []).forEach(uid => {
        if (uid === family.ownerId) return;
        const memberRef = doc(db, "families", family.id, "members", uid);
        batch.update(memberRef, {
          combatPoints: window.firebaseFieldValue?.increment(points) || points,
        });
        batch.update(doc(db, "users", uid), {
          combatPoints: window.firebaseFieldValue?.increment(points) || points,
        });
      });
      batch.update(doc(db, "families", family.id), {
        totalCombatPoints: (family.totalCombatPoints || 0) + (points * ((family.memberUids?.length || 1) - 1)),
      });
      await batch.commit();
      alert("Points awarded!");
      onUpdate();
    } catch (err) {
      alert(err.message);
    }
  };

  const tabs = [
    { id: 'overview', label: 'Overview', icon: Info },
    { id: 'members', label: 'Members', icon: Users },
    { id: 'requests', label: `Requests (${joinRequests.length})`, icon: UserCheck },
    { id: 'battles', label: `Battles (${battleRequests.length})`, icon: Zap },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-4xl rounded-3xl overflow-hidden shadow-2xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="p-6 border-b border-white/5 flex justify-between items-center shrink-0">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-amber-500/20 text-amber-500 rounded-2xl">
              <Users size={24} />
            </div>
            <div>
              <h2 className="text-xl font-black text-white uppercase tracking-tight">{family.name}</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">
                ID: {family.id} • {family.rankName || 'No Rank'} • Lv.{family.level || 1}
              </p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-white/5 px-6 shrink-0 overflow-x-auto">
          {tabs.map(t => {
            const Icon = t.icon;
            return (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`flex items-center gap-2 px-4 py-3 text-xs font-black uppercase tracking-widest border-b-2 transition-all whitespace-nowrap ${
                  tab === t.id ? 'text-amber-400 border-amber-400' : 'text-slate-500 border-transparent hover:text-slate-300'
                }`}
              >
                <Icon size={14} />
                {t.label}
              </button>
            );
          })}
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto custom-scrollbar flex-1">
          {/* OVERVIEW TAB */}
          {tab === 'overview' && (
            <div className="space-y-6">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Members</p>
                  <p className="text-xl font-black text-white">{family.memberUids?.length || 0} / {family.memberLimit || 100}</p>
                </div>
                <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Combat Points</p>
                  <p className="text-xl font-black text-emerald-400">{(family.totalCombatPoints || 0).toLocaleString()}</p>
                </div>
                <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Battle Points</p>
                  <p className="text-xl font-black text-indigo-400">{(family.totalBattlePoints || 0).toLocaleString()}</p>
                </div>
                <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Monthly Target</p>
                  <p className="text-xl font-black text-amber-400">{(family.currentMonthPoints || 0).toLocaleString()} / {(family.monthlyTarget || 0).toLocaleString()}</p>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Owner</p>
                  <p className="text-sm font-bold text-white truncate">{family.ownerId}</p>
                </div>
                <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-1">Country</p>
                  <p className="text-sm font-bold text-white">{family.country || 'N/A'}</p>
                </div>
              </div>

              <div className="flex gap-3">
                <button onClick={() => handleAwardCombatPoints(500)} className="flex items-center gap-2 px-4 py-3 bg-amber-500/10 text-amber-400 border border-amber-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-amber-500 hover:text-white transition-all">
                  <Zap size={14} /> Award 500 CP All
                </button>
                <button onClick={() => handleAwardCombatPoints(1000)} className="flex items-center gap-2 px-4 py-3 bg-amber-500/10 text-amber-400 border border-amber-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-amber-500 hover:text-white transition-all">
                  <Zap size={14} /> Award 1000 CP All
                </button>
              </div>
            </div>
          )}

          {/* MEMBERS TAB */}
          {tab === 'members' && (
            <div className="space-y-3">
              {selectedMember && (
                <div className="p-4 rounded-2xl bg-indigo-500/10 border border-indigo-500/20">
                  <p className="text-[10px] font-black text-slate-500 uppercase mb-3">Edit Member: {selectedMember.displayName || selectedMember.id}</p>
                  <div className="grid grid-cols-3 gap-3">
                    <div>
                      <label className="text-[9px] font-black text-slate-600 uppercase block mb-1">Level</label>
                      <input type="number" value={editMemberLevel} onChange={e => setEditMemberLevel(e.target.value)}
                        className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm font-bold" />
                    </div>
                    <div>
                      <label className="text-[9px] font-black text-slate-600 uppercase block mb-1">Combat Points</label>
                      <input type="number" value={editMemberCombat} onChange={e => setEditMemberCombat(e.target.value)}
                        className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm font-bold" />
                    </div>
                    <div>
                      <label className="text-[9px] font-black text-slate-600 uppercase block mb-1">Role</label>
                      <select value={editMemberRole} onChange={e => setEditMemberRole(e.target.value)}
                        className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm font-bold">
                        <option value="member">Member</option>
                        <option value="admin">Admin</option>
                      </select>
                    </div>
                  </div>
                  <div className="flex gap-2 mt-3">
                    <button onClick={() => handleSaveMember(selectedMember.id)} className="px-4 py-2 bg-emerald-500/20 text-emerald-400 rounded-xl text-[10px] font-black uppercase hover:bg-emerald-500 hover:text-white transition-all">
                      <Check size={14} className="inline mr-1" /> Save
                    </button>
                    <button onClick={() => setSelectedMember(null)} className="px-4 py-2 bg-white/5 text-slate-400 rounded-xl text-[10px] font-black uppercase hover:bg-white/10 transition-all">
                      Cancel
                    </button>
                  </div>
                </div>
              )}

              {loading ? (
                <div className="p-8 flex justify-center"><RefreshCw className="animate-spin text-slate-600" /></div>
              ) : members.length === 0 ? (
                <p className="text-slate-500 text-center py-8 text-sm">No members found</p>
              ) : members.map(m => {
                const role = m.role || (m.id === family.ownerId ? 'owner' : 'member');
                const isOwner = role === 'owner';
                return (
                  <div key={m.id} className="flex items-center justify-between p-4 bg-white/5 rounded-2xl border border-white/5 group">
                    <div className="flex items-center gap-3 min-w-0">
                      <img src={m.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${m.id}`}
                        className="w-10 h-10 rounded-xl object-cover shrink-0" alt="" />
                      <div className="min-w-0">
                        <p className="text-sm font-black text-white flex items-center gap-2 truncate">
                          {m.displayName || 'Unknown'}
                          {isOwner && <Crown size={12} className="text-amber-500 shrink-0" />}
                          {role === 'admin' && <Shield size={12} className="text-blue-400 shrink-0" />}
                        </p>
                        <p className="text-[10px] font-bold text-slate-500 truncate">{m.id}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 shrink-0">
                      <span className="text-xs font-black text-emerald-400">Lv.{m.memberLevel || 1}</span>
                      <span className="text-xs font-bold text-amber-400">{(m.combatPoints || 0).toLocaleString()} CP</span>
                      {!isOwner && (
                        <>
                          {role === 'admin' ? (
                            <button onClick={() => handleDemoteAdmin(m.id)} title="Demote"
                              className="p-1.5 text-blue-400 hover:bg-blue-500/10 rounded-lg transition-all">
                              <UserX size={14} />
                            </button>
                          ) : (
                            <button onClick={() => handlePromoteAdmin(m.id)} title="Promote to Admin"
                              className="p-1.5 text-slate-500 hover:text-blue-400 hover:bg-blue-500/10 rounded-lg transition-all">
                              <Shield size={14} />
                            </button>
                          )}
                          <button onClick={() => { setSelectedMember(m); setEditMemberLevel(m.memberLevel || 1); setEditMemberCombat(m.combatPoints || 0); setEditMemberRole(role); }}
                            className="p-1.5 text-slate-500 hover:text-indigo-400 hover:bg-indigo-500/10 rounded-lg transition-all">
                            <Edit3 size={14} />
                          </button>
                          <button onClick={() => handleRemoveMember(m.id)}
                            className="p-1.5 text-slate-500 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all">
                            <X size={14} />
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* JOIN REQUESTS TAB */}
          {tab === 'requests' && (
            <div className="space-y-3">
              {joinRequests.length === 0 ? (
                <p className="text-slate-500 text-center py-8 text-sm">No pending join requests</p>
              ) : joinRequests.map(req => (
                <div key={req.id} className="flex items-center justify-between p-4 bg-white/5 rounded-2xl border border-white/5">
                  <div className="flex items-center gap-3">
                    <img src={req.userAvatar || `https://api.dicebear.com/7.x/avataaars/png?seed=${req.userId}`}
                      className="w-10 h-10 rounded-xl object-cover" alt="" />
                    <div>
                      <p className="text-sm font-black text-white">{req.userName || 'Unknown'}</p>
                      <p className="text-[10px] font-bold text-slate-500">{req.userId}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => handleRejectRequest(req.id)}
                      className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-all">
                      <X size={16} />
                    </button>
                    <button onClick={() => handleApproveRequest(req)}
                      className="flex items-center gap-2 px-4 py-2 bg-emerald-500/10 text-emerald-400 border border-emerald-500/10 rounded-xl text-[10px] font-black uppercase hover:bg-emerald-500 hover:text-white transition-all">
                      <Check size={14} /> Accept
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* BATTLES TAB */}
          {tab === 'battles' && (
            <div className="space-y-3">
              {battleRequests.length === 0 ? (
                <p className="text-slate-500 text-center py-8 text-sm">No incoming battle challenges</p>
              ) : battleRequests.map(req => (
                <div key={req.id} className="flex items-center justify-between p-4 bg-white/5 rounded-2xl border border-white/5">
                  <div className="flex items-center gap-3">
                    <img src={req.challengerAvatar || `https://api.dicebear.com/7.x/avataaars/png?seed=${req.challengerFamilyId}`}
                      className="w-10 h-10 rounded-xl object-cover" alt="" />
                    <div>
                      <p className="text-sm font-black text-white">{req.challengerName || 'Unknown'}</p>
                      <p className="text-[10px] font-bold text-slate-500">Challenger ID: {req.challengerFamilyId}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => handleRejectBattle(req.id)}
                      className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-all">
                      <X size={16} />
                    </button>
                    <button onClick={() => handleAcceptBattle(req)}
                      className="flex items-center gap-2 px-4 py-2 bg-amber-500/10 text-amber-400 border border-amber-500/10 rounded-xl text-[10px] font-black uppercase hover:bg-amber-500 hover:text-black transition-all">
                      <Zap size={14} /> Accept
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* SETTINGS TAB */}
          {tab === 'settings' && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Family Name</label>
                  <input type="text" value={editName} onChange={e => setEditName(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Tag</label>
                  <input type="text" value={editTag} onChange={e => setEditTag(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Country</label>
                  <input type="text" value={editCountry} onChange={e => setEditCountry(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Monthly Target</label>
                  <input type="number" value={editMonthlyTarget} onChange={e => setEditMonthlyTarget(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Family Level</label>
                  <input type="number" value={editLevel} onChange={e => setEditLevel(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Member Limit</label>
                  <input type="number" value={editMemberLimit} onChange={e => setEditMemberLimit(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Combat Points</label>
                  <input type="number" value={editCombatPoints} onChange={e => setEditCombatPoints(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Battle Points</label>
                  <input type="number" value={editBattlePoints} onChange={e => setEditBattlePoints(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Rank</label>
                  <select value={editRankName} onChange={e => setEditRankName(e.target.value)}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold">
                    {RANK_NAMES.map(r => <option key={r} value={r}>{r}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Emblem</label>
                  <div className="flex items-center gap-3">
                    <label className="flex-1 flex items-center gap-3 px-4 py-3 bg-white/5 border border-white/10 rounded-2xl cursor-pointer hover:bg-white/10 transition-all">
                      <Camera size={18} className="text-amber-400 shrink-0" />
                      <span className="text-[10px] font-black text-slate-400 uppercase">{newAvatarFile ? newAvatarFile.name : 'Upload New Emblem'}</span>
                      <input type="file" accept="image/*" className="hidden" onChange={e => {
                        const file = e.target.files?.[0];
                        if (file) { setNewAvatarFile(file); }
                      }} />
                    </label>
                    {(newAvatarFile || family.avatarUrl) && (
                      <img src={newAvatarFile ? URL.createObjectURL(newAvatarFile) : family.avatarUrl}
                        className="w-12 h-12 rounded-xl object-cover border border-white/10" alt="" />
                    )}
                  </div>
                </div>
                <div>
                  <label className="text-[10px] font-black text-slate-500 uppercase block mb-2">Description</label>
                  <textarea value={editDescription} onChange={e => setEditDescription(e.target.value)} rows={3}
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold resize-none" />
                </div>
              </div>

              <button onClick={handleSaveSettings} disabled={saving}
                className="w-full flex items-center justify-center gap-2 py-4 bg-amber-500/20 text-amber-400 border border-amber-500/20 rounded-2xl text-xs font-black uppercase tracking-widest hover:bg-amber-500 hover:text-black transition-all disabled:opacity-50">
                {saving ? <RefreshCw size={16} className="animate-spin" /> : <Check size={16} />}
                {saving ? 'Saving...' : 'Save All Settings'}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export const FamilyManagement = () => {
  const [families, setFamilies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedFamily, setSelectedFamily] = useState(null);
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [newTag, setNewTag] = useState('');
  const [newCountry, setNewCountry] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newOwnerId, setNewOwnerId] = useState('');
  const [newAvatarFile, setNewAvatarFile] = useState(null);
  const [newAvatarPreview, setNewAvatarPreview] = useState(null);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);

  useEffect(() => {
    fetchFamilies();
  }, []);

  const fetchFamilies = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "families"), limit(100));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setFamilies(list);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!newName || !newOwnerId) { alert("Name and Owner ID required."); return; }
    setUploadingAvatar(true);
    try {
      let avatarUrl = null;
      if (newAvatarFile) {
        const storageRef = ref(storage, `families/emblems/${Date.now()}_${newAvatarFile.name}`);
        const snapshot = await uploadBytesResumable(storageRef, newAvatarFile);
        avatarUrl = await getDownloadURL(snapshot.ref);
      }

      const docRef = doc(collection(db, "families"));
      await setDoc(docRef, {
        name: newName,
        tag: newTag,
        description: newDesc,
        country: newCountry,
        ownerId: newOwnerId,
        memberUids: [newOwnerId],
        level: 1,
        totalBattlePoints: 0,
        totalCombatPoints: 0,
        createdAt: new Date(),
        category: 'Social',
        rank: 0,
        joinMode: 'verification',
        levelRequirement: 0,
        monthlyTarget: 3000000,
        currentMonthPoints: 0,
        memberLimit: 100,
        rankName: 'Bronze',
        avatarUrl,
      });
      // Create owner member doc
      await setDoc(doc(db, "families", docRef.id, "members", newOwnerId), {
        userId: newOwnerId,
        familyId: docRef.id,
        role: 'owner',
        memberLevel: 1,
        memberXP: 0,
        combatPoints: 0,
        contribution: 0,
        joinedAt: new Date(),
      });
      await updateDoc(doc(db, "users", newOwnerId), {
        familyId: docRef.id,
        isFamilyOwner: true,
      });
      alert("Family created!");
      setShowCreate(false);
      setNewName('');
      setNewTag('');
      setNewCountry('');
      setNewDesc('');
      setNewOwnerId('');
      setNewAvatarFile(null);
      setNewAvatarPreview(null);
      fetchFamilies();
    } catch (err) {
      alert("Error: " + err.message);
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handleDisband = async (family) => {
    if (!window.confirm(`PERMANENTLY DISBAND ${family.name}? This cannot be undone.`)) return;
    try {
      const batch = writeBatch(db);
      for (const uid of family.memberUids || []) {
        batch.update(doc(db, "users", uid), { familyId: null, isFamilyOwner: false });
        try { batch.delete(doc(db, "families", family.id, "members", uid)); } catch (e) {}
      }
      const requestsSnap = await getDocs(query(collection(db, "familyJoinRequests"), where("familyId", "==", family.id)));
      for (const d of requestsSnap.docs) batch.delete(d.ref);
      batch.delete(doc(db, "families", family.id));
      await batch.commit();
      alert("Family disbanded.");
      fetchFamilies();
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const handleSimulateMembers = async (family) => {
    try {
      const batch = writeBatch(db);
      const names = ["Bot_Alpha", "Bot_Beta", "Bot_Gamma", "Bot_Delta", "Bot_Epsilon"];
      let totalPts = 0;
      const uids = [];
      for (let i = 0; i < 5; i++) {
        const uid = `bot_${family.id}_${i}_${Date.now()}`;
        const pts = 1000 + (i * 200);
        uids.push(uid);
        totalPts += pts;
        batch.set(doc(db, "users", uid), {
          uid, displayName: names[i], username: names[i].toLowerCase(),
          profilePhotoUrl: `https://api.dicebear.com/7.x/pixel-art/png?seed=${uid}`,
          combatPoints: pts, familyId: family.id, level: 5 + i, familyMemberLevel: 1,
        });
        batch.set(doc(db, "families", family.id, "members", uid), {
          userId: uid, familyId: family.id, role: 'member', memberLevel: 1, memberXP: 0,
          combatPoints: pts, contribution: 0, joinedAt: new Date(),
        });
      }
      batch.update(doc(db, "families", family.id), {
        memberUids: [...(family.memberUids || []), ...uids],
        totalCombatPoints: (family.totalCombatPoints || 0) + totalPts,
      });
      await batch.commit();
      alert("Simulated 5 members added.");
      fetchFamilies();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleSimulateBattle = async (family) => {
    try {
      const newBattlePts = (family.totalBattlePoints || 0) + 1500;
      const newLevel = newBattlePts > ((family.level || 1) * 5000) ? (family.level || 1) + 1 : (family.level || 1);
      await updateDoc(doc(db, "families", family.id), {
        totalBattlePoints: newBattlePts,
        level: newLevel,
      });
      alert("Battle simulation complete. Level: " + newLevel);
      fetchFamilies();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleResetMonthly = async (family) => {
    if (!window.confirm(`Reset monthly target for ${family.name}?`)) return;
    try {
      await updateDoc(doc(db, "families", family.id), { currentMonthPoints: 0 });
      alert("Monthly target reset.");
      fetchFamilies();
    } catch (err) {
      alert(err.message);
    }
  };

  const filteredFamilies = families.filter(f =>
    f.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    f.id?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    f.country?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    f.tag?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-8 space-y-8 min-h-screen bg-[#020617] text-slate-200">
      {selectedFamily && (
        <FamilyDetailsModal
          family={selectedFamily}
          onClose={() => setSelectedFamily(null)}
          onUpdate={fetchFamilies}
        />
      )}

      {/* Create Modal */}
      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="bg-[#09090B] border border-white/10 w-full max-w-lg rounded-3xl p-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-black text-white uppercase">Create Family</h2>
              <button onClick={() => setShowCreate(false)} className="p-2 hover:bg-white/5 rounded-full">
                <X size={20} className="text-slate-500" />
              </button>
            </div>
            <div className="space-y-4">
              <input placeholder="Family Name *" value={newName} onChange={e => setNewName(e.target.value)}
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
              <input placeholder="Tag" value={newTag} onChange={e => setNewTag(e.target.value)}
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
              <input placeholder="Country" value={newCountry} onChange={e => setNewCountry(e.target.value)}
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
              <textarea placeholder="Description" value={newDesc} onChange={e => setNewDesc(e.target.value)} rows={3}
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold resize-none" />
              <input placeholder="Owner User ID *" value={newOwnerId} onChange={e => setNewOwnerId(e.target.value)}
                className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-white text-sm font-bold" />
              <div className="flex items-center gap-4">
                <label className="flex-1 flex items-center gap-3 px-4 py-3 bg-white/5 border border-white/10 rounded-2xl cursor-pointer hover:bg-white/10 transition-all">
                  <Camera size={18} className="text-amber-400 shrink-0" />
                  <span className="text-[10px] font-black text-slate-400 uppercase">{newAvatarFile ? newAvatarFile.name : 'Upload Emblem'}</span>
                  <input type="file" accept="image/*" className="hidden" onChange={e => {
                    const file = e.target.files?.[0];
                    if (file) { setNewAvatarFile(file); setNewAvatarPreview(URL.createObjectURL(file)); }
                  }} />
                </label>
                {newAvatarPreview && <img src={newAvatarPreview} className="w-12 h-12 rounded-xl object-cover border border-white/10" alt="" />}
              </div>
              <button onClick={handleCreate} disabled={uploadingAvatar}
                className="w-full flex items-center justify-center gap-2 py-4 bg-amber-500/20 text-amber-400 border border-amber-500/20 rounded-2xl text-xs font-black uppercase tracking-widest hover:bg-amber-500 hover:text-black transition-all disabled:opacity-50">
                {uploadingAvatar ? <RefreshCw size={16} className="animate-spin" /> : <Plus size={16} />}
                {uploadingAvatar ? 'Uploading...' : 'Create Family'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 pb-8 border-b border-white/5">
        <div>
          <h1 className="text-4xl font-black text-white tracking-widest uppercase">Family Battle</h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-widest mt-2">Manage clans, ranks, members & battle settings</p>
        </div>
        <div className="flex items-center gap-4">
          <div className="relative group w-72">
            <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
              <Search className="text-slate-600 group-focus-within:text-amber-400 transition-colors" size={18} />
            </div>
            <input type="text" placeholder="Search by name, ID, country..."
              className="glass-input w-full pl-12 !py-3.5"
              value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} />
          </div>
          <button onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-5 py-3.5 bg-amber-500/20 text-amber-400 border border-amber-500/20 rounded-2xl text-xs font-black uppercase tracking-widest hover:bg-amber-500 hover:text-black transition-all shrink-0">
            <Plus size={16} /> Create
          </button>
          <button onClick={fetchFamilies} className="p-3.5 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-all">
            <RefreshCw size={16} className="text-slate-400" />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <AnimatePresence>
          {loading ? (
            <div className="col-span-full py-20 flex flex-col items-center gap-4">
              <RefreshCw size={40} className="text-amber-500 animate-spin" />
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Loading Clans...</p>
            </div>
          ) : filteredFamilies.length === 0 ? (
            <div className="col-span-full py-20 text-center text-slate-500 text-sm">No families found</div>
          ) : filteredFamilies.map((family) => (
            <motion.div key={family.id} initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-[#09090B] border border-white/5 rounded-[32px] p-6 hover:bg-white/[0.02] transition-all relative overflow-hidden group">
              <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:opacity-10 transition-opacity">
                <Shield size={120} />
              </div>

              <div className="relative">
                <div className="flex items-center gap-4 mb-6">
                  <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-amber-500/20 to-orange-500/20 border border-white/5 overflow-hidden">
                    {family.avatarUrl ? (
                      <img src={family.avatarUrl} className="w-full h-full object-cover" alt="" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-amber-400">
                        <Users size={32} />
                      </div>
                    )}
                  </div>
                  <div className="min-w-0">
                    <h3 className="font-black text-white text-lg tracking-tight truncate">{family.name}</h3>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="text-[10px] font-black text-amber-500 uppercase tracking-widest">{family.tag || 'NO TAG'}</span>
                      {family.country && <span className="text-[10px] text-slate-500">• {family.country}</span>}
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-3 mb-4">
                  <div className="p-3 bg-white/5 rounded-2xl border border-white/5">
                    <Users size={12} className="text-slate-500 mb-1" />
                    <span className="text-sm font-black text-white block">{family.memberUids?.length || 0}</span>
                    <span className="text-[8px] font-black text-slate-500 uppercase">Members</span>
                  </div>
                  <div className="p-3 bg-white/5 rounded-2xl border border-white/5">
                    <Award size={12} className="text-emerald-400 mb-1" />
                    <span className="text-sm font-black text-white block">{family.level || 1}</span>
                    <span className="text-[8px] font-black text-slate-500 uppercase">Level</span>
                  </div>
                  <div className="p-3 bg-white/5 rounded-2xl border border-white/5">
                    <Trophy size={12} className="text-amber-400 mb-1" />
                    <span className="text-sm font-black text-white block truncate">{family.rankName || 'Bronze'}</span>
                    <span className="text-[8px] font-black text-slate-500 uppercase">Rank</span>
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-3 mb-4 border border-white/5">
                  <div className="flex items-center justify-between text-[10px] font-black mb-2">
                    <span className="text-slate-500 uppercase">Combat Points</span>
                    <span className="text-emerald-400">{(family.totalCombatPoints || 0).toLocaleString()}</span>
                  </div>
                  <div className="flex items-center justify-between text-[10px] font-black">
                    <span className="text-slate-500 uppercase">Monthly Target</span>
                    <span className="text-amber-400">{(family.currentMonthPoints || 0).toLocaleString()} / {(family.monthlyTarget || 0).toLocaleString()}</span>
                  </div>
                </div>

                <div className="flex flex-col gap-2 mb-4">
                  <button onClick={() => handleSimulateMembers(family)}
                    className="flex items-center justify-center gap-2 py-2.5 bg-indigo-500/10 text-indigo-400 border border-indigo-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-indigo-500 hover:text-white transition-all">
                    <Plus size={14} /> Sim 5 Members
                  </button>
                  <div className="flex gap-2">
                    <button onClick={() => handleSimulateBattle(family)}
                      className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-amber-500/10 text-amber-500 border border-amber-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-amber-500 hover:text-white transition-all">
                      <Zap size={14} /> Battle
                    </button>
                    <button onClick={() => handleResetMonthly(family)}
                      className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-blue-500/10 text-blue-400 border border-blue-500/10 rounded-2xl text-[10px] font-black uppercase hover:bg-blue-500 hover:text-white transition-all">
                      <RefreshCw size={14} /> Reset
                    </button>
                  </div>
                </div>

                <div className="flex items-center justify-between pt-4 border-t border-white/5">
                  <button onClick={() => setSelectedFamily(family)}
                    className="flex items-center gap-2 px-4 py-2 bg-amber-500/10 text-amber-400 text-[10px] font-black uppercase tracking-widest rounded-xl hover:bg-amber-500 hover:text-white transition-all">
                    <Info size={14} /> Manage
                  </button>
                  <button onClick={() => handleDisband(family)}
                    className="p-2.5 text-slate-500 hover:text-red-500 transition-colors">
                    <Trash2 size={20} />
                  </button>
                </div>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </div>
  );
};

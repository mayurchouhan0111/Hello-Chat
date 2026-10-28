import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { collection, query, getDocs, doc, updateDoc, arrayUnion, arrayRemove } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { listScopedUsers, asDocList } from '../lib/scopedUsers';
import { 
  ShieldCheck, 
  Users, 
  UserPlus, 
  Search, 
  Trash2, 
  RefreshCw, 
  Building2, 
  CheckCircle, 
  AlertCircle, 
  X, 
  ArrowRightLeft, 
  ShieldAlert, 
  Check, 
  Clock 
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
import { motion, AnimatePresence } from 'framer-motion';

export const AdminManagement = () => {
  const { userData: currentUser, isOwner, isSuperAdmin, branchId, user: authUser } = useAdmin();
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [actionMessage, setActionMessage] = useState({ text: '', type: '' });

  // Appoint Admin Modal
  const [showAppointModal, setShowAppointModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearchingUser, setIsSearchingUser] = useState(false);
  const [foundUser, setFoundUser] = useState(null);
  const [searchError, setSearchError] = useState('');
  const [isAppointing, setIsAppointing] = useState(false);

  // Replace Admin Modal
  const [replacingAdmin, setReplacingAdmin] = useState(null);
  const [replaceQuery, setReplaceQuery] = useState('');
  const [isSearchingReplace, setIsSearchingReplace] = useState(false);
  const [foundReplaceUser, setFoundReplaceUser] = useState(null);
  const [replaceError, setReplaceError] = useState('');
  const [isReplacing, setIsReplacing] = useState(false);

  useEffect(() => {
    fetchAdmins();
  }, [isOwner, isSuperAdmin, branchId]);

  const showToast = (text, type = 'success') => {
    setActionMessage({ text, type });
    setTimeout(() => setActionMessage({ text: '', type: '' }), 4500);
  };

  // Agency Override States
  const [allowAgencyOverride, setAllowAgencyOverride] = useState(false);
  const [overrideReason, setOverrideReason] = useState('');
  const [showAgencyConflictModal, setShowAgencyConflictModal] = useState(false);

  const [allowReplaceOverride, setAllowReplaceOverride] = useState(false);
  const [replaceOverrideReason, setReplaceOverrideReason] = useState('');
  const [showReplaceAgencyConflictModal, setShowReplaceAgencyConflictModal] = useState(false);

  const fetchAdmins = async () => {
    setLoading(true);
    try {
      const listFn = httpsCallable(functions, 'listBranchAdmins');
      const res = await listFn({ pageSize: 100 });
      setAdmins(res.data.admins || []);
    } catch (err) {
      console.error("Error fetching branch admins:", err);
      // Fallback for offline/unauthenticated dev state
      showToast("Failed to load branch admins: " + (err.message || err), 'error');
    } finally {
      setLoading(false);
    }
  };

  // Search candidate user for appointment
  const handleSearchUser = async (e) => {
    if (e) e.preventDefault();
    const q = searchQuery.trim();
    if (!q) return;

    setIsSearchingUser(true);
    setFoundUser(null);
    setSearchError('');

    try {
      const allUsers = asDocList(await listScopedUsers(1000));
      const numQ = Number(q);
      const match = allUsers.find(u => 
        u.id === q || 
        u.uid === q || 
        (numQ && (u.helloId === numQ || Number(u.displayId) === numQ)) ||
        (u.username && u.username.toLowerCase() === q.toLowerCase()) ||
        (u.displayName && u.displayName.toLowerCase().includes(q.toLowerCase()))
      );

      if (match) {
        setFoundUser(match);
      } else {
        // Direct search fallback
        setFoundUser({ id: q, uid: q, displayName: `Candidate (ID: ${q})`, helloId: numQ || q });
      }
    } catch (err) {
      setSearchError('Error searching user: ' + err.message);
    } finally {
      setIsSearchingUser(false);
    }
  };

  // Execute Appoint Admin via dedicated callable
  const handleAppointAdmin = async (forceOverride = false) => {
    if (!foundUser) return;
    setIsAppointing(true);
    try {
      const targetIdentifier = String(foundUser.helloId || foundUser.displayId || foundUser.uid || foundUser.id);
      const appointFn = httpsCallable(functions, 'appointAdmin');
      
      await appointFn({
        targetIdentifier,
        allowAgencyOverride: forceOverride || allowAgencyOverride,
        overrideReason: overrideReason || 'Authorized by Super Admin via Admin Panel',
      });

      showToast(`✅ Successfully appointed ${foundUser.displayName || foundUser.username} as Admin!`);
      setShowAppointModal(false);
      setShowAgencyConflictModal(false);
      setFoundUser(null);
      setSearchQuery('');
      setAllowAgencyOverride(false);
      setOverrideReason('');
      fetchAdmins();
    } catch (err) {
      console.error("Appoint admin error:", err);
      if (err.message && err.message.includes("active Agency Owner")) {
        setShowAgencyConflictModal(true);
      } else {
        showToast("Failed to appoint admin: " + (err.message || err), 'error');
      }
    } finally {
      setIsAppointing(false);
    }
  };

  // Search candidate for replacement
  const handleSearchReplaceUser = async (e) => {
    if (e) e.preventDefault();
    const q = replaceQuery.trim();
    if (!q) return;

    setIsSearchingReplace(true);
    setFoundReplaceUser(null);
    setReplaceError('');

    try {
      const allUsers = asDocList(await listScopedUsers(1000));
      const numQ = Number(q);
      const match = allUsers.find(u => 
        (u.id === q || u.uid === q || 
        (numQ && (u.helloId === numQ || Number(u.displayId) === numQ)) ||
        (u.username && u.username.toLowerCase() === q.toLowerCase())) &&
        u.id !== (replacingAdmin.id || replacingAdmin.uid)
      );

      if (match) {
        setFoundReplaceUser(match);
      } else {
        setFoundReplaceUser({ id: q, uid: q, displayName: `Candidate (ID: ${q})`, helloId: numQ || q });
      }
    } catch (err) {
      setReplaceError('Error searching replacement candidate: ' + err.message);
    } finally {
      setIsSearchingReplace(false);
    }
  };

  // Execute Atomic Replace Admin via dedicated callable
  const handleExecuteReplace = async (forceOverride = false) => {
    if (!replacingAdmin || !foundReplaceUser) return;
    setIsReplacing(true);
    try {
      const oldUid = replacingAdmin.id || replacingAdmin.uid;
      const newTargetIdentifier = String(foundReplaceUser.helloId || foundReplaceUser.displayId || foundReplaceUser.uid || foundReplaceUser.id);

      const replaceFn = httpsCallable(functions, 'replaceAdmin');
      await replaceFn({
        oldAdminUid: oldUid,
        newTargetIdentifier,
        allowAgencyOverride: forceOverride || allowReplaceOverride,
        overrideReason: replaceOverrideReason || 'Admin replacement authorized by Super Admin',
      });

      showToast(`✅ Successfully replaced Admin ${replacingAdmin.displayName} with ${foundReplaceUser.displayName}!`);
      setReplacingAdmin(null);
      setFoundReplaceUser(null);
      setReplaceQuery('');
      setShowReplaceAgencyConflictModal(false);
      setAllowReplaceOverride(false);
      setReplaceOverrideReason('');
      fetchAdmins();
    } catch (err) {
      console.error("Replace admin error:", err);
      if (err.message && err.message.includes("active Agency Owner")) {
        setShowReplaceAgencyConflictModal(true);
      } else {
        showToast("Failed to replace admin: " + (err.message || err), 'error');
      }
    } finally {
      setIsReplacing(false);
    }
  };

  // Revoke Admin Role via dedicated callable (demotes & revokes tokens immediately)
  const handleRevokeAdmin = async (adminUser) => {
    const adminName = adminUser.displayName || adminUser.username || 'this user';
    if (!window.confirm(`Are you sure you want to revoke Admin privileges from ${adminName}?\n\nTheir previous role will be restored, administrative claims deleted, and login tokens revoked immediately.`)) {
      return;
    }

    try {
      const targetUid = adminUser.id || adminUser.uid;
      const removeFn = httpsCallable(functions, 'removeAdmin');
      await removeFn({
        targetUid,
        reason: 'Revoked by Super Admin via Admin Panel'
      });

      showToast(`✅ Revoked Admin role and access tokens from ${adminName}`);
      fetchAdmins();
    } catch (err) {
      console.error("Revoke error:", err);
      showToast("Failed to revoke admin: " + (err.message || err), 'error');
    }
  };

  const filteredAdmins = admins.filter(a => {
    if (!searchTerm) return true;
    const q = searchTerm.toLowerCase();
    const name = (a.displayName || a.username || '').toLowerCase();
    const helloId = String(a.helloId || '');
    const uid = (a.uid || a.id || '').toLowerCase();
    return name.includes(q) || helloId.includes(q) || uid.includes(q);
  });

  return (
    <div className="space-y-8 animate-fade-in pb-16">
      {/* Toast Alert */}
      <AnimatePresence>
        {actionMessage.text && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className={`p-4 rounded-2xl flex items-center gap-3 border shadow-xl ${
              actionMessage.type === 'error'
                ? 'bg-red-500/10 border-red-500/20 text-red-400'
                : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
            }`}
          >
            {actionMessage.type === 'error' ? <AlertCircle size={20} /> : <CheckCircle size={20} />}
            <span className="font-bold text-sm tracking-tight">{actionMessage.text}</span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Header Bar */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6 bg-[#121214] border border-white/[0.04] p-8 rounded-[32px] shadow-2xl relative overflow-hidden">
        <div className="absolute top-0 right-0 w-96 h-96 bg-[#6366F1]/5 rounded-full blur-3xl pointer-events-none" />
        <div>
          <div className="flex items-center gap-3">
            <div className="p-3 bg-[#6366F1]/10 text-[#818CF8] rounded-2xl border border-[#6366F1]/20">
              <ShieldCheck size={28} />
            </div>
            <div>
              <h1 className="text-3xl font-black text-white tracking-tight">Admin Management</h1>
              <p className="text-gray-400 text-sm mt-1">
                Appoint, manage, and supervise branch administrators within authorized hierarchy
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchAdmins}
            disabled={loading}
            className="p-3.5 bg-white/[0.03] hover:bg-white/[0.06] border border-white/[0.05] rounded-2xl text-gray-300 hover:text-white transition-all disabled:opacity-50"
            title="Refresh Admins"
          >
            <RefreshCw size={18} className={loading ? 'animate-spin' : ''} />
          </button>
          <button
            onClick={() => {
              setFoundUser(null);
              setSearchQuery('');
              setSearchError('');
              setShowAppointModal(true);
            }}
            className="flex items-center gap-2.5 px-6 py-3.5 bg-gradient-to-r from-[#6366F1] to-[#4F46E5] hover:opacity-90 text-white rounded-2xl font-bold text-sm tracking-tight shadow-lg shadow-[#6366F1]/20 transition-all cursor-pointer"
          >
            <UserPlus size={18} />
            <span>Appoint Admin</span>
          </button>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-[#121214] border border-white/[0.04] p-6 rounded-[24px]">
          <div className="flex items-center justify-between">
            <span className="text-xs font-black text-gray-400 uppercase tracking-widest">Total Admins</span>
            <div className="p-2.5 bg-indigo-500/10 text-indigo-400 rounded-xl">
              <Users size={18} />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-3xl font-black text-white">{admins.length}</div>
            <p className="text-xs text-gray-500 mt-1">Supervising assigned branch operations</p>
          </div>
        </div>

        <div className="bg-[#121214] border border-white/[0.04] p-6 rounded-[24px]">
          <div className="flex items-center justify-between">
            <span className="text-xs font-black text-gray-400 uppercase tracking-widest">Authority Scope</span>
            <div className="p-2.5 bg-emerald-500/10 text-emerald-400 rounded-xl">
              <Building2 size={18} />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-white truncate">
              {isOwner ? 'All Branches (Owner)' : (branchId || currentUser?.branchId || 'Branch Prod 1')}
            </div>
            <p className="text-xs text-gray-500 mt-1">Enforced cross-branch sandboxing</p>
          </div>
        </div>

        <div className="bg-[#121214] border border-white/[0.04] p-6 rounded-[24px]">
          <div className="flex items-center justify-between">
            <span className="text-xs font-black text-gray-400 uppercase tracking-widest">Tier Level</span>
            <div className="p-2.5 bg-purple-500/10 text-purple-400 rounded-xl">
              <ShieldCheck size={18} />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-white">
              {isOwner ? 'Tier 4 (Owner)' : 'Tier 3 (Super Admin)'}
            </div>
            <p className="text-xs text-gray-500 mt-1">Direct supervisory privileges</p>
          </div>
        </div>

        <div className="bg-[#121214] border border-white/[0.04] p-6 rounded-[24px]">
          <div className="flex items-center justify-between">
            <span className="text-xs font-black text-gray-400 uppercase tracking-widest">Security Status</span>
            <div className="p-2.5 bg-amber-500/10 text-amber-400 rounded-xl">
              <ShieldAlert size={18} />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-emerald-400">Isolated & Sandboxed</div>
            <p className="text-xs text-gray-500 mt-1">Horizontal data protection active</p>
          </div>
        </div>
      </div>

      {/* Search & List Section */}
      <div className="bg-[#121214] border border-white/[0.04] rounded-[32px] overflow-hidden shadow-2xl">
        <div className="p-6 border-b border-white/[0.04] flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="relative w-full md:w-96">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-500" size={18} />
            <input
              type="text"
              placeholder="Search by Admin name, Hello ID, or UID..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full bg-[#18181B] border border-white/[0.06] rounded-2xl pl-12 pr-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-[#6366F1] transition-all"
            />
          </div>
          <div className="text-xs font-bold text-gray-400">
            Showing <span className="text-white font-black">{filteredAdmins.length}</span> of {admins.length} Admins
          </div>
        </div>

        {loading ? (
          <div className="p-16 text-center">
            <div className="w-10 h-10 border-2 border-[#6366F1] border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-gray-400 font-bold text-sm">Loading Branch Admins...</p>
          </div>
        ) : filteredAdmins.length === 0 ? (
          <div className="p-16 text-center">
            <div className="w-16 h-16 bg-white/[0.02] border border-white/[0.05] rounded-3xl flex items-center justify-center mx-auto mb-4 text-gray-600">
              <Users size={32} />
            </div>
            <h3 className="text-lg font-bold text-white">No Branch Admins Found</h3>
            <p className="text-gray-500 text-sm mt-1 max-w-md mx-auto">
              {searchTerm 
                ? `No admin matching "${searchTerm}". Try a different keyword.` 
                : 'No Admins have been appointed under your branch supervision yet.'}
            </p>
            {!searchTerm && (
              <button
                onClick={() => setShowAppointModal(true)}
                className="mt-6 px-6 py-3 bg-[#6366F1] hover:bg-[#4F46E5] text-white rounded-2xl font-bold text-sm inline-flex items-center gap-2 transition-all cursor-pointer"
              >
                <UserPlus size={16} />
                <span>Appoint First Admin</span>
              </button>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-white/[0.04] bg-white/[0.01]">
                  <th className="py-4 px-6 text-[10px] font-black tracking-widest text-gray-400 uppercase">Admin User</th>
                  <th className="py-4 px-6 text-[10px] font-black tracking-widest text-gray-400 uppercase">Hello ID</th>
                  <th className="py-4 px-6 text-[10px] font-black tracking-widest text-gray-400 uppercase">Branch Scope</th>
                  <th className="py-4 px-6 text-[10px] font-black tracking-widest text-gray-400 uppercase">Super Admin</th>
                  <th className="py-4 px-6 text-[10px] font-black tracking-widest text-gray-400 uppercase">Role Badge</th>
                  <th className="py-4 px-6 text-[10px] font-black tracking-widest text-gray-400 uppercase text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/[0.03]">
                {filteredAdmins.map((adminUser) => {
                  const uid = adminUser.id || adminUser.uid;
                  const name = adminUser.displayName || adminUser.username || 'Admin User';
                  const photo = adminUser.profilePhotoUrl || '';
                  const helloId = adminUser.helloId || adminUser.displayId || 'N/A';
                  const adminBranch = adminUser.branchId || branchId || 'branch-prod-1';
                  const superAdmin = adminUser.superAdminId || 'Super Admin';

                  return (
                    <tr key={uid} className="hover:bg-white/[0.02] transition-colors group">
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="w-11 h-11 rounded-2xl bg-[#1A1A1E] border border-white/[0.08] overflow-hidden flex items-center justify-center font-bold text-white text-sm">
                            {photo ? (
                              <img src={photo} alt={name} className="w-full h-full object-cover" />
                            ) : (
                              name.charAt(0).toUpperCase()
                            )}
                          </div>
                          <div>
                            <div className="font-bold text-white text-sm">{name}</div>
                            <div className="text-[11px] font-mono text-gray-500 truncate max-w-[140px]">{uid}</div>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-6">
                        <span className="font-mono font-bold text-white text-sm">{helloId}</span>
                        {adminUser.roleCode && (
                          <div className="text-[11px] font-mono font-bold text-[#818CF8] mt-0.5">
                            Code: #{adminUser.roleCode}
                          </div>
                        )}
                      </td>
                      <td className="py-4 px-6">
                        <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-white/[0.04] border border-white/[0.06] rounded-xl text-xs font-bold text-gray-300">
                          <Building2 size={12} className="text-gray-400" />
                          {adminBranch}
                        </span>
                      </td>
                      <td className="py-4 px-6">
                        <span className="text-xs text-gray-400 font-mono truncate block max-w-[120px]">
                          {superAdmin}
                        </span>
                      </td>
                      <td className="py-4 px-6">
                        <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-[#6366F1]/10 border border-[#6366F1]/30 text-[#818CF8] rounded-xl text-xs font-bold">
                          <ShieldCheck size={13} />
                          ADMIN
                        </span>
                      </td>
                      <td className="py-4 px-6 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => {
                              setReplacingAdmin(adminUser);
                              setFoundReplaceUser(null);
                              setReplaceQuery('');
                              setReplaceError('');
                            }}
                            className="px-3 py-1.5 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 border border-amber-500/20 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all cursor-pointer"
                            title="Replace this Admin with another user"
                          >
                            <ArrowRightLeft size={13} />
                            <span>Replace</span>
                          </button>
                          <button
                            onClick={() => handleRevokeAdmin(adminUser)}
                            className="p-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/20 rounded-xl text-xs font-bold transition-all cursor-pointer"
                            title="Revoke Admin privileges"
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Appoint Admin Modal */}
      <AnimatePresence>
        {showAppointModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-[#121214] border border-white/[0.08] w-full max-w-lg rounded-[32px] p-8 shadow-2xl relative"
            >
              <button
                onClick={() => setShowAppointModal(false)}
                className="absolute top-6 right-6 p-2 text-gray-400 hover:text-white rounded-xl hover:bg-white/[0.05] transition-all"
              >
                <X size={20} />
              </button>

              <div className="flex items-center gap-3 mb-6">
                <div className="p-3 bg-[#6366F1]/10 text-[#818CF8] rounded-2xl border border-[#6366F1]/20">
                  <UserPlus size={24} />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white">Appoint Branch Admin</h2>
                  <p className="text-gray-400 text-xs mt-0.5">
                    Assign a user to supervise agencies & staff for Branch {branchId || 'branch-prod-1'}
                  </p>
                </div>
              </div>

              {/* User search */}
              <form onSubmit={handleSearchUser} className="space-y-4">
                <label className="text-xs font-black text-gray-400 uppercase tracking-widest block">
                  Find Candidate User
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    placeholder="Enter Hello ID, UID, or Username..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="flex-1 bg-[#18181B] border border-white/[0.08] rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-[#6366F1]"
                  />
                  <button
                    type="submit"
                    disabled={isSearchingUser}
                    className="px-5 py-3 bg-[#6366F1] hover:bg-[#4F46E5] text-white rounded-2xl font-bold text-sm tracking-tight transition-all disabled:opacity-50 cursor-pointer"
                  >
                    {isSearchingUser ? <RefreshCw size={16} className="animate-spin" /> : 'Search'}
                  </button>
                </div>
              </form>

              {searchError && (
                <div className="mt-4 p-3.5 bg-red-500/10 border border-red-500/20 text-red-400 rounded-2xl text-xs font-bold flex items-center gap-2">
                  <AlertCircle size={16} />
                  <span>{searchError}</span>
                </div>
              )}

              {/* Found user preview card */}
              {foundUser && (
                <div className="mt-6 p-5 bg-[#18181B] border border-white/[0.06] rounded-2xl space-y-4">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 rounded-2xl bg-black border border-white/[0.1] overflow-hidden flex items-center justify-center font-bold text-white text-lg">
                      {foundUser.profilePhotoUrl ? (
                        <img src={foundUser.profilePhotoUrl} alt="" className="w-full h-full object-cover" />
                      ) : (
                        (foundUser.displayName || 'U').charAt(0).toUpperCase()
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-bold text-white text-base truncate">
                        {foundUser.displayName || foundUser.username || 'User'}
                      </div>
                      <div className="text-xs text-gray-400 font-mono mt-0.5">
                        Hello ID: <span className="text-white font-bold">{foundUser.helloId || 'N/A'}</span>
                      </div>
                      <div className="text-xs text-gray-400 font-mono">
                        Current Role: <span className="text-amber-400 font-bold uppercase">{foundUser.role || 'user'}</span>
                      </div>
                    </div>
                  </div>

                  <div className="pt-3 border-t border-white/[0.04] flex items-center justify-between text-xs text-gray-400">
                    <span>Target Branch: <b className="text-white">{branchId || 'branch-prod-1'}</b></span>
                    <span>Rank: <b className="text-[#818CF8]">Tier 2 (Admin)</b></span>
                  </div>

                  <button
                    onClick={handleAppointAdmin}
                    disabled={isAppointing}
                    className="w-full py-3.5 bg-gradient-to-r from-emerald-500 to-teal-600 hover:opacity-90 text-white rounded-2xl font-bold text-sm tracking-tight shadow-lg shadow-emerald-500/20 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    {isAppointing ? (
                      <RefreshCw size={18} className="animate-spin" />
                    ) : (
                      <>
                        <Check size={18} />
                        <span>Confirm Admin Appointment</span>
                      </>
                    )}
                  </button>
                </div>
              )}
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Replace Admin Modal */}
      <AnimatePresence>
        {replacingAdmin && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-[#121214] border border-white/[0.08] w-full max-w-lg rounded-[32px] p-8 shadow-2xl relative"
            >
              <button
                onClick={() => setReplacingAdmin(null)}
                className="absolute top-6 right-6 p-2 text-gray-400 hover:text-white rounded-xl hover:bg-white/[0.05] transition-all"
              >
                <X size={20} />
              </button>

              <div className="flex items-center gap-3 mb-6">
                <div className="p-3 bg-amber-500/10 text-amber-400 rounded-2xl border border-amber-500/20">
                  <ArrowRightLeft size={24} />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white">Replace Branch Admin</h2>
                  <p className="text-gray-400 text-xs mt-0.5">
                    Transition administrative supervision to a new eligible user
                  </p>
                </div>
              </div>

              {/* Current Admin Notice */}
              <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl mb-4">
                <div className="text-xs text-red-300 font-bold">Admin Being Replaced:</div>
                <div className="text-white font-bold text-sm mt-1">{replacingAdmin.displayName || replacingAdmin.username}</div>
                <div className="text-gray-400 text-xs font-mono">UID: {replacingAdmin.id || replacingAdmin.uid}</div>
              </div>

              {/* Search new replacement user */}
              <form onSubmit={handleSearchReplaceUser} className="space-y-4">
                <label className="text-xs font-black text-gray-400 uppercase tracking-widest block">
                  Find Replacement Candidate
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    placeholder="Enter candidate's Hello ID, UID, or Username..."
                    value={replaceQuery}
                    onChange={(e) => setReplaceQuery(e.target.value)}
                    className="flex-1 bg-[#18181B] border border-white/[0.08] rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-amber-400"
                  />
                  <button
                    type="submit"
                    disabled={isSearchingReplace}
                    className="px-5 py-3 bg-amber-500 hover:bg-amber-600 text-black rounded-2xl font-bold text-sm tracking-tight transition-all disabled:opacity-50 cursor-pointer"
                  >
                    {isSearchingReplace ? <RefreshCw size={16} className="animate-spin" /> : 'Search'}
                  </button>
                </div>
              </form>

              {replaceError && (
                <div className="mt-4 p-3.5 bg-red-500/10 border border-red-500/20 text-red-400 rounded-2xl text-xs font-bold flex items-center gap-2">
                  <AlertCircle size={16} />
                  <span>{replaceError}</span>
                </div>
              )}

              {/* Found replacement candidate preview */}
              {foundReplaceUser && (
                <div className="mt-6 p-5 bg-[#18181B] border border-white/[0.06] rounded-2xl space-y-4">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 rounded-2xl bg-black border border-white/[0.1] overflow-hidden flex items-center justify-center font-bold text-white text-lg">
                      {foundReplaceUser.profilePhotoUrl ? (
                        <img src={foundReplaceUser.profilePhotoUrl} alt="" className="w-full h-full object-cover" />
                      ) : (
                        (foundReplaceUser.displayName || 'U').charAt(0).toUpperCase()
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-bold text-white text-base truncate">
                        {foundReplaceUser.displayName || foundReplaceUser.username || 'User'}
                      </div>
                      <div className="text-xs text-gray-400 font-mono mt-0.5">
                        Hello ID: <span className="text-white font-bold">{foundReplaceUser.helloId || 'N/A'}</span>
                      </div>
                      <div className="text-xs text-gray-400 font-mono">
                        Current Role: <span className="text-emerald-400 font-bold uppercase">{foundReplaceUser.role || 'user'}</span>
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={handleExecuteReplace}
                    disabled={isReplacing}
                    className="w-full py-3.5 bg-gradient-to-r from-amber-500 to-orange-500 hover:opacity-90 text-black rounded-2xl font-black text-sm tracking-tight shadow-lg shadow-amber-500/20 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    {isReplacing ? (
                      <RefreshCw size={18} className="animate-spin" />
                    ) : (
                      <>
                        <Check size={18} />
                        <span>Confirm Admin Replacement</span>
                      </>
                    )}
                  </button>
                </div>
              )}
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

import { useState, useEffect, useCallback } from 'react';
import { functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { 
  ShieldCheck, 
  Users, 
  UserPlus, 
  Search, 
  Trash2, 
  RefreshCw, 
  Building2, 
  AlertCircle, 
  X, 
  ArrowRightLeft, 
  ShieldAlert, 
  Check
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
// eslint-disable-next-line no-unused-vars
import { motion, AnimatePresence } from 'framer-motion';

// Map Firebase callable error codes and messages to human-friendly text
const formatAdminError = (err) => {
  const msg = err?.message || String(err || '');
  if (msg.includes('active Agency Owner')) {
    return 'Target user is an active Agency Owner. Appointing them creates a role conflict unless an agency override is authorized.';
  }
  if (msg.includes('not-found') || msg.includes('not found')) {
    return 'User record could not be found. Please double-check the Hello ID or UID.';
  }
  if (msg.includes('permission-denied') || msg.includes('Permission')) {
    return 'Permission denied: Only Super Admins or Owners may manage branch Admins.';
  }
  if (msg.includes('belongs to another branch')) {
    return 'Hierarchy violation: Candidate belongs to another branch.';
  }
  if (msg.includes('resource-exhausted') || msg.includes('code space exhausted')) {
    return 'Admin capacity limit reached: No 5-digit admin role codes are currently available.';
  }
  if (msg.includes('already an Admin')) {
    return 'User is already an appointed Admin in this branch.';
  }
  return msg || 'An unexpected error occurred. Please try again.';
};

export const AdminManagement = () => {
  const { isOwner, isSuperAdmin, branchId } = useAdmin();
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

  // Agency Override States
  const [allowAgencyOverride, setAllowAgencyOverride] = useState(false);
  const [overrideReason, setOverrideReason] = useState('');

  // Replace Admin Modal
  const [replacingAdmin, setReplacingAdmin] = useState(null);
  const [replaceQuery, setReplaceQuery] = useState('');
  const [isSearchingReplace, setIsSearchingReplace] = useState(false);
  const [foundReplaceUser, setFoundReplaceUser] = useState(null);
  const [replaceError, setReplaceError] = useState('');
  const [isReplacing, setIsReplacing] = useState(false);
  const [allowReplaceOverride, setAllowReplaceOverride] = useState(false);
  const [replaceOverrideReason, setReplaceOverrideReason] = useState('');

  const showToast = (text, type = 'success') => {
    setActionMessage({ text, type });
    setTimeout(() => setActionMessage({ text: '', type: '' }), 4500);
  };

  const fetchAdmins = useCallback(async () => {
    setLoading(true);
    try {
      const listFn = httpsCallable(functions, 'listBranchAdmins');
      const res = await listFn({ pageSize: 100 });
      setAdmins(res.data?.admins || []);
    } catch (err) {
      console.error('Error fetching branch admins:', err);
      showToast('Failed to load branch admins: ' + formatAdminError(err), 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAdmins();
  }, [fetchAdmins, isOwner, isSuperAdmin, branchId]);

  // Server-side candidate validation before appointing
  const handleSearchUser = async (e) => {
    if (e) e.preventDefault();
    const q = searchQuery.trim();
    if (!q) return;

    setIsSearchingUser(true);
    setFoundUser(null);
    setSearchError('');
    setAllowAgencyOverride(false);
    setOverrideReason('');

    try {
      const valFn = httpsCallable(functions, 'validateCandidate');
      const res = await valFn({ targetIdentifier: q, action: 'appoint_admin' });
      if (!res.data?.valid) {
        setSearchError(res.data?.error || 'Candidate is not eligible for appointment.');
        return;
      }

      setFoundUser(res.data.candidate);
      if (res.data.requiresOverride) {
        setAllowAgencyOverride(true);
        setOverrideReason('Authorized agency owner transition to admin role');
      }
    } catch (err) {
      setSearchError('Error validating candidate: ' + formatAdminError(err));
    } finally {
      setIsSearchingUser(false);
    }
  };

  // Execute Appoint Admin via dedicated callable
  const handleAppointAdmin = async () => {
    if (!foundUser) return;
    setIsAppointing(true);
    try {
      const targetIdentifier = String(foundUser.helloId || foundUser.displayId || foundUser.uid || foundUser.id);
      const appointFn = httpsCallable(functions, 'appointAdmin');
      
      await appointFn({
        targetIdentifier,
        allowAgencyOverride,
        overrideReason: overrideReason || 'Authorized by Super Admin via Admin Panel',
      });

      showToast(`✅ Successfully appointed ${foundUser.displayName || foundUser.username} as Admin!`);
      setShowAppointModal(false);
      setFoundUser(null);
      setSearchQuery('');
      setAllowAgencyOverride(false);
      setOverrideReason('');
      fetchAdmins();
    } catch (err) {
      console.error('Appoint admin error:', err);
      showToast('Failed to appoint admin: ' + formatAdminError(err), 'error');
    } finally {
      setIsAppointing(false);
    }
  };

  // Search candidate for replacement with server-side validation
  const handleSearchReplaceUser = async (e) => {
    if (e) e.preventDefault();
    const q = replaceQuery.trim();
    if (!q) return;

    setIsSearchingReplace(true);
    setFoundReplaceUser(null);
    setReplaceError('');
    setAllowReplaceOverride(false);
    setReplaceOverrideReason('');

    try {
      const valFn = httpsCallable(functions, 'validateCandidate');
      const res = await valFn({ targetIdentifier: q, action: 'replace_admin' });
      if (!res.data?.valid) {
        setReplaceError(res.data?.error || 'Replacement candidate is not eligible.');
        return;
      }

      const cand = res.data.candidate;
      if (cand.uid === (replacingAdmin?.id || replacingAdmin?.uid)) {
        setReplaceError('Candidate cannot be the same user as the admin being replaced.');
        return;
      }

      setFoundReplaceUser(cand);
      if (res.data.requiresOverride) {
        setAllowReplaceOverride(true);
        setReplaceOverrideReason('Agency Owner override authorized for Admin replacement');
      }
    } catch (err) {
      setReplaceError('Error validating replacement candidate: ' + formatAdminError(err));
    } finally {
      setIsSearchingReplace(false);
    }
  };

  // Execute Atomic Replace Admin via dedicated callable
  const handleExecuteReplace = async () => {
    if (!replacingAdmin || !foundReplaceUser) return;
    setIsReplacing(true);
    try {
      const oldUid = replacingAdmin.id || replacingAdmin.uid;
      const newTargetIdentifier = String(foundReplaceUser.helloId || foundReplaceUser.displayId || foundReplaceUser.uid || foundReplaceUser.id);

      const replaceFn = httpsCallable(functions, 'replaceAdmin');
      await replaceFn({
        oldAdminUid: oldUid,
        newTargetIdentifier,
        allowAgencyOverride: allowReplaceOverride,
        overrideReason: replaceOverrideReason || 'Admin replacement authorized by Super Admin',
      });

      showToast(`✅ Successfully replaced Admin ${replacingAdmin.displayName} with ${foundReplaceUser.displayName}!`);
      setReplacingAdmin(null);
      setFoundReplaceUser(null);
      setReplaceQuery('');
      setAllowReplaceOverride(false);
      setReplaceOverrideReason('');
      fetchAdmins();
    } catch (err) {
      console.error('Replace admin error:', err);
      showToast('Failed to replace admin: ' + formatAdminError(err), 'error');
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
      console.error('Revoke error:', err);
      showToast('Failed to revoke admin: ' + formatAdminError(err), 'error');
    }
  };

  const filteredAdmins = admins.filter(a => {
    const q = searchTerm.toLowerCase();
    return (
      (a.displayName && a.displayName.toLowerCase().includes(q)) ||
      (a.username && a.username.toLowerCase().includes(q)) ||
      (a.uid && a.uid.toLowerCase().includes(q)) ||
      (a.helloId && String(a.helloId).includes(q)) ||
      (a.roleCode && String(a.roleCode).includes(q))
    );
  });

  return (
    <div className="space-y-8 animate-fade-in text-white pb-20">
      {/* Toast Notification */}
      <AnimatePresence>
        {actionMessage.text && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className={`fixed top-8 right-8 z-50 px-6 py-4 rounded-2xl shadow-2xl flex items-center gap-3 border text-sm font-bold ${
              actionMessage.type === 'error'
                ? 'bg-red-500/20 border-red-500/40 text-red-200 backdrop-blur-xl'
                : 'bg-emerald-500/20 border-emerald-500/40 text-emerald-200 backdrop-blur-xl'
            }`}
          >
            {actionMessage.type === 'error' ? <ShieldAlert size={20} /> : <ShieldCheck size={20} />}
            <span>{actionMessage.text}</span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-[#6366F1]/10 border border-[#6366F1]/20 rounded-full text-[#818CF8] text-xs font-black uppercase tracking-widest mb-3">
            <Building2 size={14} />
            Branch Supervision • {branchId || 'Global / Owner'}
          </div>
          <h1 className="text-3xl md:text-4xl font-black text-white tracking-tight flex items-center gap-3">
            Admin Management
          </h1>
          <p className="text-gray-400 text-sm mt-1 max-w-2xl">
            Supervise and appoint branch administrators. Admins possess Tier 2 authority over agencies and hosts within your branch.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => fetchAdmins()}
            disabled={loading}
            className="p-3 bg-white/[0.03] hover:bg-white/[0.08] border border-white/[0.06] rounded-2xl text-gray-300 hover:text-white transition-all cursor-pointer disabled:opacity-50"
            title="Refresh list"
          >
            <RefreshCw size={18} className={loading ? 'animate-spin' : ''} />
          </button>

          <button
            onClick={() => {
              setShowAppointModal(true);
              setFoundUser(null);
              setSearchQuery('');
              setSearchError('');
            }}
            className="px-6 py-3.5 bg-gradient-to-r from-[#6366F1] to-[#4F46E5] hover:opacity-90 text-white rounded-2xl font-bold text-sm tracking-tight shadow-lg shadow-[#6366F1]/25 flex items-center gap-2 transition-all cursor-pointer"
          >
            <UserPlus size={18} />
            <span>Appoint Admin</span>
          </button>
        </div>
      </div>

      {/* Admins Table Card */}
      <div className="bg-[#121214] border border-white/[0.06] rounded-[32px] overflow-hidden shadow-2xl">
        <div className="p-6 border-b border-white/[0.04] flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-500" size={18} />
            <input
              type="text"
              placeholder="Filter by name, hello ID, role code, or UID..."
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
                className="absolute top-6 right-6 p-2 text-gray-400 hover:text-white rounded-xl hover:bg-white/[0.05] transition-all cursor-pointer"
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
                    Assign a validated candidate to supervise agencies & staff for Branch {branchId || 'Current Branch'}
                  </p>
                </div>
              </div>

              {/* User search */}
              <form onSubmit={handleSearchUser} className="space-y-4">
                <label className="text-xs font-black text-gray-400 uppercase tracking-widest block">
                  Find Candidate User (Hello ID or UID)
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    placeholder="Enter Hello ID or User UID..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="flex-1 bg-[#18181B] border border-white/[0.08] rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-[#6366F1]"
                  />
                  <button
                    type="submit"
                    disabled={isSearchingUser}
                    className="px-5 py-3 bg-[#6366F1] hover:bg-[#4F46E5] text-white rounded-2xl font-bold text-sm tracking-tight transition-all disabled:opacity-50 cursor-pointer"
                  >
                    {isSearchingUser ? <RefreshCw size={16} className="animate-spin" /> : 'Validate'}
                  </button>
                </div>
              </form>

              {searchError && (
                <div className="mt-4 p-3.5 bg-red-500/10 border border-red-500/20 text-red-400 rounded-2xl text-xs font-bold flex items-center gap-2">
                  <AlertCircle size={16} />
                  <span>{searchError}</span>
                </div>
              )}

              {/* Found user preview card - Only enabled when validated by server */}
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
                        {foundUser.displayName || foundUser.username || 'Candidate'}
                      </div>
                      <div className="text-xs text-gray-400 font-mono mt-0.5">
                        Hello ID: <span className="text-white font-bold">{foundUser.helloId || 'N/A'}</span>
                      </div>
                      <div className="text-xs text-gray-400 font-mono">
                        Current Role: <span className="text-amber-400 font-bold uppercase">{foundUser.role || 'user'}</span>
                      </div>
                    </div>
                  </div>

                  {allowAgencyOverride && (
                    <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl space-y-2">
                      <div className="flex items-center gap-2 text-xs font-bold text-amber-400">
                        <AlertCircle size={14} />
                        <span>Agency Owner Conflict Detected</span>
                      </div>
                      <p className="text-[11px] text-gray-300">
                        This candidate currently owns an active Agency. Authorizing this appointment will transition them to Admin and require an override reason.
                      </p>
                      <input
                        type="text"
                        placeholder="Reason for overriding agency ownership..."
                        value={overrideReason}
                        onChange={(e) => setOverrideReason(e.target.value)}
                        className="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-1.5 text-xs text-white"
                      />
                    </div>
                  )}

                  <div className="pt-3 border-t border-white/[0.04] flex items-center justify-between text-xs text-gray-400">
                    <span>Target Branch: <b className="text-white">{branchId || 'Assigned Branch'}</b></span>
                    <span>Role to Grant: <b className="text-[#818CF8]">Tier 2 (Admin)</b></span>
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
                className="absolute top-6 right-6 p-2 text-gray-400 hover:text-white rounded-xl hover:bg-white/[0.05] transition-all cursor-pointer"
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
                  Find Replacement Candidate (Hello ID or UID)
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    placeholder="Enter candidate's Hello ID or UID..."
                    value={replaceQuery}
                    onChange={(e) => setReplaceQuery(e.target.value)}
                    className="flex-1 bg-[#18181B] border border-white/[0.08] rounded-2xl px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-amber-400"
                  />
                  <button
                    type="submit"
                    disabled={isSearchingReplace}
                    className="px-5 py-3 bg-amber-500 hover:bg-amber-600 text-black rounded-2xl font-bold text-sm tracking-tight transition-all disabled:opacity-50 cursor-pointer"
                  >
                    {isSearchingReplace ? <RefreshCw size={16} className="animate-spin" /> : 'Validate'}
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
                        {foundReplaceUser.displayName || foundReplaceUser.username || 'Candidate'}
                      </div>
                      <div className="text-xs text-gray-400 font-mono mt-0.5">
                        Hello ID: <span className="text-white font-bold">{foundReplaceUser.helloId || 'N/A'}</span>
                      </div>
                      <div className="text-xs text-gray-400 font-mono">
                        Current Role: <span className="text-emerald-400 font-bold uppercase">{foundReplaceUser.role || 'user'}</span>
                      </div>
                    </div>
                  </div>

                  {allowReplaceOverride && (
                    <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl space-y-2">
                      <div className="flex items-center gap-2 text-xs font-bold text-amber-400">
                        <AlertCircle size={14} />
                        <span>Agency Owner Conflict Detected</span>
                      </div>
                      <p className="text-[11px] text-gray-300">
                        Candidate owns an active Agency. Enter an authorization reason to proceed.
                      </p>
                      <input
                        type="text"
                        placeholder="Reason for replacement override..."
                        value={replaceOverrideReason}
                        onChange={(e) => setReplaceOverrideReason(e.target.value)}
                        className="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-1.5 text-xs text-white"
                      />
                    </div>
                  )}

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

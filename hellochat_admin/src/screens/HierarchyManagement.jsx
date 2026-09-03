import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { collection, query, getDocs, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { Shield, Users, UserCheck, Building2, Crown, Search, Filter, Plus, Network, CheckCircle, AlertCircle } from 'lucide-react';
import { useAdmin } from '../context/AdminContext';

export const HierarchyManagement = () => {
  const { isOwner, isSuperAdmin, isAdminRole, branchId, user: authUser, role: userRole } = useAdmin();
  const [users, setUsers] = useState([]);
  const [branches, setBranches] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  
  // Provision Branch Modal State (Owner Only)
  const [showBranchModal, setShowBranchModal] = useState(false);
  const [newBranchName, setNewBranchName] = useState('');
  const [selectedSuperAdminUid, setSelectedSuperAdminUid] = useState('');
  const [isProvisioning, setIsProvisioning] = useState(false);
  const [actionMessage, setActionMessage] = useState('');

  useEffect(() => {
    fetchHierarchyData();
  }, [isOwner, isSuperAdmin, isAdminRole, branchId, authUser]);

  const fetchHierarchyData = async () => {
    setLoading(true);
    setActionMessage('');
    try {
      // 1. Fetch Branches if Owner
      if (isOwner) {
        try {
          const bSnap = await getDocs(collection(db, "branches"));
          setBranches(bSnap.docs.map(d => ({ id: d.id, ...d.data() })));
        } catch (e) {
          console.error("Error fetching branches:", e);
        }
      }

      // 2. Fetch Users with Strict Branch Sandboxing
      let q;
      if (isOwner) {
        // Owner sees global accounts
        q = query(collection(db, "users"));
      } else if (isSuperAdmin && branchId) {
        // Super Admin sandboxed to own branch
        q = query(collection(db, "users"), where("branchId", "==", branchId));
      } else if (isAdminRole && authUser?.uid) {
        // Admin sandboxed to supervised accounts
        q = query(collection(db, "users"), where("adminId", "==", authUser.uid));
      } else {
        q = query(collection(db, "users"), where("role", "==", "host"));
      }

      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
    } catch (e) {
      console.error("Hierarchy fetch error:", e);
    } finally {
      setLoading(false);
    }
  };

  const handleAssignRole = async (targetUser, newRole) => {
    if (!window.confirm(`Assign role ${newRole.toUpperCase()} to ${targetUser.displayName || targetUser.username}?`)) return;
    try {
      const assignFn = httpsCallable(functions, 'assignHierarchyRole');
      await assignFn({
        targetUid: targetUser.id || targetUser.uid,
        newRole: newRole,
        targetBranchId: isSuperAdmin ? branchId : undefined,
        targetSuperAdminId: isSuperAdmin ? authUser.uid : undefined,
        targetAdminId: isAdminRole ? authUser.uid : undefined
      });
      setActionMessage(`✅ Successfully assigned role ${newRole.toUpperCase()}`);
      fetchHierarchyData();
    } catch (e) {
      alert("Role Assignment Error: " + e.message);
    }
  };

  const handleProvisionBranch = async (e) => {
    e.preventDefault();
    if (!newBranchName || !selectedSuperAdminUid) {
      alert("Please enter a Branch Name and select a target Super Admin user.");
      return;
    }
    setIsProvisioning(true);
    try {
      const provFn = httpsCallable(functions, 'provisionBranch');
      await provFn({
        branchName: newBranchName,
        superAdminUid: selectedSuperAdminUid
      });
      setActionMessage(`✅ Branch "${newBranchName}" created successfully!`);
      setShowBranchModal(false);
      setNewBranchName('');
      setSelectedSuperAdminUid('');
      fetchHierarchyData();
    } catch (e) {
      alert("Branch Provisioning Error: " + e.message);
    } finally {
      setIsProvisioning(false);
    }
  };

  const filteredUsers = users.filter(u => {
    const matchesSearch = (u.displayName || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
                          (u.username || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
                          (u.id || u.uid || '').toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRole = roleFilter === 'all' || u.role === roleFilter;
    return matchesSearch && matchesRole;
  });

  const getRoleBadge = (role) => {
    switch (role) {
      case 'owner':
        return <span className="px-3 py-1 bg-amber-500/20 text-amber-400 border border-amber-500/30 rounded-full text-xs font-black uppercase flex items-center gap-1.5"><Crown size={12} /> Owner</span>;
      case 'superadmin':
        return <span className="px-3 py-1 bg-purple-500/20 text-purple-400 border border-purple-500/30 rounded-full text-xs font-black uppercase flex items-center gap-1.5"><Shield size={12} /> Super Admin</span>;
      case 'admin':
        return <span className="px-3 py-1 bg-indigo-500/20 text-indigo-400 border border-indigo-500/30 rounded-full text-xs font-black uppercase flex items-center gap-1.5"><UserCheck size={12} /> Admin</span>;
      case 'agency':
        return <span className="px-3 py-1 bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 rounded-full text-xs font-black uppercase flex items-center gap-1.5"><Building2 size={12} /> Agency</span>;
      default:
        return <span className="px-3 py-1 bg-slate-800 text-slate-400 rounded-full text-xs font-bold uppercase">Host</span>;
    }
  };

  // Determine assignable options per role
  const getAssignableRoles = () => {
    if (isOwner) return ['host', 'agency', 'admin', 'superadmin', 'owner'];
    if (isSuperAdmin) return ['host', 'admin'];
    if (isAdminRole) return ['host', 'agency'];
    return ['host'];
  };

  return (
    <div className="space-y-8 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-4xl font-black tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-purple-500/20 rounded-2xl border border-purple-500/30">
              <Shield className="text-purple-400" size={28} />
            </div>
            Hierarchy & Branch Permissions
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            {isOwner ? 'Apex Authority (Global View & Branch Provisioning)' : isSuperAdmin ? `Branch Sandboxed (Branch ID: ${branchId || 'Assigned'})` : 'Supervised Hierarchy Scope'}
          </p>
        </div>

        {isOwner && (
          <button
            onClick={() => setShowBranchModal(true)}
            className="flex items-center gap-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-black text-xs uppercase px-5 py-3 rounded-2xl shadow-xl transition-all"
          >
            <Plus size={16} /> Provision New Branch
          </button>
        )}
      </div>

      {actionMessage && (
        <div className="p-4 bg-emerald-500/20 border border-emerald-500/30 rounded-2xl text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle size={16} /> {actionMessage}
        </div>
      )}

      {/* Owner Only: Active Branches Overview */}
      {isOwner && branches.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-xs font-black uppercase tracking-[0.2em] text-slate-400 flex items-center gap-2">
            <Network size={14} className="text-purple-400" /> Operational Branches ({branches.length})
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {branches.map(b => (
              <div key={b.id} className="bg-slate-900/60 p-5 rounded-3xl border border-white/10 hover:border-purple-500/30 transition-all">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="text-base font-black text-white">{b.name}</h3>
                    <p className="text-[10px] text-slate-500 font-mono mt-1">Branch ID: {b.id}</p>
                  </div>
                  <span className="px-2.5 py-0.5 bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 rounded-full text-[10px] font-black uppercase">
                    Active
                  </span>
                </div>
                <div className="mt-4 pt-3 border-t border-white/[0.05] text-[11px] text-slate-400">
                  <span className="font-bold text-slate-500">Super Admin UID: </span>
                  <span className="font-mono text-purple-400">{b.superAdminUid}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filter & Search Bar */}
      <div className="flex flex-col md:flex-row gap-4 justify-between bg-slate-900/60 p-6 rounded-3xl border border-white/10">
        <div className="flex items-center gap-3 bg-black px-4 py-3 rounded-2xl border border-white/10 flex-1">
          <Search className="text-slate-500" size={18} />
          <input
            type="text"
            placeholder="Search by name, username, or UID..."
            className="bg-transparent text-white text-sm outline-none w-full font-bold"
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>

        <div className="flex items-center gap-3">
          <Filter className="text-slate-500" size={18} />
          <select
            className="bg-black border border-white/10 text-white text-xs font-black uppercase px-4 py-3 rounded-2xl outline-none"
            value={roleFilter}
            onChange={e => setRoleFilter(e.target.value)}
          >
            <option value="all">All Roles</option>
            {isOwner && <option value="owner">Owner</option>}
            {isOwner && <option value="superadmin">Super Admin</option>}
            <option value="admin">Admin</option>
            <option value="agency">Agency</option>
            <option value="host">Host</option>
          </select>
        </div>
      </div>

      {/* User Hierarchy Table */}
      <div className="bg-slate-900/40 border border-white/10 rounded-[32px] overflow-hidden shadow-2xl">
        <table className="w-full text-left text-xs">
          <thead>
            <tr className="bg-white/5 border-b border-white/10 text-slate-400 uppercase font-black tracking-wider">
              <th className="p-6">User Account</th>
              <th className="p-6">Current Role</th>
              <th className="p-6">Branch Designation</th>
              <th className="p-6">Assigned Admin</th>
              <th className="p-6 text-right">Role Assignment</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.04]">
            {loading ? (
              <tr><td colSpan={5} className="p-20 text-center animate-pulse">Loading Sandboxed Accounts...</td></tr>
            ) : filteredUsers.length === 0 ? (
              <tr><td colSpan={5} className="p-20 text-center text-slate-600 font-bold uppercase">No accounts found within your hierarchy scope</td></tr>
            ) : (
              filteredUsers.map(u => (
                <tr key={u.id || u.uid} className="hover:bg-white/5 transition-all">
                  <td className="p-6">
                    <div className="flex items-center gap-3">
                      <img src={u.profilePhotoUrl || 'https://via.placeholder.com/40'} className="w-10 h-10 rounded-full object-cover border border-white/10" />
                      <div>
                        <p className="font-black text-white text-sm">{u.displayName || u.username}</p>
                        <p className="text-[10px] text-slate-500 font-mono">UID: {u.id || u.uid}</p>
                      </div>
                    </div>
                  </td>
                  <td className="p-6">{getRoleBadge(u.role)}</td>
                  <td className="p-6 font-mono text-slate-400">{u.branchId || '—'}</td>
                  <td className="p-6 font-mono text-slate-400">{u.adminId || '—'}</td>
                  <td className="p-6 text-right">
                    {/* Only show selector if user has permission to assign */}
                    {u.role === 'owner' && !isOwner ? (
                      <span className="text-[10px] font-bold text-slate-500">Locked</span>
                    ) : (
                      <select
                        className="bg-black border border-white/10 text-white text-[11px] font-black uppercase px-3 py-2 rounded-xl outline-none"
                        value={u.role || 'host'}
                        onChange={e => handleAssignRole(u, e.target.value)}
                      >
                        {getAssignableRoles().map(r => (
                          <option key={r} value={r}>{r.toUpperCase()}</option>
                        ))}
                      </select>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Provision Branch Modal (Owner Only) */}
      {showBranchModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#121214] border border-white/10 rounded-3xl p-8 max-w-md w-full shadow-2xl space-y-6">
            <h2 className="text-xl font-black uppercase tracking-tight flex items-center gap-3">
              <Network className="text-purple-400" size={22} /> Provision Isolated Branch
            </h2>
            <p className="text-xs text-slate-400">
              Create an isolated operational team and assign a Super Admin to govern it.
            </p>

            <form onSubmit={handleProvisionBranch} className="space-y-4">
              <div>
                <label className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-2">Branch Name</label>
                <input
                  type="text"
                  placeholder="e.g. Branch Phoenix, Team Alpha"
                  className="w-full bg-black border border-white/10 px-4 py-3 rounded-2xl text-white text-sm font-bold outline-none focus:border-purple-500"
                  value={newBranchName}
                  onChange={e => setNewBranchName(e.target.value)}
                  required
                />
              </div>

              <div>
                <label className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-2">Target Super Admin UID</label>
                <input
                  type="text"
                  placeholder="Enter User UID"
                  className="w-full bg-black border border-white/10 px-4 py-3 rounded-2xl text-white text-sm font-mono outline-none focus:border-purple-500"
                  value={selectedSuperAdminUid}
                  onChange={e => setSelectedSuperAdminUid(e.target.value)}
                  required
                />
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowBranchModal(false)}
                  className="flex-1 bg-white/5 hover:bg-white/10 text-white font-bold text-xs uppercase py-3.5 rounded-2xl transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isProvisioning}
                  className="flex-1 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white font-black text-xs uppercase py-3.5 rounded-2xl shadow-xl transition-all disabled:opacity-50"
                >
                  {isProvisioning ? "Provisioning..." : "Create Branch"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

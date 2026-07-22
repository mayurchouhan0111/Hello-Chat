import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, getDocs, where, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { Shield, Users, UserCheck, Building2, Crown, Search, Filter } from 'lucide-react';

export const HierarchyManagement = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const snap = await getDocs(collection(db, "users"));
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleAssignRole = async (user, newRole, superAdminId, adminId) => {
    if (!window.confirm(`Assign role ${newRole.toUpperCase()} to ${user.displayName || user.username}?`)) return;
    try {
      const uRef = doc(db, "users", user.id || user.uid);
      const updates = {
        role: newRole,
        roleUpdatedAt: serverTimestamp(),
      };
      if (superAdminId !== undefined) updates.superAdminId = superAdminId;
      if (adminId !== undefined) updates.adminId = adminId;

      await updateDoc(uRef, updates);
      alert(`Role ${newRole} assigned successfully.`);
      fetchUsers();
    } catch (e) {
      alert("Error: " + e.message);
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

  return (
    <div className="space-y-8 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-4xl font-black tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-purple-500/20 rounded-2xl border border-purple-500/30">
              <Shield className="text-purple-400" size={28} />
            </div>
            Hierarchy & Branch Permissions
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            5-Tier Branch Sandboxing (Owner → Super Admin → Admin → Agency → Host)
          </p>
        </div>
      </div>

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
            <option value="owner">Owner</option>
            <option value="superadmin">Super Admin</option>
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
              <th className="p-6">Super Admin Branch</th>
              <th className="p-6">Assigned Admin</th>
              <th className="p-6 text-right">Role Assignment</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.04]">
            {loading ? (
              <tr><td colSpan={5} className="p-20 text-center animate-pulse">Loading Hierarchy Accounts...</td></tr>
            ) : filteredUsers.length === 0 ? (
              <tr><td colSpan={5} className="p-20 text-center text-slate-600 font-bold uppercase">No accounts found</td></tr>
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
                  <td className="p-6 font-mono text-slate-400">{u.superAdminId || '—'}</td>
                  <td className="p-6 font-mono text-slate-400">{u.adminId || '—'}</td>
                  <td className="p-6 text-right">
                    <select
                      className="bg-black border border-white/10 text-white text-[11px] font-black uppercase px-3 py-2 rounded-xl outline-none"
                      value={u.role || 'host'}
                      onChange={e => handleAssignRole(u, e.target.value)}
                    >
                      <option value="host">Host</option>
                      <option value="agency">Agency</option>
                      <option value="admin">Admin</option>
                      <option value="superadmin">Super Admin</option>
                      <option value="owner">Owner</option>
                    </select>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

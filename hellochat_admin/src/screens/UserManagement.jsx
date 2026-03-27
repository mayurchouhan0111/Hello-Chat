import { useState, useEffect } from 'react';
import { db, auth } from '../firebase';
import { collection, query, getDocs, where, doc, updateDoc, limit } from 'firebase/firestore';
import { 
  Search, 
  Filter, 
  Ban, 
  CheckCircle, 
  Tag, 
  Coins, 
  MoreHorizontal, 
  User, 
  ShieldCheck, 
  Eye 
} from 'lucide-react';

export const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterTag, setFilterTag] = useState('All');

  useEffect(() => {
    fetchUsers();
  }, [filterTag]);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      let q = query(collection(db, "users"), limit(50));
      if (filterTag !== 'All') {
        q = query(collection(db, "users"), where("tags", "array-contains", filterTag), limit(50));
      }
      
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(list);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter(u => 
    u.displayName?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    u.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    u.uid === searchTerm
  );

  return (
    <div className="space-y-8 animate-fade-in text-white">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-black text-white mb-2 leading-tight tracking-tight uppercase tracking-widest">User Orchestration</h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.2em]">Manage 14,208 registered platform entities</p>
        </div>
        <div className="flex gap-4">
          <div className="relative group">
            <Search className="absolute left-4 top-4 text-slate-500 group-focus-within:text-primary transition-colors" size={20} />
            <input 
              type="text" 
              placeholder="Search by ID, Username, or Display Name..."
              className="input-field w-96 pl-12 bg-slate-800/50 border-white/5"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select 
            className="input-field bg-slate-800/50 border-white/5 px-6 font-black uppercase text-xs tracking-widest text-slate-400"
            value={filterTag}
            onChange={(e) => setFilterTag(e.target.value)}
          >
            {['All', 'Admin', 'Host', 'Agency', 'VIP', 'Recharge'].map(t => <option key={t}>{t}</option>)}
          </select>
        </div>
      </div>

      <div className="card-glass border-white/5 bg-slate-900/40 p-0 overflow-hidden shadow-3xl">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="border-b border-white/5 bg-white/5">
              <th className="px-8 py-5 text-[10px] font-black uppercase tracking-[0.2em] text-slate-400">Identity</th>
              <th className="px-8 py-5 text-[10px] font-black uppercase tracking-[0.2em] text-slate-400">Privileges</th>
              <th className="px-8 py-5 text-[10px] font-black uppercase tracking-[0.2em] text-slate-400">Wallets</th>
              <th className="px-8 py-5 text-[10px] font-black uppercase tracking-[0.2em] text-slate-400">Status</th>
              <th className="px-8 py-5 text-[10px] font-black uppercase tracking-[0.2em] text-slate-400 text-right">Operations</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.03]">
            {loading ? (
              <tr><td colSpan="5" className="py-20 text-center text-slate-600 font-black animate-pulse uppercase tracking-[0.5em]">Syncing Personnel Data...</td></tr>
            ) : filteredUsers.map(user => (
              <tr key={user.id} className="hover:bg-white/5 transition-all group">
                <td className="px-8 py-6">
                  <div className="flex items-center gap-4">
                    <div className="relative">
                      <img src={user.profilePhotoUrl || `https://picsum.photos/seed/${user.id}/100`} className="w-12 h-12 rounded-2xl object-cover border-2 border-white/10 group-hover:scale-110 transition-transform shadow-2xl" />
                      {user.status === 'online' && <div className="absolute -bottom-1 -right-1 w-3 h-3 bg-emerald-500 rounded-full border-2 border-slate-900 ring-4 ring-emerald-500/20"></div>}
                    </div>
                    <div>
                      <p className="font-extrabold text-white text-sm group-hover:text-primary-light transition-colors">{user.displayName}</p>
                      <p className="text-[10px] font-black uppercase text-slate-500 pt-1 tracking-widest">@{user.username || 'ID:' + user.id.slice(0,6)}</p>
                    </div>
                  </div>
                </td>
                <td className="px-8 py-6">
                  <div className="flex flex-wrap gap-2">
                    {user.tags?.map(t => (
                      <span key={t} className="px-3 py-1 bg-primary/10 border border-primary/20 text-primary-light font-black text-[9px] uppercase tracking-widest rounded-lg">{t}</span>
                    ))}
                    {!user.tags?.length && <span className="text-slate-700 font-black text-[9px] uppercase tracking-widest">Normal User</span>}
                  </div>
                </td>
                <td className="px-8 py-6">
                  <div className="space-y-1.5">
                    <div className="flex items-center gap-2">
                      <Coins size={12} className="text-cyan-400" />
                      <span className="text-xs font-black text-cyan-400 tracking-tighter">{user.diamondBalance || 0}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 bg-amber-500/10 border border-amber-500/30 rounded-full flex items-center justify-center">
                         <div className="w-1 h-1 bg-amber-500 rounded-full"></div>
                      </div>
                      <span className="text-xs font-black text-slate-400 tracking-tighter">{user.beansBalance || 0}</span>
                    </div>
                  </div>
                </td>
                <td className="px-8 py-6">
                  {user.isBanned ? (
                    <span className="inline-flex items-center gap-2 px-3 py-1 bg-red-500/10 border border-red-500/20 text-red-500 font-black text-[9px] uppercase tracking-widest rounded-lg">
                      <Ban size={10} /> BANNED
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-2 px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 text-emerald-500 font-black text-[9px] uppercase tracking-widest rounded-lg">
                      <CheckCircle size={10} /> ACTIVE
                    </span>
                  )}
                </td>
                <td className="px-8 py-6 text-right">
                  <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button title="View Profile" className="p-2.5 bg-white/5 border border-white/5 rounded-xl hover:bg-primary/20 hover:text-primary-light transition-all shadow-xl"><Eye size={18} /></button>
                    <button title="Adjust Balance" className="p-2.5 bg-white/5 border border-white/5 rounded-xl hover:bg-cyan-500/20 hover:text-cyan-400 transition-all shadow-xl"><Coins size={18} /></button>
                    <button title="Ban User" className="p-2.5 bg-white/5 border border-white/5 rounded-xl hover:bg-red-500/20 hover:text-red-400 transition-all shadow-xl"><Ban size={18} /></button>
                    <button title="Manage Permissions" className="p-2.5 bg-white/5 border border-white/5 rounded-xl hover:bg-amber-500/20 hover:text-amber-500 transition-all shadow-xl"><ShieldCheck size={18} /></button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

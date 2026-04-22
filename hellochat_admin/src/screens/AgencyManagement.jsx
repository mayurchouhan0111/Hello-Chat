import { useState, useEffect } from 'react';
import { db, auth } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  where, 
  doc, 
  updateDoc, 
  limit, 
  writeBatch, 
  serverTimestamp,
  getDoc
} from 'firebase/firestore';
import { 
  Search, 
  UserPlus, 
  Users, 
  Trophy, 
  Wallet,
  Star,
  ShieldCheck,
  ChevronRight,
  TrendingUp,
  Building2,
  Trash2,
  X,
  ChevronLeft
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
import { motion, AnimatePresence } from 'framer-motion';

export const AgencyManagement = () => {
  const { userData: currentUser, isAdmin, isAgencyOwner } = useAdmin();
  const [agencies, setAgencies] = useState([]);
  const [selectedAgency, setSelectedAgency] = useState(null);
  const [selectedHost, setSelectedHost] = useState(null);
  const [hosts, setHosts] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isSearching, setIsSearching] = useState(false);

  useEffect(() => {
    if (isAdmin) {
       fetchAllAgencies();
    } else if (isAgencyOwner) {
       setSelectedAgency(currentUser);
    }
  }, [isAdmin, isAgencyOwner, currentUser]);

  useEffect(() => {
    const agencyUid = selectedAgency?.uid || selectedAgency?.id;
    if (agencyUid) {
      fetchAgencyHosts(agencyUid);
    }
  }, [selectedAgency]);

  const fetchAllAgencies = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "users"), where("isAgencyOwner", "==", true));
      const snap = await getDocs(q);
      setAgencies(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchAgencyHosts = async (agencyUid) => {
    setLoading(true);
    try {
      const q = query(
        collection(db, "users"), 
        where("agencyId", "==", agencyUid)
      );
      const snap = await getDocs(q);
      setHosts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveHost = async (hostId) => {
    if (!window.confirm("Release this host from your agency? All current contracts will be voided.")) return;
    try {
      await updateDoc(doc(db, "users", hostId), {
        agencyId: null,
        agencyName: null,
        role: 'user'
      });
      alert("Host has been released from the agency.");
      setSelectedHost(null);
      fetchAgencyHosts(selectedAgency.uid);
    } catch (err) {
      alert("Remove Error: " + err.message);
    }
  };

  const handleSearchUsers = async () => {
    const term = searchTerm.trim();
    if (!term) return;
    setIsSearching(true);
    setSearchResults([]);
    
    try {
      // Attempt 3 Parallel Lookups for Maximum Flexibility
      const queries = [
        query(collection(db, "users"), where("uid", "==", term), limit(1)),
        query(collection(db, "users"), where("username", "==", term), limit(5)),
        query(collection(db, "users"), where("username_lowercase", "==", term.toLowerCase()), limit(5))
      ];

      const snaps = await Promise.all(queries.map(q => getDocs(q)));
      
      const combined = [];
      const seenIds = new Set();

      snaps.forEach(snap => {
        snap.docs.forEach(d => {
          if (!seenIds.has(d.id)) {
            const data = d.data();
            // Don't show users already in an agency if possible
            if (data.agencyId !== selectedAgency?.uid) {
              combined.push({ id: d.id, ...data });
              seenIds.add(d.id);
            }
          }
        });
      });

      setSearchResults(combined);
      if (combined.length === 0) {
        alert("No talent found matching: " + term);
      }
    } catch (err) {
       console.error("Recruitment Search Error:", err);
       alert("Find Talent Failed: Check your network/permissions");
    } finally {
      setIsSearching(false);
    }
  };

  const assignAsHost = async (targetUser) => {
    if (!selectedAgency) return;
    if (!window.confirm(`Assign ${targetUser.displayName} as a Host for ${selectedAgency.displayName}?`)) return;
    
    try {
      const agencyUid = selectedAgency.uid || selectedAgency.id;
      const userRef = doc(db, "users", targetUser.id || targetUser.uid);
      await updateDoc(userRef, {
        agencyId: agencyUid,
        agencyName: selectedAgency.displayName || 'Unnamed Agency',
        role: 'host',
        assignedAt: serverTimestamp()
      });
      
      alert(`${targetUser.displayName} has been assigned to the agency.`);
      setSearchResults([]);
      setSearchTerm('');
      fetchAgencyHosts(selectedAgency.uid);
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  return (
    <div className="p-8 space-y-8 min-h-screen bg-[#020617] text-slate-200">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 pb-8 border-b border-white/5">
        <div>
          <div className="flex items-center gap-4">
              {isAdmin && selectedAgency && (
                <button 
                   onClick={() => setSelectedAgency(null)}
                   className="p-3 bg-white/5 hover:bg-white/10 rounded-2xl text-slate-400 hover:text-indigo-400 transition-all group"
                   title="Return to Agency List"
                >
                   <ChevronLeft size={20} className="group-hover:-translate-x-1 transition-transform" />
                </button>
              )}
             <h1 className="text-4xl font-black text-white tracking-widest uppercase">
               {isAdmin && !selectedAgency ? 'All Agencies' : 'Agency Portal'}
             </h1>
          </div>
          <p className="text-amber-500 font-black text-[10px] uppercase tracking-[0.3em] mt-2 flex items-center gap-2">
             <ShieldCheck size={12} /> {selectedAgency ? `Managing: ${selectedAgency.displayName}` : 'Network Overview'}
          </p>
        </div>

        {selectedAgency && (
          <div className="flex gap-4">
             <div className="bg-slate-900/50 border border-white/5 p-4 rounded-3xl flex items-center gap-4 min-w-[200px]">
                <div className="p-3 bg-indigo-500/10 text-indigo-400 rounded-2xl">
                   <Users size={20} />
                </div>
                <div>
                   <p className="text-[10px] font-black uppercase text-slate-500 tracking-widest">Active Hosts</p>
                   <p className="text-xl font-black text-white">{hosts.length}</p>
                </div>
             </div>
             {/* Admin: Show Agency ID for debugging if needed */}
             {isAdmin && (
                <div className="bg-slate-900/50 border border-white/5 p-4 rounded-3xl hidden md:block">
                   <p className="text-[10px] font-black uppercase text-slate-500 tracking-widest">Agency UID</p>
                   <p className="text-[10px] font-mono text-slate-400">{(selectedAgency.uid || selectedAgency.id)}</p>
                </div>
             )}
          </div>
        )}
      </div>

      {isAdmin && !selectedAgency ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {agencies.map(agency => (
            <div 
              key={agency.id} 
              onClick={() => setSelectedAgency(agency)}
              className="bg-[#09090B] border border-white/5 p-8 rounded-[40px] hover:border-amber-500/30 transition-all cursor-pointer group relative overflow-hidden"
            >
               <div className="absolute top-0 right-0 p-8 bg-amber-500/5 rounded-full blur-3xl opacity-0 group-hover:opacity-100 transition-opacity"></div>
               <div className="flex items-center gap-6 relative">
                  <div className="w-20 h-20 bg-amber-500/10 rounded-3xl flex items-center justify-center border border-amber-500/20 group-hover:scale-110 transition-transform">
                     <Building2 size={32} className="text-amber-500" />
                  </div>
                  <div>
                    <h3 className="text-xl font-black text-white mb-1">{agency.displayName}</h3>
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest">@{agency.username}</p>
                    <div className="mt-4 flex items-center gap-2 text-indigo-400 font-bold text-[10px] uppercase tracking-tighter">
                       Tap to Manage <ChevronRight size={14} />
                    </div>
                  </div>
               </div>
            </div>
          ))}
        </div>
      ) : selectedAgency ? (
        <>
          {/* Recruitment Hub */}
          <div className="bg-indigo-600/5 border border-indigo-500/20 rounded-[40px] p-8 space-y-6">
         <div className="flex items-center gap-3">
            <div className="p-2 bg-indigo-500 text-white rounded-lg">
               <UserPlus size={18} />
            </div>
            <h2 className="text-xl font-black text-white uppercase tracking-tighter">Host Recruitment Hub</h2>
         </div>

         <div className="flex gap-4">
            <div className="relative flex-1">
               <input 
                  type="text" 
                  placeholder="Enter exact Username to recruit..."
                  className="w-full bg-black/40 border border-white/10 rounded-2xl py-4 px-6 outline-none focus:border-indigo-500 text-white font-bold"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSearchUsers()}
               />
               <button 
                  onClick={handleSearchUsers}
                  disabled={isSearching}
                  className="absolute right-2 top-2 bottom-2 px-6 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-900/50 text-white rounded-xl font-black text-[10px] uppercase tracking-widest transition-all"
               >
                  {isSearching ? 'Scanning Cloud...' : 'Find Talent'}
               </button>
            </div>
         </div>

         <AnimatePresence>
            {searchResults.length > 0 && (
               <motion.div 
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4"
               >
                  {searchResults.map(user => (
                     <div key={user.id} className="bg-white/5 border border-white/10 p-6 rounded-3xl flex items-center justify-between group">
                        <div className="flex items-center gap-4">
                           <img src={user.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${user.id}`} className="w-12 h-12 rounded-2xl object-cover" />
                           <div>
                              <p className="font-black text-white">{user.displayName}</p>
                              <p className="text-xs font-bold text-slate-500">@{user.username}</p>
                           </div>
                        </div>
                        <button 
                           onClick={() => assignAsHost(user)}
                           className="px-6 py-3 bg-white text-black font-black text-[10px] uppercase tracking-widest rounded-xl hover:scale-105 transition-transform"
                        >
                           Assign as Host
                        </button>
                     </div>
                  ))}
               </motion.div>
            )}
         </AnimatePresence>
      </div>

      {/* Roster List */}
      <div className="space-y-6">
         <h2 className="text-xs font-black text-slate-500 uppercase tracking-[0.4em] ml-2">Your Agency Roster</h2>
         
         {loading ? (
             <div className="py-20 text-center animate-pulse uppercase font-black text-slate-700 tracking-[1em]">Retrieving Talent Data...</div>
         ) : hosts.length === 0 ? (
             <div className="bg-slate-900/30 border border-dashed border-white/5 py-20 rounded-[40px] text-center">
                 <p className="text-slate-500 font-bold uppercase tracking-widest">No hosts assigned yet. Start recruiting!</p>
             </div>
         ) : (
             <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
                {hosts.map(host => (
                   <div key={host.id} className="bg-[#09090B] border border-white/5 p-6 rounded-[35px] hover:bg-white/[0.02] transition-all group relative overflow-hidden">
                      <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/5 blur-3xl -mr-16 -mt-16"></div>
                      
                      <div className="flex items-start justify-between mb-6 relative">
                         <div className="flex items-center gap-4">
                            <div className="relative">
                               <img src={host.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${host.id}`} className="w-16 h-16 rounded-2xl object-cover ring-2 ring-indigo-500/20" />
                               <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-indigo-500 border-2 border-[#09090B] rounded-full"></div>
                            </div>
                            <div>
                               <h3 className="font-black text-white">{host.displayName}</h3>
                               <p className="text-[10px] font-black uppercase text-slate-500">Member since {host.assignedAt?.toDate().toLocaleDateString() || 'Recently'}</p>
                            </div>
                         </div>
                         <div className="p-3 bg-slate-900 rounded-2xl text-amber-400">
                             <Star size={18} fill="currentColor" />
                         </div>
                      </div>

                      <div className="grid grid-cols-2 gap-4 relative">
                         <div className="bg-black/40 p-4 rounded-2xl">
                            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-1">XP Points</p>
                            <p className="text-sm font-black text-white">{host.xp || 0}</p>
                         </div>
                         <div className="bg-black/40 p-4 rounded-2xl">
                            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-1">Diamonds Gen</p>
                            <p className="text-sm font-black text-white">{host.diamondBalance || 0}</p>
                         </div>
                      </div>

                      <button 
                        onClick={() => setSelectedHost(host)}
                        className="w-full mt-6 py-4 bg-white/[0.03] hover:bg-white/5 text-slate-400 font-black text-[10px] uppercase tracking-widest rounded-2xl border border-white/5 flex items-center justify-center gap-2 transition-all"
                      >
                         View Full Analytics <ChevronRight size={14} />
                      </button>
                   </div>
                ))}
             </div>
         )}
      </div>
      {/* Host Analytics Modal */}
      <AnimatePresence>
        {selectedHost && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-6 bg-black/80 backdrop-blur-xl">
             <motion.div 
               initial={{ opacity: 0, scale: 0.9, y: 30 }}
               animate={{ opacity: 1, scale: 1, y: 0 }}
               exit={{ opacity: 0, scale: 0.9, y: 30 }}
               className="bg-[#09090B] border border-white/10 w-full max-w-2xl rounded-[40px] overflow-hidden shadow-2xl relative"
             >
                <div className="absolute top-6 right-6 z-10">
                   <button 
                      onClick={() => setSelectedHost(null)}
                      className="p-3 bg-white/5 hover:bg-white/10 rounded-2xl text-slate-500 hover:text-white transition-all"
                   >
                      <X size={20} />
                   </button>
                </div>

                <div className="p-10 space-y-8">
                   {/* Host Profile Header */}
                   <div className="flex items-center gap-6">
                      <div className="relative">
                         <img 
                            src={selectedHost.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${selectedHost.id}`} 
                            className="w-24 h-24 rounded-[32px] object-cover ring-4 ring-indigo-500/20 shadow-2xl" 
                         />
                         <div className="absolute -top-2 -right-2 bg-indigo-500 text-white p-2 rounded-xl border-4 border-[#09090B]">
                            <Star size={14} fill="currentColor" />
                         </div>
                      </div>
                      <div>
                         <h2 className="text-3xl font-black text-white tracking-tight uppercase">
                            {selectedHost.displayName}
                         </h2>
                         <p className="text-xs font-bold text-slate-500 uppercase tracking-widest mt-1">
                            Contracted Host Since {selectedHost.assignedAt?.toDate().toLocaleDateString() || 'Recently'}
                         </p>
                      </div>
                   </div>

                   {/* Stats Grid */}
                   <div className="grid grid-cols-2 gap-4">
                      <div className="bg-white/[0.03] border border-white/5 p-6 rounded-[32px] space-y-2">
                         <p className="text-[10px] font-black text-slate-600 uppercase tracking-widest">Global Ranking XP</p>
                         <p className="text-2xl font-black text-white">{selectedHost.xp || 0}</p>
                         <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                            <div className="h-full bg-indigo-500 w-[65%]" />
                         </div>
                      </div>
                      <div className="bg-white/[0.03] border border-white/5 p-6 rounded-[32px] space-y-2">
                         <p className="text-[10px] font-black text-slate-600 uppercase tracking-widest">Total Earnings (Beans)</p>
                         <p className="text-2xl font-black text-amber-500">{selectedHost.beanBalance || 0}</p>
                         <p className="text-[10px] font-bold text-slate-700">≈ ${( (selectedHost.beanBalance || 0) / 100).toFixed(2)} USD</p>
                      </div>
                   </div>

                   {/* Recent Performance HUD */}
                   <div className="bg-indigo-600/5 border border-indigo-500/10 p-8 rounded-[40px] space-y-4">
                      <div className="flex items-center justify-between">
                         <h4 className="text-[10px] font-black text-indigo-400 uppercase tracking-widest">Live Activity Pulse</h4>
                         <div className="flex items-center gap-2">
                            <span className="w-1.5 h-1.5 bg-indigo-500 rounded-full animate-ping"></span>
                            <span className="text-[9px] font-bold text-slate-500 uppercase">Synchronized with Node</span>
                         </div>
                      </div>
                      <div className="h-24 flex items-end gap-2 justify-between px-2">
                         {[40, 70, 45, 90, 65, 80, 55, 60, 30].map((h, i) => (
                           <div key={i} style={{ height: `${h}%` }} className="flex-1 bg-indigo-500/20 rounded-lg group hover:bg-indigo-500 transition-all cursor-crosshair relative">
                              <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-white text-black text-[8px] font-black p-1 px-2 rounded opacity-0 group-hover:opacity-100 transition-all">
                                 {h}%
                              </div>
                           </div>
                         ))}
                      </div>
                   </div>

                   {/* Actions */}
                   <div className="flex gap-4 pt-4">
                      <button className="flex-1 py-4 bg-white text-black font-black text-xs uppercase tracking-[0.2em] rounded-2xl hover:scale-[1.02] transition-all">
                         Export PDF Report
                      </button>
                      <button 
                        onClick={() => handleRemoveHost(selectedHost.id)}
                        className="p-4 bg-red-500/10 text-red-500 border border-red-500/20 rounded-2xl hover:bg-red-500 hover:text-white transition-all"
                        title="Release Host"
                      >
                         <Trash2 size={24} />
                      </button>
                   </div>
                </div>
             </motion.div>
          </div>
        )}
      </AnimatePresence>
        </>
      ) : null}
    </div>
  );
};

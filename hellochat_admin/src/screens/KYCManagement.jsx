import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  onSnapshot, 
  where, 
  doc, 
  updateDoc,
  serverTimestamp 
} from 'firebase/firestore';
import { 
  ShieldCheck, 
  UserCheck, 
  UserX, 
  Eye,
  Clock,
  ExternalLink,
  ShieldAlert,
  Search
} from 'lucide-react';
import { format } from 'date-fns';
import { useAdmin } from '../context/AdminContext';
import { logAdminAction } from './AuditLogs';

export const KYCManagement = () => {
  const [pendingUsers, setPendingUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedImage, setSelectedImage] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const { user: adminUser } = useAdmin();

  useEffect(() => {
    const q = query(
      collection(db, "users"), 
      where("verificationStatus", "==", "pending")
    );
    
    const unsub = onSnapshot(q, (snap) => {
      setPendingUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleVerify = async (targetUser, isApproved) => {
    const status = isApproved ? 'verified' : 'rejected';
    const action = isApproved ? 'APPROVE' : 'REJECT';
    
    if(!window.confirm(`Are you sure you want to ${action} verification for ${targetUser.displayName}?`)) return;

    try {
      await updateDoc(doc(db, "users", targetUser.id), {
        verificationStatus: status,
        isVerified: isApproved,
        verificationProcessedAt: serverTimestamp(),
        verificationProcessedBy: adminUser.uid
      });

      await logAdminAction(adminUser, "KYC_STATUS_UPDATE", targetUser.id, { status });
      alert(`User ${status} successfully.`);
    } catch (err) {
      alert("Error: " + err.message);
    }
  };

  const filteredUsers = pendingUsers.filter(u => 
    u.displayName?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    u.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
           <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
              <div className="p-3 bg-indigo-500/20 rounded-2xl border border-indigo-500/30">
                 <ShieldCheck className="text-indigo-400" size={28} />
              </div>
              Identity Verification
           </h1>
           <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">KYC Compliance • Document Review Queue</p>
        </div>

        <div className="relative group w-80">
          <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
             <Search className="text-slate-600 group-focus-within:text-indigo-400 transition-colors" size={18} />
          </div>
          <input 
            type="text" 
            placeholder="Search pending requests..."
            className="glass-input w-full pl-12 !py-3 bg-slate-900/40 border-white/5 focus:ring-1 ring-indigo-500/50"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {loading ? (
        <div className="py-40 text-center animate-pulse font-black text-slate-700 uppercase tracking-widest">Scanning Regulatory Vault...</div>
      ) : (
        <div className="grid grid-cols-1 gap-6">
          {filteredUsers.map((req) => (
            <div key={req.id} className="card-glass bg-slate-900/60 border-white/5 p-8 relative group overflow-hidden">
               <div className="absolute top-0 right-0 p-12 bg-indigo-500/5 rounded-full blur-3xl group-hover:scale-125 transition-transform"></div>
               <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-8 relative">
                  
                  {/* User Info */}
                  <div className="flex items-center gap-6 min-w-[300px]">
                     <div className="w-16 h-16 bg-slate-800 rounded-2xl overflow-hidden border border-white/10">
                        <img src={req.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${req.id}`} alt="" className="w-full h-full object-cover" />
                     </div>
                     <div>
                        <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-1">Applicant Identity</p>
                        <h3 className="text-lg font-black text-white leading-tight">{req.displayName}</h3>
                        <p className="text-[10px] font-bold text-slate-600 uppercase mt-1">UID: {req.id.slice(0, 12)}...</p>
                     </div>
                  </div>

                  {/* Document Preview */}
                  <div className="flex-1 flex items-center gap-6 px-8 border-l border-white/5">
                     <div 
                        className="w-40 h-24 bg-black rounded-xl border border-white/10 overflow-hidden cursor-pointer relative group/img"
                        onClick={() => setSelectedImage(req.idPhotoUrl)}
                     >
                        {req.idPhotoUrl ? (
                          <>
                            <img src={req.idPhotoUrl} className="w-full h-full object-cover opacity-60 group-hover/img:opacity-100 transition-opacity" alt="ID Document" />
                            <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover/img:opacity-100 transition-opacity bg-black/40">
                              <Eye className="text-white" size={20} />
                            </div>
                          </>
                        ) : (
                          <div className="w-full h-full flex items-center justify-center bg-slate-900">
                            <ShieldAlert className="text-slate-700" size={24} />
                          </div>
                        )}
                     </div>
                     <div className="space-y-1">
                        <p className="text-xs font-black text-white uppercase tracking-widest">Document of Record</p>
                        <p className="text-[10px] font-bold text-slate-500 leading-relaxed max-w-[200px]">Identification provided for bean settlement eligibility.</p>
                        {req.idPhotoUrl && (
                          <a href={req.idPhotoUrl} target="_blank" rel="noreferrer" className="text-[10px] font-black text-indigo-400 flex items-center gap-1 mt-2 hover:underline">
                            OPEN FULL SIZE <ExternalLink size={10} />
                          </a>
                        )}
                     </div>
                  </div>

                  {/* Request Metadata */}
                  <div className="px-8 border-l border-white/5 hidden xl:block">
                     <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-2">Submission Context</p>
                     <div className="flex items-center gap-2 text-indigo-300">
                        <Clock size={12} />
                        <span className="text-[10px] font-black uppercase">Awaiting Review</span>
                     </div>
                     <p className="text-[10px] font-bold text-slate-600 uppercase mt-2">Logged: {req.updatedAt ? format(req.updatedAt.toDate(), 'MMM dd, HH:mm') : '...'}</p>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-4">
                     <button 
                        onClick={() => handleVerify(req, false)}
                        className="flex items-center gap-3 px-6 py-4 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all border border-red-500/20"
                     >
                        <UserX size={16} /> REJECT
                     </button>
                     <button 
                        onClick={() => handleVerify(req, true)}
                        className="flex items-center gap-3 px-8 py-4 bg-indigo-600 hover:bg-indigo-500 text-white rounded-2xl font-black uppercase text-[10px] tracking-widest transition-all shadow-xl shadow-indigo-900/20"
                     >
                        <UserCheck size={18} /> VERIFY ACCOUNT
                     </button>
                  </div>

               </div>
            </div>
          ))}

          {filteredUsers.length === 0 && (
            <div className="py-40 text-center border-2 border-dashed border-white/5 rounded-[40px] bg-slate-900/20">
               <ShieldCheck className="text-slate-800 mx-auto mb-4" size={48} />
               <p className="text-slate-600 font-black uppercase text-xs tracking-widest">Verification queue is currently empty</p>
            </div>
          )}
        </div>
      )}

      {/* Image Modal */}
      {selectedImage && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-10 bg-black/95 backdrop-blur-xl" onClick={() => setSelectedImage(null)}>
           <div className="relative max-w-5xl max-h-full">
              <img src={selectedImage} className="rounded-3xl border border-white/10 shadow-2xl" alt="ID Document Full" />
              <button 
                className="absolute -top-12 right-0 text-white font-black uppercase text-xs tracking-widest flex items-center gap-2 bg-white/5 px-4 py-2 rounded-xl border border-white/10"
                onClick={() => setSelectedImage(null)}
              >
                Close View
              </button>
           </div>
        </div>
      )}
    </div>
  );
};

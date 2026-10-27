import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { 
  Search, 
  UserPlus, 
  Users, 
  Wallet,
  Star,
  ShieldCheck,
  ChevronRight,
  Building2,
  Trash2,
  X,
  ChevronLeft,
  Plus,
  Edit2,
  CheckCircle2,
  AlertCircle,
  Percent,
  Globe,
  Phone,
  RefreshCw,
  Power,
  Coins
} from 'lucide-react';
import { useAdmin } from '../context/AdminContext';
import { motion, AnimatePresence } from 'framer-motion';

export const AgencyManagement = () => {
  const { userData: currentUser, isAdmin, isAgencyOwner } = useAdmin();
  const [agencies, setAgencies] = useState([]);
  const [selectedAgency, setSelectedAgency] = useState(null);
  const [hosts, setHosts] = useState([]);
  const [selectedHost, setSelectedHost] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  // Modals state
  const [showAppointModal, setShowAppointModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showRecruitModal, setShowRecruitModal] = useState(false);
  const [modalError, setModalError] = useState('');

  // Form states
  const [appointForm, setAppointForm] = useState({
    ownerIdentifier: '',
    name: '',
    commissionRate: 10, // percentage (e.g. 10%)
    country: '',
    contactPhone: '',
    description: ''
  });

  const [editForm, setEditForm] = useState({
    name: '',
    commissionRate: 10,
    country: '',
    contactPhone: '',
    description: ''
  });

  const [recruitIdentifier, setRecruitIdentifier] = useState('');

  useEffect(() => {
    if (isAdmin) {
      fetchAgencies();
    } else if (isAgencyOwner && currentUser) {
      const myAgencyId = currentUser.agencyId || currentUser.uid || currentUser.id;
      loadAgencyDetail(myAgencyId);
    }
  }, [isAdmin, isAgencyOwner, currentUser]);

  const fetchAgencies = async () => {
    setLoading(true);
    try {
      const listFn = httpsCallable(functions, 'listAgencies');
      const res = await listFn();
      if (res.data?.success && Array.isArray(res.data.agencies)) {
        setAgencies(res.data.agencies);
      } else {
        setAgencies([]);
      }
    } catch (err) {
      console.error('Failed to list agencies:', err);
      // Fallback empty if error
      setAgencies([]);
    } finally {
      setLoading(false);
    }
  };

  const loadAgencyDetail = async (agencyId) => {
    setLoading(true);
    try {
      const getFn = httpsCallable(functions, 'getAgency');
      const res = await getFn({ agencyId });
      if (res.data?.success) {
        setSelectedAgency(res.data.agency);
        setHosts(res.data.hosts || []);
        setEditForm({
          name: res.data.agency.name || '',
          commissionRate: Math.round((res.data.agency.commissionRate || 0.1) * 100),
          country: res.data.agency.country || '',
          contactPhone: res.data.agency.contactPhone || '',
          description: res.data.agency.description || ''
        });
      }
    } catch (err) {
      console.error('Failed to get agency detail:', err);
      alert('Error loading agency: ' + (err.message || err));
    } finally {
      setLoading(false);
    }
  };

  const handleAppointAgency = async (e) => {
    e.preventDefault();
    if (!appointForm.ownerIdentifier.trim() || !appointForm.name.trim()) {
      alert('Please provide Owner Hello ID / UID and Agency Name.');
      return;
    }

    setModalError('');
    setActionLoading(true);
    try {
      const createFn = httpsCallable(functions, 'createAgency');
      const rateDecimal = parseFloat(appointForm.commissionRate) / 100 || 0.1;
      const res = await createFn({
        ownerIdentifier: appointForm.ownerIdentifier.trim(),
        name: appointForm.name.trim(),
        commissionRate: rateDecimal,
        country: appointForm.country.trim(),
        contactPhone: appointForm.contactPhone.trim(),
        description: appointForm.description.trim()
      });

      if (res.data?.success) {
        alert(res.data.message || 'Agency appointed successfully!');
        setShowAppointModal(false);
        setAppointForm({
          ownerIdentifier: '',
          name: '',
          commissionRate: 10,
          country: '',
          contactPhone: '',
          description: ''
        });
        await fetchAgencies();
      }
    } catch (err) {
      console.error('Failed to appoint agency:', err);
      setModalError(err.message || String(err));
    } finally {
      setActionLoading(false);
    }
  };

  const handleUpdateAgency = async (e) => {
    e.preventDefault();
    if (!selectedAgency) return;

    setActionLoading(true);
    try {
      const updateFn = httpsCallable(functions, 'updateAgency');
      const rateDecimal = parseFloat(editForm.commissionRate) / 100 || 0.1;
      const res = await updateFn({
        agencyId: selectedAgency.agencyId || selectedAgency.id,
        name: editForm.name.trim(),
        commissionRate: rateDecimal,
        country: editForm.country.trim(),
        contactPhone: editForm.contactPhone.trim(),
        description: editForm.description.trim()
      });

      if (res.data?.success) {
        alert('Agency updated successfully!');
        setShowEditModal(false);
        await loadAgencyDetail(selectedAgency.agencyId || selectedAgency.id);
        fetchAgencies();
      }
    } catch (err) {
      console.error('Failed to update agency:', err);
      alert('Update Agency Failed: ' + (err.message || err));
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggleStatus = async (agency) => {
    const target = agency || selectedAgency;
    if (!target) return;
    const currentActive = target.isActive !== false;
    const newActive = !currentActive;
    const actionLabel = newActive ? 'activate' : 'suspend';

    if (!window.confirm(`Are you sure you want to ${actionLabel} agency "${target.name}"?`)) {
      return;
    }

    setActionLoading(true);
    try {
      const statusFn = httpsCallable(functions, 'setAgencyStatus');
      const agencyId = target.agencyId || target.id;
      const res = await statusFn({ agencyId, isActive: newActive });
      if (res.data?.success) {
        if (selectedAgency && (selectedAgency.agencyId === agencyId || selectedAgency.id === agencyId)) {
          setSelectedAgency(prev => ({ ...prev, isActive: newActive, status: res.data.status }));
        }
        await fetchAgencies();
      }
    } catch (err) {
      console.error('Failed to set agency status:', err);
      alert('Status Change Failed: ' + (err.message || err));
    } finally {
      setActionLoading(false);
    }
  };

  const handleRecruitHost = async (e) => {
    e.preventDefault();
    if (!selectedAgency || !recruitIdentifier.trim()) {
      alert('Please enter a Host Hello ID or UID.');
      return;
    }

    setActionLoading(true);
    try {
      const addHostFn = httpsCallable(functions, 'addHost');
      const res = await addHostFn({
        agencyId: selectedAgency.agencyId || selectedAgency.id,
        hostIdentifier: recruitIdentifier.trim()
      });

      if (res.data?.success) {
        alert(`Host ${res.data.host?.displayName || ''} (ID: ${res.data.host?.helloId || ''}) added to agency!`);
        setRecruitIdentifier('');
        setShowRecruitModal(false);
        await loadAgencyDetail(selectedAgency.agencyId || selectedAgency.id);
      }
    } catch (err) {
      console.error('Failed to recruit host:', err);
      alert('Host Recruitment Failed: ' + (err.message || err));
    } finally {
      setActionLoading(false);
    }
  };

  const handleRemoveHost = async (host) => {
    if (!selectedAgency || !host) return;
    const hostUid = host.uid || host.id;
    const hostName = host.displayName || host.username || hostUid;

    if (!window.confirm(`Release host "${hostName}" from ${selectedAgency.name}?`)) {
      return;
    }

    setActionLoading(true);
    try {
      const removeHostFn = httpsCallable(functions, 'removeHost');
      const res = await removeHostFn({
        agencyId: selectedAgency.agencyId || selectedAgency.id,
        hostUid
      });

      if (res.data?.success) {
        alert(`Host "${hostName}" released successfully.`);
        if (selectedHost && (selectedHost.uid === hostUid || selectedHost.id === hostUid)) {
          setSelectedHost(null);
        }
        await loadAgencyDetail(selectedAgency.agencyId || selectedAgency.id);
      }
    } catch (err) {
      console.error('Failed to remove host:', err);
      alert('Host Release Failed: ' + (err.message || err));
    } finally {
      setActionLoading(false);
    }
  };

  // Filtered agencies
  const filteredAgencies = agencies.filter(a => {
    const term = searchTerm.toLowerCase();
    const matchesSearch = !term || 
      (a.name && a.name.toLowerCase().includes(term)) ||
      (a.ownerName && a.ownerName.toLowerCase().includes(term)) ||
      String(a.ownerHelloId || '').includes(term) ||
      a.agencyId.toLowerCase().includes(term);

    const matchesStatus = statusFilter === 'all' || 
      (statusFilter === 'active' && a.isActive !== false) ||
      (statusFilter === 'suspended' && a.isActive === false);

    return matchesSearch && matchesStatus;
  });

  const totalAgencies = agencies.length;
  const activeAgencies = agencies.filter(a => a.isActive !== false).length;
  const totalHosts = agencies.reduce((acc, a) => acc + (a.hostCount || 0), 0);

  return (
    <div className="p-8 space-y-8 min-h-screen bg-[#020617] text-slate-200">
      {/* Top Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-white/5">
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
            <h1 className="text-3xl font-black text-white tracking-widest uppercase">
              {isAdmin && !selectedAgency ? 'Agency Management' : selectedAgency?.name || 'Agency Portal'}
            </h1>
          </div>
          <p className="text-amber-500 font-bold text-xs uppercase tracking-[0.25em] mt-2 flex items-center gap-2">
            <ShieldCheck size={14} /> 
            {selectedAgency 
              ? `Owner: ${selectedAgency.ownerName || 'Unknown'} (Hello ID: ${selectedAgency.ownerHelloId || 'N/A'})` 
              : 'Network Administration & Host Roster System'}
          </p>
        </div>

        {/* Global Action Buttons */}
        <div className="flex flex-wrap items-center gap-3">
          {isAdmin && !selectedAgency && (
            <>
              <button
                onClick={fetchAgencies}
                disabled={loading}
                className="p-3 bg-white/5 hover:bg-white/10 text-slate-300 rounded-2xl transition-all"
                title="Refresh List"
              >
                <RefreshCw size={18} className={loading ? 'animate-spin' : ''} />
              </button>
              <button
                onClick={() => setShowAppointModal(true)}
                className="flex items-center gap-2 px-6 py-3.5 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white rounded-2xl text-xs font-black uppercase tracking-wider transition-all shadow-lg shadow-indigo-600/30"
              >
                <Plus size={18} /> Appoint Agency
              </button>
            </>
          )}

          {selectedAgency && (
            <>
              <Link 
                to="/commission-wallet"
                className="flex items-center gap-2 px-5 py-3.5 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 rounded-2xl text-xs font-black uppercase tracking-wider transition-all"
              >
                <Wallet size={16} /> Commission Wallet
              </Link>
              {isAdmin && (
                <>
                  <button
                    onClick={() => setShowEditModal(true)}
                    className="flex items-center gap-2 px-4 py-3.5 bg-white/5 hover:bg-white/10 text-slate-200 border border-white/10 rounded-2xl text-xs font-black uppercase tracking-wider transition-all"
                  >
                    <Edit2 size={16} /> Edit Info
                  </button>
                  <button
                    onClick={() => handleToggleStatus(selectedAgency)}
                    className={`flex items-center gap-2 px-4 py-3.5 rounded-2xl text-xs font-black uppercase tracking-wider transition-all border ${
                      selectedAgency.isActive !== false 
                        ? 'bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border-rose-500/30' 
                        : 'bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                    }`}
                  >
                    <Power size={16} /> {selectedAgency.isActive !== false ? 'Suspend' : 'Activate'}
                  </button>
                </>
              )}
              <button
                onClick={() => setShowRecruitModal(true)}
                className="flex items-center gap-2 px-6 py-3.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-2xl text-xs font-black uppercase tracking-wider transition-all shadow-lg shadow-indigo-600/30"
              >
                <UserPlus size={18} /> Recruit Host
              </button>
            </>
          )}
        </div>
      </div>

      {/* Metrics Row (when list view) */}
      {isAdmin && !selectedAgency && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div className="bg-[#09090B] border border-white/5 p-6 rounded-3xl flex items-center gap-5">
            <div className="p-4 bg-indigo-500/10 text-indigo-400 rounded-2xl">
              <Building2 size={24} />
            </div>
            <div>
              <p className="text-[10px] font-black uppercase text-slate-500 tracking-widest">Total Agencies</p>
              <p className="text-2xl font-black text-white">{totalAgencies}</p>
            </div>
          </div>
          <div className="bg-[#09090B] border border-white/5 p-6 rounded-3xl flex items-center gap-5">
            <div className="p-4 bg-emerald-500/10 text-emerald-400 rounded-2xl">
              <CheckCircle2 size={24} />
            </div>
            <div>
              <p className="text-[10px] font-black uppercase text-slate-500 tracking-widest">Active Agencies</p>
              <p className="text-2xl font-black text-emerald-400">{activeAgencies}</p>
            </div>
          </div>
          <div className="bg-[#09090B] border border-white/5 p-6 rounded-3xl flex items-center gap-5">
            <div className="p-4 bg-amber-500/10 text-amber-400 rounded-2xl">
              <Users size={24} />
            </div>
            <div>
              <p className="text-[10px] font-black uppercase text-slate-500 tracking-widest">Contracted Hosts</p>
              <p className="text-2xl font-black text-amber-400">{totalHosts}</p>
            </div>
          </div>
        </div>
      )}

      {/* ─── LIST VIEW ─── */}
      {isAdmin && !selectedAgency ? (
        <div className="space-y-6">
          {/* Search & Filter Bar */}
          <div className="flex flex-col sm:flex-row gap-4 justify-between items-center">
            <div className="relative flex-1 w-full">
              <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" />
              <input
                type="text"
                placeholder="Search by agency name, owner, Hello ID or UID..."
                className="w-full bg-[#09090B] border border-white/10 rounded-2xl py-3.5 pl-12 pr-4 text-sm text-white placeholder-slate-500 outline-none focus:border-indigo-500 transition-all font-medium"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <div className="flex gap-2 w-full sm:w-auto">
              {['all', 'active', 'suspended'].map(status => (
                <button
                  key={status}
                  onClick={() => setStatusFilter(status)}
                  className={`px-4 py-3 rounded-2xl text-xs font-black uppercase tracking-wider transition-all ${
                    statusFilter === status 
                      ? 'bg-indigo-600 text-white' 
                      : 'bg-white/5 text-slate-400 hover:bg-white/10'
                  }`}
                >
                  {status}
                </button>
              ))}
            </div>
          </div>

          {/* Agencies Grid */}
          {loading ? (
            <div className="py-24 text-center animate-pulse uppercase font-black text-slate-600 tracking-[0.5em]">
              Loading Registered Agencies...
            </div>
          ) : filteredAgencies.length === 0 ? (
            <div className="bg-[#09090B] border border-dashed border-white/10 p-16 rounded-[40px] text-center space-y-4">
              <div className="w-16 h-16 mx-auto bg-amber-500/10 text-amber-400 rounded-3xl flex items-center justify-center">
                <Building2 size={32} />
              </div>
              <h3 className="text-xl font-black text-white">No Agencies Found</h3>
              <p className="text-slate-400 text-sm max-w-md mx-auto">
                {searchTerm || statusFilter !== 'all' 
                  ? 'No agency matches your current filter criteria.' 
                  : 'No agencies have been registered yet. Appoint the first agency to start recruiting hosts.'}
              </p>
              <button
                onClick={() => setShowAppointModal(true)}
                className="mt-4 px-6 py-3.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-2xl text-xs font-black uppercase tracking-wider inline-flex items-center gap-2 shadow-lg shadow-indigo-600/30"
              >
                <Plus size={16} /> Appoint First Agency
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {filteredAgencies.map((agency) => {
                const isActive = agency.isActive !== false;
                return (
                  <div
                    key={agency.agencyId || agency.id}
                    onClick={() => loadAgencyDetail(agency.agencyId || agency.id)}
                    className="bg-[#09090B] border border-white/5 hover:border-indigo-500/40 p-7 rounded-[36px] transition-all cursor-pointer group relative overflow-hidden flex flex-col justify-between"
                  >
                    <div className="space-y-5">
                      {/* Top Badges */}
                      <div className="flex items-center justify-between">
                        <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wider ${
                          isActive 
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' 
                            : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                        }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${isActive ? 'bg-emerald-400' : 'bg-rose-400'}`} />
                          {isActive ? 'Active' : 'Suspended'}
                        </span>
                        <span className="text-[10px] font-mono font-bold text-slate-500">
                          {(agency.commissionRate * 100).toFixed(0)}% Split
                        </span>
                      </div>

                      {/* Agency Icon & Info */}
                      <div className="flex items-center gap-4">
                        <div className="w-16 h-16 bg-gradient-to-tr from-amber-500/10 to-indigo-500/10 rounded-2xl flex items-center justify-center border border-white/10 group-hover:scale-105 transition-transform flex-shrink-0">
                          <Building2 size={28} className="text-amber-400" />
                        </div>
                        <div className="overflow-hidden">
                          <h3 className="text-lg font-black text-white truncate group-hover:text-indigo-400 transition-colors">
                            {agency.name}
                          </h3>
                          <p className="text-xs text-slate-400 truncate mt-0.5">
                            Owner: <span className="text-white font-bold">{agency.ownerName || 'Unknown'}</span>
                          </p>
                          <p className="text-[11px] text-slate-500 font-mono">
                            Hello ID: {agency.ownerHelloId || 'N/A'}
                          </p>
                          {agency.code && (
                            <p className="text-[11px] text-amber-400 font-mono font-bold mt-0.5">
                              Agency Code: #{agency.code}
                            </p>
                          )}
                        </div>
                      </div>

                      {/* Stats Row */}
                      <div className="grid grid-cols-2 gap-3 pt-2">
                        <div className="bg-white/[0.02] border border-white/5 p-3 rounded-2xl">
                          <p className="text-[9px] font-black text-slate-500 uppercase tracking-wider">Hosts</p>
                          <p className="text-base font-black text-indigo-400 mt-0.5">{agency.hostCount || 0}</p>
                        </div>
                        <div className="bg-white/[0.02] border border-white/5 p-3 rounded-2xl">
                          <p className="text-[9px] font-black text-slate-500 uppercase tracking-wider">Total Beans</p>
                          <p className="text-base font-black text-amber-400 mt-0.5">{(agency.totalBeansEarned || 0).toLocaleString()}</p>
                        </div>
                      </div>
                    </div>

                    {/* Bottom CTA */}
                    <div className="mt-6 pt-4 border-t border-white/5 flex items-center justify-between text-indigo-400 text-xs font-bold uppercase tracking-wider">
                      <span>Manage Roster</span>
                      <ChevronRight size={16} className="group-hover:translate-x-1 transition-transform" />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      ) : selectedAgency ? (
        /* ─── AGENCY DETAIL / ROSTER VIEW ─── */
        <div className="space-y-8">
          {/* Agency HUD Card */}
          <div className="bg-gradient-to-r from-indigo-950/20 via-[#09090B] to-[#09090B] border border-indigo-500/20 p-8 rounded-[40px] space-y-6">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
              <div className="flex items-center gap-5">
                <div className="w-20 h-20 bg-amber-500/10 rounded-3xl flex items-center justify-center border border-amber-500/20 flex-shrink-0">
                  <Building2 size={36} className="text-amber-400" />
                </div>
                <div>
                  <div className="flex items-center gap-3">
                    <h2 className="text-2xl font-black text-white">{selectedAgency.name}</h2>
                    <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wider ${
                      selectedAgency.isActive !== false 
                        ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' 
                        : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                    }`}>
                      {selectedAgency.isActive !== false ? 'Active' : 'Suspended'}
                    </span>
                    {selectedAgency.code && (
                      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-mono font-black uppercase tracking-wider bg-amber-500/10 text-amber-400 border border-amber-500/20">
                        Code: #{selectedAgency.code}
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-slate-400 mt-1">
                    Owner: <span className="text-white font-bold">{selectedAgency.ownerName || 'Unknown'}</span> · Hello ID: <span className="font-mono text-indigo-400 font-bold">{selectedAgency.ownerHelloId || 'N/A'}</span> · UID: <span className="font-mono text-slate-500 text-[10px]">{selectedAgency.ownerUid}</span>
                  </p>
                  {selectedAgency.description && (
                    <p className="text-xs text-slate-500 mt-2 max-w-2xl">{selectedAgency.description}</p>
                  )}
                </div>
              </div>

              {/* Quick Details Badges */}
              <div className="flex flex-wrap items-center gap-3">
                <div className="bg-white/[0.03] border border-white/5 px-4 py-3 rounded-2xl">
                  <p className="text-[9px] font-black uppercase text-slate-500 tracking-wider">Commission Split</p>
                  <p className="text-lg font-black text-white">{((selectedAgency.commissionRate || 0.1) * 100).toFixed(0)}%</p>
                </div>
                <div className="bg-white/[0.03] border border-white/5 px-4 py-3 rounded-2xl">
                  <p className="text-[9px] font-black uppercase text-slate-500 tracking-wider">Active Hosts</p>
                  <p className="text-lg font-black text-indigo-400">{hosts.length}</p>
                </div>
                <div className="bg-white/[0.03] border border-white/5 px-4 py-3 rounded-2xl">
                  <p className="text-[9px] font-black uppercase text-slate-500 tracking-wider">Beans Balance</p>
                  <p className="text-lg font-black text-amber-400">{(selectedAgency.beansBalance || 0).toLocaleString()}</p>
                </div>
              </div>
            </div>
          </div>

          {/* Roster Section Header */}
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-xl font-black text-white uppercase tracking-wider">Host Roster ({hosts.length})</h3>
              <p className="text-xs text-slate-500 mt-0.5">Performers and streamers managed under this agency.</p>
            </div>
            <button
              onClick={() => setShowRecruitModal(true)}
              className="flex items-center gap-2 px-5 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-2xl text-xs font-black uppercase tracking-wider transition-all shadow-lg shadow-indigo-600/30"
            >
              <UserPlus size={16} /> Recruit Host
            </button>
          </div>

          {/* Host Roster Cards */}
          {loading ? (
            <div className="py-20 text-center animate-pulse uppercase font-black text-slate-600 tracking-[0.5em]">
              Loading Host Roster...
            </div>
          ) : hosts.length === 0 ? (
            <div className="bg-[#09090B] border border-dashed border-white/10 p-14 rounded-[36px] text-center space-y-3">
              <p className="text-slate-400 font-bold">No hosts assigned to this agency yet.</p>
              <button
                onClick={() => setShowRecruitModal(true)}
                className="px-5 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-2xl text-xs font-black uppercase tracking-wider inline-flex items-center gap-2"
              >
                <UserPlus size={16} /> Recruit First Host
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {hosts.map(host => (
                <div 
                  key={host.uid || host.id}
                  className="bg-[#09090B] border border-white/5 hover:border-white/15 p-6 rounded-[32px] transition-all relative group flex flex-col justify-between"
                >
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <img 
                          src={host.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${host.uid || host.id}`} 
                          className="w-12 h-12 rounded-2xl object-cover ring-2 ring-indigo-500/20"
                          alt="avatar"
                        />
                        <div>
                          <h4 className="font-black text-white text-sm truncate max-w-[150px]">{host.displayName || 'Unknown Host'}</h4>
                          <p className="text-[11px] font-mono text-indigo-400">ID: {host.helloId || 'N/A'}</p>
                        </div>
                      </div>
                      <button
                        onClick={() => handleRemoveHost(host)}
                        className="p-2.5 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 rounded-xl transition-all"
                        title="Release Host from Agency"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>

                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <div className="bg-white/[0.02] border border-white/5 p-3 rounded-xl">
                        <p className="text-[9px] font-black text-slate-500 uppercase tracking-wider">Beans Balance</p>
                        <p className="font-black text-amber-400 mt-0.5">{(host.beansBalance || 0).toLocaleString()}</p>
                      </div>
                      <div className="bg-white/[0.02] border border-white/5 p-3 rounded-xl">
                        <p className="text-[9px] font-black text-slate-500 uppercase tracking-wider">Diamonds Spent</p>
                        <p className="font-black text-emerald-400 mt-0.5">{(host.svipPoints || 0).toLocaleString()}</p>
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={() => setSelectedHost(host)}
                    className="w-full mt-4 py-3 bg-white/5 hover:bg-white/10 text-slate-300 font-bold text-xs uppercase tracking-wider rounded-xl transition-all flex items-center justify-center gap-1.5"
                  >
                    Host Details <ChevronRight size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      ) : null}

      {/* ─── APPOINT AGENCY MODAL ─── */}
      <AnimatePresence>
        {showAppointModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="bg-[#09090B] border border-white/10 w-full max-w-xl rounded-[36px] overflow-hidden shadow-2xl"
            >
              <div className="flex items-center justify-between p-6 border-b border-white/5">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 bg-indigo-500/10 text-indigo-400 rounded-2xl">
                    <Building2 size={20} />
                  </div>
                  <div>
                    <h3 className="text-lg font-black text-white uppercase tracking-wider">Appoint New Agency</h3>
                    <p className="text-xs text-slate-500">Designate a user as an agency owner and register their agency.</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowAppointModal(false)}
                  className="p-2 hover:bg-white/10 rounded-xl text-slate-400 transition-all"
                >
                  <X size={20} />
                </button>
              </div>

              <form onSubmit={handleAppointAgency} className="p-6 space-y-4">
                {modalError && (
                  <div className="p-3.5 bg-rose-500/15 border border-rose-500/30 rounded-xl text-rose-300 text-xs font-semibold flex items-start gap-2.5 shadow-lg shadow-rose-900/20">
                    <span className="text-base leading-none">⚠️</span>
                    <span className="flex-1">{modalError}</span>
                  </div>
                )}

                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Owner Identifier (Hello ID or UID) *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 5621916410 or user UID"
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-mono"
                    value={appointForm.ownerIdentifier}
                    onChange={(e) => setAppointForm({ ...appointForm, ownerIdentifier: e.target.value })}
                  />
                  <p className="text-[10px] text-slate-500 mt-1">Accepts numeric Hello ID or standard Firebase Auth UID.</p>
                </div>

                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Agency Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Starlight Talent Group"
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-medium"
                    value={appointForm.name}
                    onChange={(e) => setAppointForm({ ...appointForm, name: e.target.value })}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                      Commission Rate (%) <span className="text-amber-400 text-[10px] lowercase font-normal">(display only, not used for payouts)</span>
                    </label>
                    <div className="relative">
                      <input
                        type="number"
                        min="0"
                        max="100"
                        step="0.5"
                        placeholder="10"
                        className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-mono"
                        value={appointForm.commissionRate}
                        onChange={(e) => setAppointForm({ ...appointForm, commissionRate: e.target.value })}
                      />
                      <Percent size={14} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-500" />
                    </div>
                    <p className="text-[9px] text-slate-500 mt-1">
                      * Informational only. Recharge commission uses global system policy.
                    </p>
                  </div>
                  <div>
                    <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                      Country
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. India, Bangladesh"
                      className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-medium"
                      value={appointForm.country}
                      onChange={(e) => setAppointForm({ ...appointForm, country: e.target.value })}
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Contact Phone / WhatsApp
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. +91 9876543210"
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-mono"
                    value={appointForm.contactPhone}
                    onChange={(e) => setAppointForm({ ...appointForm, contactPhone: e.target.value })}
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Description
                  </label>
                  <textarea
                    rows={2}
                    placeholder="Agency background or operational notes..."
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-2.5 px-4 text-white text-sm outline-none focus:border-indigo-500 resize-none font-medium"
                    value={appointForm.description}
                    onChange={(e) => setAppointForm({ ...appointForm, description: e.target.value })}
                  />
                </div>

                <div className="flex justify-end gap-3 pt-4 border-t border-white/5">
                  <button
                    type="button"
                    onClick={() => setShowAppointModal(false)}
                    className="px-5 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-black uppercase tracking-wider text-slate-300 transition-all"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={actionLoading}
                    className="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-900/50 rounded-xl text-xs font-black uppercase tracking-wider text-white transition-all shadow-lg shadow-indigo-600/30 flex items-center gap-2"
                  >
                    {actionLoading ? 'Appointing...' : 'Appoint Agency'}
                  </button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* ─── EDIT AGENCY MODAL ─── */}
      <AnimatePresence>
        {showEditModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="bg-[#09090B] border border-white/10 w-full max-w-xl rounded-[36px] overflow-hidden shadow-2xl"
            >
              <div className="flex items-center justify-between p-6 border-b border-white/5">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 bg-indigo-500/10 text-indigo-400 rounded-2xl">
                    <Edit2 size={20} />
                  </div>
                  <div>
                    <h3 className="text-lg font-black text-white uppercase tracking-wider">Edit Agency Details</h3>
                    <p className="text-xs text-slate-500">Update agency name, split percentage, and contact info.</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowEditModal(false)}
                  className="p-2 hover:bg-white/10 rounded-xl text-slate-400 transition-all"
                >
                  <X size={20} />
                </button>
              </div>

              <form onSubmit={handleUpdateAgency} className="p-6 space-y-4">
                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Agency Name *
                  </label>
                  <input
                    type="text"
                    required
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-medium"
                    value={editForm.name}
                    onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                      Commission Rate (%) <span className="text-amber-400 text-[10px] lowercase font-normal">(display only, not used for payouts)</span>
                    </label>
                    <div className="relative">
                      <input
                        type="number"
                        min="0"
                        max="100"
                        step="0.5"
                        className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-mono"
                        value={editForm.commissionRate}
                        onChange={(e) => setEditForm({ ...editForm, commissionRate: e.target.value })}
                      />
                      <Percent size={14} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-500" />
                    </div>
                    <p className="text-[9px] text-slate-500 mt-1">
                      * Informational only. Payout calculations use system-wide financial policies.
                    </p>
                  </div>
                  <div>
                    <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                      Country
                    </label>
                    <input
                      type="text"
                      className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-medium"
                      value={editForm.country}
                      onChange={(e) => setEditForm({ ...editForm, country: e.target.value })}
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Contact Phone / WhatsApp
                  </label>
                  <input
                    type="text"
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-mono"
                    value={editForm.contactPhone}
                    onChange={(e) => setEditForm({ ...editForm, contactPhone: e.target.value })}
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Description
                  </label>
                  <textarea
                    rows={2}
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-2.5 px-4 text-white text-sm outline-none focus:border-indigo-500 resize-none font-medium"
                    value={editForm.description}
                    onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                  />
                </div>

                <div className="flex justify-end gap-3 pt-4 border-t border-white/5">
                  <button
                    type="button"
                    onClick={() => setShowEditModal(false)}
                    className="px-5 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-black uppercase tracking-wider text-slate-300 transition-all"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={actionLoading}
                    className="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-900/50 rounded-xl text-xs font-black uppercase tracking-wider text-white transition-all shadow-lg shadow-indigo-600/30 flex items-center gap-2"
                  >
                    {actionLoading ? 'Saving...' : 'Save Changes'}
                  </button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* ─── RECRUIT HOST MODAL ─── */}
      <AnimatePresence>
        {showRecruitModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="bg-[#09090B] border border-white/10 w-full max-w-lg rounded-[36px] overflow-hidden shadow-2xl"
            >
              <div className="flex items-center justify-between p-6 border-b border-white/5">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 bg-indigo-500/10 text-indigo-400 rounded-2xl">
                    <UserPlus size={20} />
                  </div>
                  <div>
                    <h3 className="text-lg font-black text-white uppercase tracking-wider">Recruit Host</h3>
                    <p className="text-xs text-slate-500">Link a registered user to this agency roster.</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowRecruitModal(false)}
                  className="p-2 hover:bg-white/10 rounded-xl text-slate-400 transition-all"
                >
                  <X size={20} />
                </button>
              </div>

              <form onSubmit={handleRecruitHost} className="p-6 space-y-4">
                <div>
                  <label className="block text-[11px] font-black uppercase text-slate-400 tracking-wider mb-2">
                    Host Identifier (Hello ID or UID) *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 1002 or user UID"
                    className="w-full bg-black/40 border border-white/10 rounded-xl py-3 px-4 text-white text-sm outline-none focus:border-indigo-500 font-mono"
                    value={recruitIdentifier}
                    onChange={(e) => setRecruitIdentifier(e.target.value)}
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    Enter the performer's numeric Hello ID or UID to link them to {selectedAgency?.name}.
                  </p>
                </div>

                <div className="flex justify-end gap-3 pt-4 border-t border-white/5">
                  <button
                    type="button"
                    onClick={() => setShowRecruitModal(false)}
                    className="px-5 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-black uppercase tracking-wider text-slate-300 transition-all"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={actionLoading}
                    className="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-900/50 rounded-xl text-xs font-black uppercase tracking-wider text-white transition-all shadow-lg shadow-indigo-600/30 flex items-center gap-2"
                  >
                    {actionLoading ? 'Linking...' : 'Add to Agency'}
                  </button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* ─── HOST DETAIL MODAL ─── */}
      <AnimatePresence>
        {selectedHost && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="bg-[#09090B] border border-white/10 w-full max-w-xl rounded-[36px] overflow-hidden shadow-2xl"
            >
              <div className="flex items-center justify-between p-6 border-b border-white/5">
                <div className="flex items-center gap-3">
                  <img
                    src={selectedHost.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${selectedHost.uid || selectedHost.id}`}
                    className="w-12 h-12 rounded-2xl object-cover ring-2 ring-indigo-500/20"
                    alt="avatar"
                  />
                  <div>
                    <h3 className="text-lg font-black text-white">{selectedHost.displayName || 'Host Details'}</h3>
                    <p className="text-xs font-mono text-indigo-400">Hello ID: {selectedHost.helloId || 'N/A'}</p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedHost(null)}
                  className="p-2 hover:bg-white/10 rounded-xl text-slate-400 transition-all"
                >
                  <X size={20} />
                </button>
              </div>

              <div className="p-6 space-y-6">
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-white/[0.02] border border-white/5 p-4 rounded-2xl">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">Beans Balance</p>
                    <p className="text-xl font-black text-amber-400 mt-1">{(selectedHost.beansBalance || 0).toLocaleString()}</p>
                  </div>
                  <div className="bg-white/[0.02] border border-white/5 p-4 rounded-2xl">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">Diamonds Spent</p>
                    <p className="text-xl font-black text-emerald-400 mt-1">{(selectedHost.svipPoints || 0).toLocaleString()}</p>
                  </div>
                  <div className="bg-white/[0.02] border border-white/5 p-4 rounded-2xl">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">XP Points</p>
                    <p className="text-xl font-black text-indigo-400 mt-1">{(selectedHost.xp || 0).toLocaleString()}</p>
                  </div>
                  <div className="bg-white/[0.02] border border-white/5 p-4 rounded-2xl">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">Role</p>
                    <p className="text-xl font-black text-white uppercase mt-1">{selectedHost.role || 'host'}</p>
                  </div>
                </div>

                <div className="bg-white/[0.02] border border-white/5 p-4 rounded-2xl space-y-1">
                  <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">Firebase UID</p>
                  <p className="text-xs font-mono text-slate-300 select-all">{selectedHost.uid || selectedHost.id}</p>
                </div>

                <div className="flex justify-between items-center pt-2">
                  <button
                    onClick={() => handleRemoveHost(selectedHost)}
                    className="px-5 py-3 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30 rounded-xl text-xs font-black uppercase tracking-wider transition-all flex items-center gap-2"
                  >
                    <Trash2 size={16} /> Release From Agency
                  </button>
                  <button
                    onClick={() => setSelectedHost(null)}
                    className="px-5 py-3 bg-white/5 hover:bg-white/10 text-slate-300 rounded-xl text-xs font-black uppercase tracking-wider transition-all"
                  >
                    Close
                  </button>
                </div>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

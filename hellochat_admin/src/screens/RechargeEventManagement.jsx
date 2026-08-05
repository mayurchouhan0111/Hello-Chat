import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, 
  query, 
  orderBy, 
  onSnapshot, 
  addDoc, 
  updateDoc, 
  doc, 
  deleteDoc, 
  Timestamp,
  getDocs,
  where,
  writeBatch
} from 'firebase/firestore';
import { 
  Calendar, 
  Coins, 
  Image as ImageIcon, 
  Layers, 
  Plus, 
  Trash2, 
  Edit2, 
  Save, 
  X, 
  Check, 
  AlertCircle,
  Globe,
  Monitor
} from 'lucide-react';

const TABS = [
  { id: 'events', label: 'Event Details', icon: Calendar },
  { id: 'packages', label: 'Recharge Packages', icon: Layers },
];

export const RechargeEventManagement = () => {
  const [activeTab, setActiveTab] = useState('events');
  const [events, setEvents] = useState([]);
  const [packages, setPackages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState(null);

  // Event Form State
  const [showEventForm, setShowEventForm] = useState(false);
  const [editingEventId, setEditingEventId] = useState(null);
  const [eventForm, setEventForm] = useState({
    title: '',
    description: '',
    bannerImage: '',
    startDate: '',
    endDate: '',
    isActive: true,
    webUrl: '',
  });

  // Package Form State
  const [showPackageForm, setShowPackageForm] = useState(false);
  const [editingPackageId, setEditingPackageId] = useState(null);
  const [packageForm, setPackageForm] = useState({
    eventId: '',
    rechargeAmount: 1,
    baseCoins: 1000000,
    bonusCoins: 2000000,
    frameUrl: 'assets/images/super/super-admin.svga',
    validityDays: 1,
    sortOrder: 1,
    isActive: true,
  });

  useEffect(() => {
    setLoading(true);
    // Listen to Events
    const eventsQuery = query(collection(db, 'recharge_bonus_events'), orderBy('createdAt', 'desc'));
    const unsubEvents = onSnapshot(eventsQuery, (snap) => {
      setEvents(snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          ...data,
          startDate: data.startDate?.toDate().toISOString().substring(0, 16) || '',
          endDate: data.endDate?.toDate().toISOString().substring(0, 16) || '',
        };
      }));
    });

    // Listen to Packages
    const packagesQuery = query(collection(db, 'recharge_bonus_packages'), orderBy('sortOrder', 'asc'));
    const unsubPackages = onSnapshot(packagesQuery, (snap) => {
      setPackages(snap.docs.map(d => ({
        id: d.id,
        ...d.data(),
      })));
    });

    setLoading(false);
    return () => {
      unsubEvents();
      unsubPackages();
    };
  }, []);

  const showMsg = (text, type = 'success') => {
    setMessage({ text, type });
    setTimeout(() => setMessage(null), 5000);
  };

  // ──────── EVENT CRUD operations ──────────────────────────

  const resetEventForm = () => {
    setEventForm({
      title: '',
      description: '',
      bannerImage: '',
      startDate: '',
      endDate: '',
      isActive: true,
      webUrl: '',
    });
    setEditingEventId(null);
    setShowEventForm(false);
  };

  const handleEditEvent = (ev) => {
    setEventForm({
      title: ev.title || '',
      description: ev.description || '',
      bannerImage: ev.bannerImage || '',
      startDate: ev.startDate || '',
      endDate: ev.endDate || '',
      isActive: ev.isActive !== false,
      webUrl: ev.webUrl || '',
    });
    setEditingEventId(ev.id);
    setShowEventForm(true);
  };

  const handleSaveEvent = async (e) => {
    e.preventDefault();
    if (!eventForm.title.trim() || !eventForm.description.trim() || !eventForm.bannerImage.trim()) {
      showMsg('❌ Please fill in all required fields.', 'error');
      return;
    }
    if (!eventForm.startDate || !eventForm.endDate) {
      showMsg('❌ Start and End dates are required.', 'error');
      return;
    }

    const startTs = Timestamp.fromDate(new Date(eventForm.startDate));
    const endTs = Timestamp.fromDate(new Date(eventForm.endDate));

    if (endTs.toMillis() <= startTs.toMillis()) {
      showMsg('❌ End date must be after Start date.', 'error');
      return;
    }

    try {
      const data = {
        title: eventForm.title,
        description: eventForm.description,
        bannerImage: eventForm.bannerImage,
        startDate: startTs,
        endDate: endTs,
        isActive: eventForm.isActive,
        webUrl: eventForm.webUrl.trim(),
      };

      let savedEventId = editingEventId;
      if (editingEventId) {
        await updateDoc(doc(db, 'recharge_bonus_events', editingEventId), data);
        showMsg('✅ Event successfully updated.');
      } else {
        const ref = await addDoc(collection(db, 'recharge_bonus_events'), {
          ...data,
          createdAt: Timestamp.now(),
        });
        savedEventId = ref.id;
        showMsg('✅ Event successfully created.');
      }

      // Single active event enforcement
      if (eventForm.isActive) {
        const activeQuery = query(
          collection(db, 'recharge_bonus_events'),
          where('isActive', '==', true)
        );
        const activeSnap = await getDocs(activeQuery);
        
        const batch = writeBatch(db);
        let hasUpdates = false;
        activeSnap.docs.forEach((docSnap) => {
          if (docSnap.id !== savedEventId) {
            batch.update(doc(db, 'recharge_bonus_events', docSnap.id), { isActive: false });
            hasUpdates = true;
          }
        });
        if (hasUpdates) {
          await batch.commit();
        }
      }

      resetEventForm();
    } catch (err) {
      showMsg('❌ Error saving event: ' + err.message, 'error');
    }
  };

  const handleDeleteEvent = async (id) => {
    if (!window.confirm('Are you sure you want to delete this event? This will not delete associated packages.')) return;
    try {
      await deleteDoc(doc(db, 'recharge_bonus_events', id));
      showMsg('✅ Event successfully deleted.');
    } catch (err) {
      showMsg('❌ Error deleting event: ' + err.message, 'error');
    }
  };

  // ──────── PACKAGE CRUD operations ────────────────────────

  const resetPackageForm = () => {
    setPackageForm({
      eventId: events[0]?.id || '',
      rechargeAmount: 1,
      baseCoins: 1000000,
      bonusCoins: 2000000,
      frameUrl: 'assets/images/super/super-admin.svga',
      validityDays: 1,
      sortOrder: 1,
      isActive: true,
    });
    setEditingPackageId(null);
    setShowPackageForm(false);
  };

  const handleEditPackage = (pkg) => {
    setPackageForm({
      eventId: pkg.eventId || '',
      rechargeAmount: pkg.rechargeAmount || 1,
      baseCoins: pkg.baseCoins || 0,
      bonusCoins: pkg.bonusCoins || 0,
      frameUrl: pkg.frameUrl || 'assets/images/super/super-admin.svga',
      validityDays: pkg.validityDays || (pkg.rechargeAmount >= 100 ? 14 : (pkg.rechargeAmount >= 10 ? 7 : (pkg.rechargeAmount >= 5 ? 3 : 1))),
      sortOrder: pkg.sortOrder || 1,
      isActive: pkg.isActive !== false,
    });
    setEditingPackageId(pkg.id);
    setShowPackageForm(true);
  };

  const handleSavePackage = async (e) => {
    e.preventDefault();
    if (!packageForm.eventId) {
      showMsg('❌ Please select an active event first.', 'error');
      return;
    }

    const amt = Number(packageForm.rechargeAmount);
    const base = Number(packageForm.baseCoins);
    const bonus = Number(packageForm.bonusCoins);
    const sort = Number(packageForm.sortOrder);
    const days = Number(packageForm.validityDays || 1);

    if (amt <= 0 || base < 0 || bonus < 0 || sort < 0 || days <= 0) {
      showMsg('❌ Negative values are not allowed. Recharge Amount and Validity Days must be greater than zero.', 'error');
      return;
    }

    // Prevent duplicate package recharge amounts for the same event
    const isDuplicate = packages.some(p => 
      p.eventId === packageForm.eventId && 
      Number(p.rechargeAmount) === amt && 
      p.id !== editingPackageId
    );
    if (isDuplicate) {
      showMsg(`❌ A package for $${amt} already exists for this event.`, 'error');
      return;
    }

    try {
      const data = {
        eventId: packageForm.eventId,
        rechargeAmount: amt,
        baseCoins: base,
        bonusCoins: bonus,
        totalCoins: base + bonus,
        frameUrl: packageForm.frameUrl || 'assets/images/super/super-admin.svga',
        validityDays: days,
        sortOrder: sort,
        isActive: packageForm.isActive,
      };

      if (editingPackageId) {
        await updateDoc(doc(db, 'recharge_bonus_packages', editingPackageId), data);
        showMsg('✅ Package successfully updated.');
      } else {
        await addDoc(collection(db, 'recharge_bonus_packages'), data);
        showMsg('✅ Package successfully created.');
      }
      resetPackageForm();
    } catch (err) {
      showMsg('❌ Error saving package: ' + err.message, 'error');
    }
  };

  const handleDeletePackage = async (id) => {
    if (!window.confirm('Delete this package?')) return;
    try {
      await deleteDoc(doc(db, 'recharge_bonus_packages', id));
      showMsg('✅ Package successfully deleted.');
    } catch (err) {
      showMsg('❌ Error deleting package: ' + err.message, 'error');
    }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-indigo-500/20 rounded-2xl border border-indigo-500/30">
              <Coins className="text-indigo-400" size={28} />
            </div>
            Recharge Rebate Event
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Configure dynamic recharge events & bonuses for Hello Chat users
          </p>
        </div>

        {/* Tab Selection */}
        <div className="flex bg-[#111115] border border-white/[0.04] p-1.5 rounded-2xl">
          {TABS.map((tab) => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => {
                  setActiveTab(tab.id);
                  setMessage(null);
                }}
                className={`flex items-center gap-2 px-5 py-3 rounded-xl text-xs font-black uppercase tracking-wider transition-all ${
                  active 
                    ? 'bg-indigo-600 text-white shadow-lg' 
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                <Icon size={14} />
                {tab.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Alert Messaging HUD */}
      {message && (
        <div className={`p-4 rounded-2xl flex items-center gap-3 border ${
          message.type === 'error' 
            ? 'bg-rose-500/10 border-rose-500/20 text-rose-400' 
            : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
        }`}>
          <AlertCircle size={18} />
          <p className="text-xs font-black uppercase tracking-wider">{message.text}</p>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="w-10 h-10 border-4 border-indigo-500/20 border-t-indigo-500 rounded-full animate-spin"></div>
        </div>
      ) : (
        <div>
          {/* ── EVENTS MANAGEMENT TAB ───────────────────────── */}
          {activeTab === 'events' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <p className="text-slate-400 text-sm">
                  Create and manage active recharge campaigns. Only active campaigns that are within their start/end dates will show up on user devices.
                </p>
                {!showEventForm && (
                  <button 
                    onClick={() => { resetEventForm(); setShowEventForm(true); }}
                    className="flex items-center gap-2 px-6 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-black uppercase tracking-wider transition-all"
                  >
                    <Plus size={16} /> New Event
                  </button>
                )}
              </div>

              {showEventForm && (
                <form onSubmit={handleSaveEvent} className="bg-[#111115] border border-white/[0.04] p-8 rounded-3xl space-y-6">
                  <h3 className="text-lg font-bold border-b border-white/[0.04] pb-4 flex items-center justify-between">
                    <span>{editingEventId ? 'Edit Event Details' : 'Create New Recharge Event'}</span>
                    <button type="button" onClick={resetEventForm} className="p-2 hover:bg-white/5 rounded-lg text-slate-400 hover:text-white">
                      <X size={16} />
                    </button>
                  </h3>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Event Title</label>
                      <input 
                        type="text" placeholder="e.g. Recharge Bonus Event"
                        className="glass-input w-full h-14"
                        value={eventForm.title} onChange={e => setEventForm({...eventForm, title: e.target.value})}
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Banner Artwork Image URL</label>
                      <input 
                        type="text" placeholder="e.g. https://domain.com/artwork.jpg"
                        className="glass-input w-full h-14"
                        value={eventForm.bannerImage} onChange={e => setEventForm({...eventForm, bannerImage: e.target.value})}
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Hosted Event Web URL (Optional)</label>
                    <input 
                      type="text" placeholder="e.g. https://hellochat-admin.netlify.app/premium_event/ (leave empty for local fallback)"
                      className="glass-input w-full h-14"
                      value={eventForm.webUrl} onChange={e => setEventForm({...eventForm, webUrl: e.target.value})}
                    />
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Start Date & Time</label>
                      <input 
                        type="datetime-local"
                        className="glass-input w-full h-14 text-white"
                        value={eventForm.startDate} onChange={e => setEventForm({...eventForm, startDate: e.target.value})}
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">End Date & Time</label>
                      <input 
                        type="datetime-local"
                        className="glass-input w-full h-14 text-white"
                        value={eventForm.endDate} onChange={e => setEventForm({...eventForm, endDate: e.target.value})}
                      />
                    </div>
                    <div className="flex items-end pb-3">
                      <label className="flex items-center gap-4 cursor-pointer p-4 bg-white/5 border border-white/5 rounded-2xl w-full h-14 hover:bg-white/10 transition-all">
                        <input 
                          type="checkbox" 
                          className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-indigo-600 focus:ring-indigo-600 focus:ring-offset-0"
                          checked={eventForm.isActive} onChange={e => setEventForm({...eventForm, isActive: e.target.checked})}
                        />
                        <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Activate Event Immediately</span>
                      </label>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Event Rules & Description</label>
                    <textarea 
                      placeholder="Enter detailed rules and rebate text..."
                      className="glass-input w-full h-32 py-4 resize-none"
                      value={eventForm.description} onChange={e => setEventForm({...eventForm, description: e.target.value})}
                    />
                  </div>

                  {eventForm.webUrl && (
                    <div className="space-y-2 border-t border-white/[0.04] pt-6">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest flex items-center gap-2">
                        <Monitor size={12} className="text-[#00E5FF]" /> Live Web Event Preview
                      </label>
                      <div className="border border-white/10 rounded-2xl overflow-hidden bg-slate-950 flex justify-center items-center shadow-inner relative mx-auto" style={{ height: '640px', width: '375px', marginTop: '10px' }}>
                        <iframe 
                          src={`${eventForm.webUrl}${eventForm.webUrl.endsWith('/') ? '' : '/'}?recharge=45&eventId=${editingEventId || 'preview'}`} 
                          title="Hosted Event Preview" 
                          width="100%" 
                          height="100%" 
                          className="border-none"
                        />
                      </div>
                    </div>
                  )}

                  <div className="flex gap-4 pt-4 border-t border-white/[0.04]">
                    <button type="submit" className="px-8 h-12 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-black uppercase tracking-widest flex items-center gap-2">
                      <Save size={16} /> Save Event Configuration
                    </button>
                    <button type="button" onClick={resetEventForm} className="px-6 h-12 bg-white/5 hover:bg-white/10 text-white rounded-xl text-xs font-black uppercase tracking-widest">
                      Cancel
                    </button>
                  </div>
                </form>
              )}

              {/* Events Table List */}
              <div className="bg-[#111115] border border-white/[0.04] rounded-3xl overflow-hidden shadow-2xl">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-white/[0.02] border-b border-white/[0.04] text-[10px] font-black text-slate-500 uppercase tracking-wider">
                      <th className="p-5">Banner Preview</th>
                      <th className="p-5">Event Title</th>
                      <th className="p-5">Start Date (UTC)</th>
                      <th className="p-5">End Date (UTC)</th>
                      <th className="p-5">Status</th>
                      <th className="p-5 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/[0.02] text-xs">
                    {events.length === 0 ? (
                      <tr>
                        <td colSpan="6" className="p-10 text-center text-slate-500 uppercase font-black">No events configured yet.</td>
                      </tr>
                    ) : (
                      events.map((ev) => {
                        const now = new Date();
                        const start = new Date(ev.startDate);
                        const end = new Date(ev.endDate);
                        const isExpired = now > end;
                        const isLive = ev.isActive && !isExpired && now >= start;

                        return (
                          <tr key={ev.id} className="hover:bg-white/[0.01] transition-colors">
                            <td className="p-5 w-44">
                              <div className="w-36 h-16 rounded-xl overflow-hidden border border-white/5 relative bg-slate-900">
                                <img src={ev.bannerImage} className="w-full h-full object-cover" alt="Banner" />
                              </div>
                            </td>
                            <td className="p-5 font-bold text-white max-w-xs truncate">
                              <div>{ev.title}</div>
                              {ev.webUrl && (
                                <div className="text-[9px] text-[#00E5FF] font-mono mt-0.5 flex items-center gap-1">
                                  <Globe size={10} /> {ev.webUrl}
                                </div>
                              )}
                              <div className="text-[10px] font-medium text-slate-500 mt-1 truncate">{ev.description}</div>
                            </td>
                            <td className="p-5 text-slate-400 font-mono">{ev.startDate.replace('T', ' ')}</td>
                            <td className="p-5 text-slate-400 font-mono">{ev.endDate.replace('T', ' ')}</td>
                            <td className="p-5">
                              {isLive ? (
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 uppercase tracking-widest">
                                  <Check size={8} /> LIVE
                                </span>
                              ) : isExpired ? (
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-slate-500/10 text-slate-400 border border-white/10 uppercase tracking-widest">
                                  EXPIRED
                                </span>
                              ) : !ev.isActive ? (
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-rose-500/10 text-rose-400 border border-rose-500/20 uppercase tracking-widest">
                                  INACTIVE
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-amber-500/10 text-amber-400 border border-amber-500/20 uppercase tracking-widest">
                                  UPCOMING
                                </span>
                              )}
                            </td>
                            <td className="p-5 text-right">
                              <div className="flex justify-end gap-3">
                                <button onClick={() => handleEditEvent(ev)} className="p-2 hover:bg-indigo-600/20 text-indigo-400 rounded-lg transition-all border border-indigo-500/10">
                                  <Edit2 size={14} />
                                </button>
                                <button onClick={() => handleDeleteEvent(ev)} className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg transition-all border border-rose-500/10">
                                  <Trash2 size={14} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ── PACKAGES CONFIGURATION TAB ──────────────────── */}
          {activeTab === 'packages' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <p className="text-slate-400 text-sm">
                  Add bonus multiplier packages to events. Make sure to map each package to its correct parent Recharge Event.
                </p>
                {!showPackageForm && (
                  <button 
                    onClick={() => { resetPackageForm(); setShowPackageForm(true); }}
                    className="flex items-center gap-2 px-6 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-black uppercase tracking-wider transition-all"
                  >
                    <Plus size={16} /> Add Package
                  </button>
                )}
              </div>

              {showPackageForm && (
                <form onSubmit={handleSavePackage} className="bg-[#111115] border border-white/[0.04] p-8 rounded-3xl space-y-6">
                  <h3 className="text-lg font-bold border-b border-white/[0.04] pb-4 flex items-center justify-between">
                    <span>{editingPackageId ? 'Edit Package Data' : 'Add Package to Event'}</span>
                    <button type="button" onClick={resetPackageForm} className="p-2 hover:bg-white/5 rounded-lg text-slate-400 hover:text-white">
                      <X size={16} />
                    </button>
                  </h3>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Select Parent Event</label>
                      <select 
                        className="glass-input w-full h-14 px-4 appearance-none cursor-pointer text-white bg-slate-900 border border-white/5 rounded-2xl"
                        value={packageForm.eventId} onChange={e => setPackageForm({...packageForm, eventId: e.target.value})}
                      >
                        <option value="" disabled>Choose campaign...</option>
                        {events.map(ev => (
                          <option key={ev.id} value={ev.id}>{ev.title}</option>
                        ))}
                      </select>
                    </div>

                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Recharge Amount ($ USD)</label>
                      <input 
                        type="number" min="1" step="any" placeholder="e.g. 1"
                        className="glass-input w-full h-14"
                        value={packageForm.rechargeAmount} onChange={e => setPackageForm({...packageForm, rechargeAmount: e.target.value})}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Base Coins Value</label>
                      <input 
                        type="number" min="0" placeholder="e.g. 1000000"
                        className="glass-input w-full h-14"
                        value={packageForm.baseCoins} onChange={e => setPackageForm({...packageForm, baseCoins: e.target.value})}
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Bonus Coins Reward</label>
                      <input 
                        type="number" min="0" placeholder="e.g. 2000000"
                        className="glass-input w-full h-14"
                        value={packageForm.bonusCoins} onChange={e => setPackageForm({...packageForm, bonusCoins: e.target.value})}
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Total Coins (Calculated)</label>
                      <div className="glass-input w-full h-14 flex items-center px-5 text-slate-400 bg-slate-900 border border-white/5 rounded-2xl font-bold">
                        {(Number(packageForm.baseCoins || 0) + Number(packageForm.bonusCoins || 0)).toLocaleString()} Coins
                      </div>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Unlocked Frame Asset URL / Path</label>
                      <input 
                        type="text" placeholder="assets/images/super/super-admin.svga"
                        className="glass-input w-full h-14"
                        value={packageForm.frameUrl} onChange={e => setPackageForm({...packageForm, frameUrl: e.target.value})}
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Frame Validity Period (Days)</label>
                      <input 
                        type="number" min="1" placeholder="1 (1 Day), 3, 7, 14..."
                        className="glass-input w-full h-14"
                        value={packageForm.validityDays} onChange={e => setPackageForm({...packageForm, validityDays: e.target.value})}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Sort Order (Lower is first)</label>
                      <input 
                        type="number" min="1" placeholder="e.g. 1"
                        className="glass-input w-full h-14"
                        value={packageForm.sortOrder} onChange={e => setPackageForm({...packageForm, sortOrder: e.target.value})}
                      />
                    </div>
                    <div className="flex items-end pb-3">
                      <label className="flex items-center gap-4 cursor-pointer p-4 bg-white/5 border border-white/5 rounded-2xl w-full h-14 hover:bg-white/10 transition-all">
                        <input 
                          type="checkbox" 
                          className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-indigo-600 focus:ring-indigo-600 focus:ring-offset-0"
                          checked={packageForm.isActive} onChange={e => setPackageForm({...packageForm, isActive: e.target.checked})}
                        />
                        <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Enable Package Immediately</span>
                      </label>
                    </div>
                  </div>

                  <div className="flex gap-4 pt-4 border-t border-white/[0.04]">
                    <button type="submit" className="px-8 h-12 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-black uppercase tracking-widest flex items-center gap-2">
                      <Save size={16} /> Save Package Data
                    </button>
                    <button type="button" onClick={resetPackageForm} className="px-6 h-12 bg-white/5 hover:bg-white/10 text-white rounded-xl text-xs font-black uppercase tracking-widest">
                      Cancel
                    </button>
                  </div>
                </form>
              )}

              {/* Packages Table List */}
              <div className="bg-[#111115] border border-white/[0.04] rounded-3xl overflow-hidden shadow-2xl">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-white/[0.02] border-b border-white/[0.04] text-[10px] font-black text-slate-500 uppercase tracking-wider">
                      <th className="p-5">Associated Event</th>
                      <th className="p-5">Recharge Amount</th>
                      <th className="p-5">Base Coins</th>
                      <th className="p-5">Bonus Coins</th>
                      <th className="p-5">Frame Reward & Validity</th>
                      <th className="p-5">Sort Order</th>
                      <th className="p-5">Status</th>
                      <th className="p-5 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/[0.02] text-xs">
                    {packages.length === 0 ? (
                      <tr>
                        <td colSpan="8" className="p-10 text-center text-slate-500 uppercase font-black">No packages configured yet.</td>
                      </tr>
                    ) : (
                      packages.map((pkg) => {
                        const ev = events.find(e => e.id === pkg.eventId);
                        const days = pkg.validityDays || (pkg.rechargeAmount >= 100 ? 14 : (pkg.rechargeAmount >= 10 ? 7 : (pkg.rechargeAmount >= 5 ? 3 : 1)));
                        return (
                          <tr key={pkg.id} className="hover:bg-white/[0.01] transition-colors">
                            <td className="p-5 font-bold text-white max-w-xs truncate">
                              {ev ? ev.title : <span className="text-slate-500 italic">Unknown Event ({pkg.eventId})</span>}
                            </td>
                            <td className="p-5 text-indigo-400 font-black font-mono">${pkg.rechargeAmount} USD</td>
                            <td className="p-5 text-slate-300 font-mono">{(pkg.baseCoins || 0).toLocaleString()}</td>
                            <td className="p-5 text-amber-500 font-mono">+{(pkg.bonusCoins || 0).toLocaleString()}</td>
                            <td className="p-5 text-pink-400 font-bold font-mono">
                              <div>{pkg.frameUrl ? pkg.frameUrl.split('/').pop() : 'Default Frame'}</div>
                              <div className="text-[10px] text-slate-400 font-normal">⏱️ {days} Day{days > 1 ? 's' : ''} Validity</div>
                            </td>
                            <td className="p-5 text-slate-400 font-mono">{pkg.sortOrder}</td>
                            <td className="p-5">
                              {pkg.isActive ? (
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 uppercase tracking-widest">
                                  ACTIVE
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black bg-rose-500/10 text-rose-400 border border-rose-500/20 uppercase tracking-widest">
                                  DISABLED
                                </span>
                              )}
                            </td>
                            <td className="p-5 text-right">
                              <div className="flex justify-end gap-3">
                                <button onClick={() => handleEditPackage(pkg)} className="p-2 hover:bg-indigo-600/20 text-indigo-400 rounded-lg transition-all border border-indigo-500/10">
                                  <Edit2 size={14} />
                                </button>
                                <button onClick={() => handleDeletePackage(pkg)} className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg transition-all border border-rose-500/10">
                                  <Trash2 size={14} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

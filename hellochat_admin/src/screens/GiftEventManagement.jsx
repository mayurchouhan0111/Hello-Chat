import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
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
  where 
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { 
  Calendar, 
  Gift, 
  Trophy, 
  Crown, 
  Sparkles, 
  Plus, 
  Trash2, 
  Edit2, 
  Save, 
  X, 
  Check, 
  AlertCircle, 
  Play, 
  Square, 
  RotateCcw, 
  Award, 
  Image as ImageIcon, 
  Layers,
  ChevronRight,
  Clock,
  Flame,
  Search
} from 'lucide-react';

const TABS = [
  { id: 'events', label: 'All Events', icon: Calendar },
  { id: 'builder', label: 'Event Builder & Gifts', icon: Layers },
  { id: 'leaderboard', label: 'Live Leaderboard', icon: Trophy },
];

export const GiftEventManagement = () => {
  const [activeTab, setActiveTab] = useState('events');
  const [events, setEvents] = useState([]);
  const [availableGifts, setAvailableGifts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Selected event for leaderboard view
  const [selectedLeaderboardEventId, setSelectedLeaderboardEventId] = useState('');
  const [leaderboardData, setLeaderboardData] = useState([]);
  const [leaderboardLoading, setLeaderboardLoading] = useState(false);

  // Form State
  const [editingEventId, setEditingEventId] = useState(null);
  const [eventForm, setEventForm] = useState({
    title: '',
    description: '',
    rules: '',
    bannerUrl: '',
    backgroundUrl: '',
    themeColor: '#FFD700',
    startDate: '',
    endDate: '',
    isActive: true,
    rankingDuration: 'event_duration', // 'event_duration' | 'daily' | 'weekly'
    rankingDisplayCount: 50,
    gifts: [],
    rewards: [],
  });

  // Gift item sub-form
  const [giftPicker, setGiftPicker] = useState({
    giftId: '',
    name: '',
    priceInDiamonds: 100,
    eventPoints: 100,
    imageUrl: '',
  });

  // Reward tier sub-form
  const [rewardTierForm, setRewardTierForm] = useState({
    rankFrom: 1,
    rankTo: 1,
    title: 'Rank 1 Champion',
    diamonds: 500000,
    frameUrl: 'assets/VIP/VIP 1/Frame.svga',
    frameDays: 30,
    avatarFrameUrl: '',
    entryEffectUrl: '',
    badgeTitle: 'Carnival King',
    customReward: 'Exclusive Golden Entry Banner',
  });

  // 1. Listen to Events
  useEffect(() => {
    setLoading(true);
    const eventsQuery = query(collection(db, 'gift_events'), orderBy('createdAt', 'desc'));
    const unsubEvents = onSnapshot(eventsQuery, (snap) => {
      const evList = snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          ...data,
          startDateIso: data.startDate?.toDate ? data.startDate.toDate().toISOString().substring(0, 16) : '',
          endDateIso: data.endDate?.toDate ? data.endDate.toDate().toISOString().substring(0, 16) : '',
        };
      });
      setEvents(evList);
      if (evList.length > 0 && !selectedLeaderboardEventId) {
        setSelectedLeaderboardEventId(evList[0].id);
      }
      setLoading(false);
    }, (err) => {
      console.error("Error loading events:", err);
      setLoading(false);
    });

    // 2. Fetch platform gifts for selection
    const fetchPlatformGifts = async () => {
      try {
        const giftsSnap = await getDocs(query(collection(db, 'gifts'), where('isActive', '==', true)));
        const giftsList = giftsSnap.docs.map(d => ({
          giftId: d.id,
          name: d.data().name || d.id,
          priceInDiamonds: d.data().priceInDiamonds || 10,
          imageUrl: d.data().imageUrl || '🎁',
        }));
        setAvailableGifts(giftsList);
        if (giftsList.length > 0) {
          setGiftPicker(prev => ({
            ...prev,
            giftId: giftsList[0].giftId,
            name: giftsList[0].name,
            priceInDiamonds: giftsList[0].priceInDiamonds,
            eventPoints: giftsList[0].priceInDiamonds,
            imageUrl: giftsList[0].imageUrl,
          }));
        }
      } catch (e) {
        console.warn("Error fetching gifts:", e);
      }
    };
    fetchPlatformGifts();

    return () => unsubEvents();
  }, []);

  // 3. Listen to Leaderboard for selected event
  useEffect(() => {
    if (!selectedLeaderboardEventId) {
      setLeaderboardData([]);
      return;
    }
    setLeaderboardLoading(true);
    const participantsQuery = query(
      collection(db, 'gift_events', selectedLeaderboardEventId, 'participants'),
      orderBy('points', 'desc')
    );
    const unsubLeaderboard = onSnapshot(participantsQuery, (snap) => {
      setLeaderboardData(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLeaderboardLoading(false);
    }, (err) => {
      console.warn("Leaderboard listen error:", err);
      setLeaderboardLoading(false);
    });

    return () => unsubLeaderboard();
  }, [selectedLeaderboardEventId]);

  const showToast = (type, text) => {
    setMessage({ type, text });
    setTimeout(() => setMessage(null), 4500);
  };

  const handleStartCreate = () => {
    const now = new Date();
    const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    setEditingEventId(null);
    setEventForm({
      title: 'New Spring Carnival Gift War',
      description: 'Send special event gifts, top the leaderboard, and unlock luxury rewards!',
      rules: '1. Send designated event gifts to collect Event Points.\n2. Points are credited atomically on every gift sent.\n3. Top rankers receive Diamonds, exclusive profile frames, and badges at event end.',
      bannerUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?w=1000&auto=format&fit=crop',
      backgroundUrl: '',
      themeColor: '#FFD700',
      startDate: now.toISOString().substring(0, 16),
      endDate: nextWeek.toISOString().substring(0, 16),
      isActive: true,
      rankingDuration: 'event_duration',
      rankingDisplayCount: 50,
      gifts: availableGifts.slice(0, 3).map(g => ({
        giftId: g.giftId,
        name: g.name,
        priceInDiamonds: g.priceInDiamonds,
        eventPoints: g.priceInDiamonds * 2, // 2x points default
        imageUrl: g.imageUrl,
      })),
      rewards: [
        {
          rankFrom: 1,
          rankTo: 1,
          title: 'Rank 1 Champion',
          diamonds: 500000,
          frameUrl: 'assets/VIP/VIP 1/Frame.svga',
          frameDays: 30,
          avatarFrameUrl: '',
          entryEffectUrl: '',
          badgeTitle: 'Carnival King',
          customReward: 'Permanent Golden Nameplate',
        },
        {
          rankFrom: 2,
          rankTo: 3,
          title: 'Top 2-3 Silver Tier',
          diamonds: 250000,
          frameUrl: 'assets/VIP/VIP 1/Frame.svga',
          frameDays: 15,
          avatarFrameUrl: '',
          entryEffectUrl: '',
          badgeTitle: 'Carnival Hero',
          customReward: '15-Day Glory Aura',
        },
        {
          rankFrom: 4,
          rankTo: 10,
          title: 'Top 4-10 Elite Tier',
          diamonds: 50000,
          frameUrl: '',
          frameDays: 7,
          avatarFrameUrl: '',
          entryEffectUrl: '',
          badgeTitle: 'Carnival Elite',
          customReward: '7-Day Profile Badge',
        }
      ],
    });
    setActiveTab('builder');
  };

  const handleEditEvent = (ev) => {
    setEditingEventId(ev.id);
    setEventForm({
      title: ev.title || '',
      description: ev.description || '',
      rules: ev.rules || '',
      bannerUrl: ev.bannerUrl || '',
      backgroundUrl: ev.backgroundUrl || '',
      themeColor: ev.themeColor || '#FFD700',
      startDate: ev.startDateIso || '',
      endDate: ev.endDateIso || '',
      isActive: ev.isActive !== false,
      rankingDuration: ev.rankingDuration || 'event_duration',
      rankingDisplayCount: ev.rankingDisplayCount || 50,
      gifts: Array.isArray(ev.gifts) ? ev.gifts : [],
      rewards: Array.isArray(ev.rewards) ? ev.rewards : [],
    });
    setActiveTab('builder');
  };

  const handleSaveEvent = async (e) => {
    e.preventDefault();
    if (!eventForm.title.trim()) {
      showToast('error', 'Please enter an event title.');
      return;
    }
    if (!eventForm.startDate || !eventForm.endDate) {
      showToast('error', 'Please select valid start and end dates.');
      return;
    }
    if (eventForm.gifts.length === 0) {
      showToast('error', 'Please add at least one Event Gift.');
      return;
    }

    try {
      setActionLoading(true);
      const payload = {
        title: eventForm.title.trim(),
        description: eventForm.description.trim(),
        rules: eventForm.rules.trim(),
        bannerUrl: eventForm.bannerUrl.trim(),
        backgroundUrl: eventForm.backgroundUrl.trim(),
        themeColor: eventForm.themeColor || '#FFD700',
        startDate: Timestamp.fromDate(new Date(eventForm.startDate)),
        endDate: Timestamp.fromDate(new Date(eventForm.endDate)),
        isActive: eventForm.isActive,
        rankingDuration: eventForm.rankingDuration,
        rankingDisplayCount: Number(eventForm.rankingDisplayCount) || 50,
        gifts: eventForm.gifts,
        rewards: eventForm.rewards,
        updatedAt: Timestamp.now(),
      };

      if (editingEventId) {
        await updateDoc(doc(db, 'gift_events', editingEventId), payload);
        showToast('success', 'Event updated successfully!');
      } else {
        payload.createdAt = Timestamp.now();
        payload.totalEventPoints = 0;
        payload.totalGiftsSent = 0;
        payload.totalDiamondsSpent = 0;
        await addDoc(collection(db, 'gift_events'), payload);
        showToast('success', 'New Gift Event created successfully!');
      }
      setActiveTab('events');
    } catch (err) {
      console.error('Error saving event:', err);
      showToast('error', 'Failed to save event: ' + err.message);
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggleEventStatus = async (ev) => {
    try {
      const nextStatus = !ev.isActive;
      await updateDoc(doc(db, 'gift_events', ev.id), {
        isActive: nextStatus,
        updatedAt: Timestamp.now(),
      });
      showToast('success', `Event ${nextStatus ? 'Activated' : 'Disabled'}!`);
    } catch (err) {
      showToast('error', 'Could not update status: ' + err.message);
    }
  };

  const handleDeleteEvent = async (id) => {
    if (!window.confirm('Are you sure you want to delete this event? This will remove the event configuration.')) return;
    try {
      await deleteDoc(doc(db, 'gift_events', id));
      showToast('success', 'Event deleted.');
    } catch (err) {
      showToast('error', 'Delete failed: ' + err.message);
    }
  };

  const handleRestartEvent = async (ev) => {
    if (!window.confirm(`Restart event "${ev.title}"? This will set start date to NOW and extend end date by 7 days.`)) return;
    try {
      const now = new Date();
      const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
      await updateDoc(doc(db, 'gift_events', ev.id), {
        startDate: Timestamp.fromDate(now),
        endDate: Timestamp.fromDate(nextWeek),
        isActive: true,
        distributed: false,
        updatedAt: Timestamp.now(),
      });
      showToast('success', 'Event restarted successfully!');
    } catch (err) {
      showToast('error', 'Failed to restart event: ' + err.message);
    }
  };

  const handleDistributeRewards = async (eventId) => {
    if (!window.confirm('Distribute configured event rewards to top leaderboard winners? This will credit Diamonds and frames.')) return;
    try {
      setActionLoading(true);
      const distributeFn = httpsCallable(functions, 'distributeGiftEventRewards');
      const res = await distributeFn({ eventId });
      showToast('success', `Rewards distributed! Rewarded ${res.data?.rewardedCount || 0} participants.`);
    } catch (err) {
      console.error('Reward distribution failed:', err);
      showToast('error', 'Distribution error: ' + err.message);
    } finally {
      setActionLoading(false);
    }
  };

  // Gift sub-form handlers
  const handleAddGiftToEvent = () => {
    if (!giftPicker.giftId) {
      showToast('error', 'Select a gift first.');
      return;
    }
    const exists = eventForm.gifts.some(g => g.giftId === giftPicker.giftId);
    if (exists) {
      showToast('error', 'This gift is already in the event list.');
      return;
    }
    setEventForm(prev => ({
      ...prev,
      gifts: [
        ...prev.gifts,
        {
          giftId: giftPicker.giftId,
          name: giftPicker.name,
          priceInDiamonds: Number(giftPicker.priceInDiamonds) || 10,
          eventPoints: Number(giftPicker.eventPoints) || Number(giftPicker.priceInDiamonds) || 10,
          imageUrl: giftPicker.imageUrl || '🎁',
        }
      ]
    }));
  };

  const handleRemoveGiftFromEvent = (giftId) => {
    setEventForm(prev => ({
      ...prev,
      gifts: prev.gifts.filter(g => g.giftId !== giftId)
    }));
  };

  // Reward tier sub-form handlers
  const handleAddRewardTier = () => {
    if (Number(rewardTierForm.rankFrom) > Number(rewardTierForm.rankTo)) {
      showToast('error', 'Rank From must be less than or equal to Rank To.');
      return;
    }
    setEventForm(prev => ({
      ...prev,
      rewards: [
        ...prev.rewards,
        {
          ...rewardTierForm,
          rankFrom: Number(rewardTierForm.rankFrom),
          rankTo: Number(rewardTierForm.rankTo),
          diamonds: Number(rewardTierForm.diamonds) || 0,
          frameDays: Number(rewardTierForm.frameDays) || 30,
        }
      ]
    }));
  };

  const handleRemoveRewardTier = (index) => {
    setEventForm(prev => ({
      ...prev,
      rewards: prev.rewards.filter((_, i) => i !== index)
    }));
  };

  return (
    <div className="space-y-6 animate-fade-in text-white">
      {/* Top Banner Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-slate-900/60 p-6 rounded-3xl border border-white/[0.06] backdrop-blur-xl relative overflow-hidden">
        <div className="absolute -right-10 -bottom-10 w-48 h-48 bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div className="flex items-center gap-4 relative z-10">
          <div className="p-3.5 bg-gradient-to-tr from-amber-500 to-orange-500 rounded-2xl shadow-lg shadow-orange-500/20 text-black">
            <Gift size={28} className="stroke-[2.5]" />
          </div>
          <div>
            <h1 className="text-2xl font-black tracking-tight text-white flex items-center gap-2">
              Gift Event System <Sparkles className="text-amber-400" size={20} />
            </h1>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">
              Create live gift events, assign custom point values, configure rank rewards, and monitor real-time leaderboards.
            </p>
          </div>
        </div>

        <button
          onClick={handleStartCreate}
          className="relative z-10 flex items-center gap-2 px-5 py-2.5 rounded-2xl font-black text-xs uppercase tracking-wider bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 text-black transition-all shadow-lg shadow-amber-500/20 active:scale-95"
        >
          <Plus size={16} className="stroke-[3]" /> Create New Event
        </button>
      </div>

      {/* Toast Message */}
      {message && (
        <div className={`p-4 rounded-2xl flex items-center gap-3 text-sm font-bold border transition-all ${
          message.type === 'success' 
            ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400' 
            : 'bg-rose-500/10 border-rose-500/20 text-rose-400'
        }`}>
          {message.type === 'success' ? <Check size={18} /> : <AlertCircle size={18} />}
          <span>{message.text}</span>
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-2 border-b border-white/[0.06] pb-2">
        {TABS.map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-xs uppercase tracking-wider transition-all ${
                isActive
                  ? 'bg-amber-400/10 text-amber-400 border border-amber-400/20 shadow-sm'
                  : 'text-slate-400 hover:text-white hover:bg-white/[0.04]'
              }`}
            >
              <Icon size={16} />
              {tab.label}
              {tab.id === 'events' && (
                <span className="ml-1.5 px-2 py-0.5 rounded-full text-[10px] font-black bg-white/[0.06] text-slate-300">
                  {events.length}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* TAB 1: ALL EVENTS */}
      {activeTab === 'events' && (
        <div className="space-y-4">
          {loading ? (
            <div className="flex justify-center p-12 text-slate-500 font-bold">Loading gift events...</div>
          ) : events.length === 0 ? (
            <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-white/[0.06]">
              <Gift size={48} className="mx-auto text-slate-600 mb-3" />
              <h3 className="text-lg font-bold text-white">No Gift Events Found</h3>
              <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                No active or scheduled gift events found in Firestore. Click "Create New Event" above to launch one.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              {events.map(ev => {
                const now = new Date();
                const start = ev.startDate?.toDate ? ev.startDate.toDate() : new Date(ev.startDate);
                const end = ev.endDate?.toDate ? ev.endDate.toDate() : new Date(ev.endDate);
                const isLiveNow = ev.isActive && now >= start && now <= end;
                const isEnded = now > end;

                return (
                  <div 
                    key={ev.id}
                    className="bg-slate-900/70 border border-white/[0.06] rounded-3xl overflow-hidden hover:border-amber-400/30 transition-all flex flex-col justify-between shadow-lg"
                  >
                    {/* Event Banner */}
                    <div className="relative h-40 bg-slate-800 overflow-hidden">
                      {ev.bannerUrl ? (
                        <img src={ev.bannerUrl} alt={ev.title} className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-amber-500/20 to-orange-500/20">
                          <Gift size={40} className="text-amber-400/50" />
                        </div>
                      )}
                      <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/40 to-transparent"></div>

                      {/* Status Pills */}
                      <div className="absolute top-3 left-3 flex gap-2">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider border ${
                          isLiveNow
                            ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30 animate-pulse'
                            : isEnded
                            ? 'bg-slate-500/20 text-slate-400 border-slate-500/30'
                            : !ev.isActive
                            ? 'bg-rose-500/20 text-rose-400 border-rose-500/30'
                            : 'bg-blue-500/20 text-blue-400 border-blue-500/30'
                        }`}>
                          {isLiveNow ? '● Live Now' : isEnded ? 'Ended' : !ev.isActive ? 'Disabled' : 'Scheduled'}
                        </span>

                        {ev.distributed && (
                          <span className="px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider bg-purple-500/20 text-purple-300 border border-purple-500/30">
                            ✓ Distributed
                          </span>
                        )}
                      </div>

                      {/* Title over banner */}
                      <div className="absolute bottom-3 left-3 right-3">
                        <h3 className="text-base font-black text-white truncate">{ev.title}</h3>
                        <p className="text-[11px] text-slate-300 line-clamp-1">{ev.description}</p>
                      </div>
                    </div>

                    {/* Event Stats & Details */}
                    <div className="p-4 space-y-3 flex-1 flex flex-col justify-between">
                      <div className="space-y-2 text-xs">
                        <div className="flex items-center justify-between text-slate-400">
                          <span className="flex items-center gap-1.5"><Clock size={13} /> Timeline:</span>
                          <span className="font-bold text-white text-[11px]">
                            {start.toLocaleDateString()} - {end.toLocaleDateString()}
                          </span>
                        </div>
                        <div className="flex items-center justify-between text-slate-400">
                          <span className="flex items-center gap-1.5"><Gift size={13} /> Event Gifts:</span>
                          <span className="font-bold text-amber-400">
                            {Array.isArray(ev.gifts) ? ev.gifts.length : 0} items
                          </span>
                        </div>
                        <div className="flex items-center justify-between text-slate-400">
                          <span className="flex items-center gap-1.5"><Trophy size={13} /> Reward Tiers:</span>
                          <span className="font-bold text-orange-400">
                            {Array.isArray(ev.rewards) ? ev.rewards.length : 0} tiers
                          </span>
                        </div>
                        <div className="flex items-center justify-between text-slate-400">
                          <span className="flex items-center gap-1.5"><Flame size={13} /> Total Event Points:</span>
                          <span className="font-black text-amber-300">
                            {(ev.totalEventPoints || 0).toLocaleString()}
                          </span>
                        </div>
                      </div>

                      {/* Action Buttons */}
                      <div className="pt-3 border-t border-white/[0.06] flex items-center justify-between gap-2">
                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => handleToggleEventStatus(ev)}
                            title={ev.isActive ? "Pause / Stop Event" : "Enable / Start Event"}
                            className={`p-2 rounded-xl border transition-all ${
                              ev.isActive 
                                ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/20' 
                                : 'bg-slate-800 border-white/10 text-slate-400 hover:text-white'
                            }`}
                          >
                            {ev.isActive ? <Square size={14} /> : <Play size={14} />}
                          </button>

                          <button
                            onClick={() => handleRestartEvent(ev)}
                            title="Restart Event (7-day cycle)"
                            className="p-2 rounded-xl bg-slate-800 border border-white/10 text-slate-400 hover:text-white transition-all"
                          >
                            <RotateCcw size={14} />
                          </button>

                          <button
                            onClick={() => handleEditEvent(ev)}
                            title="Edit Event & Gifts"
                            className="p-2 rounded-xl bg-amber-400/10 border border-amber-400/20 text-amber-400 hover:bg-amber-400/20 transition-all"
                          >
                            <Edit2 size={14} />
                          </button>

                          <button
                            onClick={() => {
                              setSelectedLeaderboardEventId(ev.id);
                              setActiveTab('leaderboard');
                            }}
                            title="View Leaderboard"
                            className="p-2 rounded-xl bg-orange-400/10 border border-orange-400/20 text-orange-400 hover:bg-orange-400/20 transition-all"
                          >
                            <Trophy size={14} />
                          </button>
                        </div>

                        <div className="flex items-center gap-1.5">
                          {isEnded && !ev.distributed && (
                            <button
                              disabled={actionLoading}
                              onClick={() => handleDistributeRewards(ev.id)}
                              className="px-2.5 py-1.5 rounded-xl bg-purple-500/20 border border-purple-500/30 text-purple-300 hover:bg-purple-500/30 text-[10px] font-black uppercase tracking-wider flex items-center gap-1 transition-all"
                            >
                              <Award size={12} /> Disburse
                            </button>
                          )}

                          <button
                            onClick={() => handleDeleteEvent(ev.id)}
                            title="Delete Event"
                            className="p-2 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 hover:bg-rose-500/20 transition-all"
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* TAB 2: EVENT BUILDER & GIFTS CONFIG */}
      {activeTab === 'builder' && (
        <form onSubmit={handleSaveEvent} className="space-y-6">
          {/* Section 1: Basic Information */}
          <div className="bg-slate-900/60 border border-white/[0.06] p-6 rounded-3xl space-y-4">
            <h2 className="text-base font-black uppercase tracking-wider text-amber-400 flex items-center gap-2">
              <Calendar size={18} /> Step 1: Event Information & Duration
            </h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-400 mb-1">Event Title *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Royal Ramadan Carnival"
                  value={eventForm.title}
                  onChange={e => setEventForm({ ...eventForm, title: e.target.value })}
                  className="w-full bg-slate-800/80 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-amber-400"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-400 mb-1">Theme Accent Color</label>
                <div className="flex gap-2">
                  <input
                    type="color"
                    value={eventForm.themeColor}
                    onChange={e => setEventForm({ ...eventForm, themeColor: e.target.value })}
                    className="h-10 w-14 bg-slate-800 border border-white/10 rounded-xl cursor-pointer p-1"
                  />
                  <input
                    type="text"
                    value={eventForm.themeColor}
                    onChange={e => setEventForm({ ...eventForm, themeColor: e.target.value })}
                    className="flex-1 bg-slate-800/80 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-amber-400"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-400 mb-1">Start Date & Time *</label>
                <input
                  type="datetime-local"
                  required
                  value={eventForm.startDate}
                  onChange={e => setEventForm({ ...eventForm, startDate: e.target.value })}
                  className="w-full bg-slate-800/80 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-amber-400"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-400 mb-1">End Date & Time *</label>
                <input
                  type="datetime-local"
                  required
                  value={eventForm.endDate}
                  onChange={e => setEventForm({ ...eventForm, endDate: e.target.value })}
                  className="w-full bg-slate-800/80 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-amber-400"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-xs font-bold text-slate-400 mb-1">Event Banner Image URL</label>
                <input
                  type="url"
                  placeholder="https://... image url"
                  value={eventForm.bannerUrl}
                  onChange={e => setEventForm({ ...eventForm, bannerUrl: e.target.value })}
                  className="w-full bg-slate-800/80 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-amber-400"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-xs font-bold text-slate-400 mb-1">Event Short Description</label>
                <input
                  type="text"
                  placeholder="Short tagline shown to users"
                  value={eventForm.description}
                  onChange={e => setEventForm({ ...eventForm, description: e.target.value })}
                  className="w-full bg-slate-800/80 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-amber-400"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-xs font-bold text-slate-400 mb-1">Event Rules & Guidelines</label>
                <textarea
                  rows={3}
                  placeholder="Detailed rules of the event..."
                  value={eventForm.rules}
                  onChange={e => setEventForm({ ...eventForm, rules: e.target.value })}
                  className="w-full bg-slate-800/80 border border-white/10 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-amber-400"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-400 mb-1">Ranking Duration</label>
                <select
                  value={eventForm.rankingDuration}
                  onChange={e => setEventForm({ ...eventForm, rankingDuration: e.target.value })}
                  className="w-full bg-slate-800 border border-white/10 rounded-xl px-4 py-2.5 text-sm font-semibold text-white"
                >
                  <option value="event_duration">Total Event Duration</option>
                  <option value="daily">Daily Reset Rankings</option>
                  <option value="weekly">Weekly Reset Rankings</option>
                </select>
              </div>

              <div className="flex items-center gap-3 pt-6">
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={eventForm.isActive}
                    onChange={e => setEventForm({ ...eventForm, isActive: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-800 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-amber-400"></div>
                </label>
                <span className="text-xs font-bold text-white">Event Active & Live</span>
              </div>
            </div>
          </div>

          {/* Section 2: Event Gifts Configuration */}
          <div className="bg-slate-900/60 border border-white/[0.06] p-6 rounded-3xl space-y-4">
            <h2 className="text-base font-black uppercase tracking-wider text-amber-400 flex items-center gap-2">
              <Gift size={18} /> Step 2: Assign Event Gifts & Point Values
            </h2>
            <p className="text-xs text-slate-400">
              When users send any of these gifts, the assigned <strong>Event Points</strong> are automatically credited to their account.
            </p>

            {/* Gift Picker Bar */}
            <div className="bg-slate-800/60 p-4 rounded-2xl border border-white/[0.06] grid grid-cols-1 sm:grid-cols-4 gap-3 items-end">
              <div>
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Select Existing Gift</label>
                <select
                  value={giftPicker.giftId}
                  onChange={e => {
                    const sel = availableGifts.find(g => g.giftId === e.target.value);
                    if (sel) {
                      setGiftPicker({
                        giftId: sel.giftId,
                        name: sel.name,
                        priceInDiamonds: sel.priceInDiamonds,
                        eventPoints: sel.priceInDiamonds,
                        imageUrl: sel.imageUrl,
                      });
                    }
                  }}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white"
                >
                  {availableGifts.map(g => (
                    <option key={g.giftId} value={g.giftId}>
                      {g.name} ({g.priceInDiamonds} 💎)
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Price (Diamonds)</label>
                <input
                  type="number"
                  value={giftPicker.priceInDiamonds}
                  onChange={e => setGiftPicker({ ...giftPicker, priceInDiamonds: parseInt(e.target.value) || 0 })}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Event Points Earned</label>
                <input
                  type="number"
                  value={giftPicker.eventPoints}
                  onChange={e => setGiftPicker({ ...giftPicker, eventPoints: parseInt(e.target.value) || 0 })}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-amber-400"
                />
              </div>

              <button
                type="button"
                onClick={handleAddGiftToEvent}
                className="w-full py-2 bg-amber-400/20 border border-amber-400/30 hover:bg-amber-400/30 text-amber-300 font-bold text-xs rounded-xl flex items-center justify-center gap-1.5 transition-all"
              >
                <Plus size={14} /> Add Event Gift
              </button>
            </div>

            {/* Event Gifts List */}
            <div className="grid grid-cols-1 sm:grid-cols-3 md:grid-cols-4 gap-3 pt-2">
              {eventForm.gifts.map(g => (
                <div key={g.giftId} className="bg-slate-800/80 border border-white/10 p-3 rounded-2xl flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <span className="text-2xl">{g.imageUrl.startsWith('http') ? '🎁' : g.imageUrl}</span>
                    <div>
                      <h4 className="text-xs font-bold text-white truncate max-w-[120px]">{g.name}</h4>
                      <div className="flex items-center gap-2 text-[10px] text-slate-400">
                        <span>{g.priceInDiamonds} 💎</span>
                        <span className="text-amber-400 font-black">+{g.eventPoints} pts</span>
                      </div>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleRemoveGiftFromEvent(g.giftId)}
                    className="p-1.5 text-rose-400 hover:bg-rose-500/20 rounded-lg transition-all"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Section 3: Rewards Configuration */}
          <div className="bg-slate-900/60 border border-white/[0.06] p-6 rounded-3xl space-y-4">
            <h2 className="text-base font-black uppercase tracking-wider text-amber-400 flex items-center gap-2">
              <Trophy size={18} /> Step 3: Configure Event Rewards by Rank
            </h2>
            <p className="text-xs text-slate-400">
              Rewards distributed to the top participants based on final Event Points standings.
            </p>

            {/* Add Reward Tier Bar */}
            <div className="bg-slate-800/60 p-4 rounded-2xl border border-white/[0.06] grid grid-cols-1 sm:grid-cols-6 gap-3 items-end">
              <div>
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Rank From</label>
                <input
                  type="number"
                  value={rewardTierForm.rankFrom}
                  onChange={e => setRewardTierForm({ ...rewardTierForm, rankFrom: e.target.value })}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Rank To</label>
                <input
                  type="number"
                  value={rewardTierForm.rankTo}
                  onChange={e => setRewardTierForm({ ...rewardTierForm, rankTo: e.target.value })}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Tier Title</label>
                <input
                  type="text"
                  value={rewardTierForm.title}
                  onChange={e => setRewardTierForm({ ...rewardTierForm, title: e.target.value })}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-400 mb-1">Diamonds</label>
                <input
                  type="number"
                  value={rewardTierForm.diamonds}
                  onChange={e => setRewardTierForm({ ...rewardTierForm, diamonds: e.target.value })}
                  className="w-full bg-slate-900 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-amber-400"
                />
              </div>

              <button
                type="button"
                onClick={handleAddRewardTier}
                className="w-full py-2 bg-orange-400/20 border border-orange-400/30 hover:bg-orange-400/30 text-orange-300 font-bold text-xs rounded-xl flex items-center justify-center gap-1.5 transition-all"
              >
                <Plus size={14} /> Add Tier
              </button>
            </div>

            {/* Reward Tiers List */}
            <div className="space-y-2 pt-2">
              {eventForm.rewards.map((r, idx) => (
                <div key={idx} className="bg-slate-800/80 border border-white/10 p-3 rounded-2xl flex items-center justify-between text-xs">
                  <div className="flex items-center gap-3">
                    <span className="px-2.5 py-1 rounded-xl bg-amber-400/10 text-amber-400 font-black">
                      Rank {r.rankFrom} {r.rankFrom !== r.rankTo ? `- ${r.rankTo}` : ''}
                    </span>
                    <span className="font-bold text-white">{r.title}</span>
                    <span className="text-amber-300 font-black">{Number(r.diamonds).toLocaleString()} 💎</span>
                    {r.badgeTitle && <span className="text-slate-400">Badge: {r.badgeTitle}</span>}
                    {r.frameDays && <span className="text-slate-400">{r.frameDays}d Frame</span>}
                  </div>
                  <button
                    type="button"
                    onClick={() => handleRemoveRewardTier(idx)}
                    className="p-1.5 text-rose-400 hover:bg-rose-500/20 rounded-lg transition-all"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Form Actions */}
          <div className="flex items-center justify-end gap-3 pt-4">
            <button
              type="button"
              onClick={() => setActiveTab('events')}
              className="px-6 py-2.5 rounded-2xl font-bold text-xs uppercase tracking-wider bg-slate-800 text-slate-400 hover:text-white transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={actionLoading}
              className="flex items-center gap-2 px-8 py-2.5 rounded-2xl font-black text-xs uppercase tracking-wider bg-gradient-to-r from-amber-400 to-orange-500 text-black hover:opacity-90 shadow-lg shadow-amber-500/20 transition-all active:scale-95"
            >
              <Save size={16} /> Save & Deploy Event
            </button>
          </div>
        </form>
      )}

      {/* TAB 3: LIVE LEADERBOARD */}
      {activeTab === 'leaderboard' && (
        <div className="space-y-4">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 bg-slate-900/60 p-4 rounded-2xl border border-white/[0.06]">
            <div className="flex items-center gap-2">
              <Trophy size={20} className="text-amber-400" />
              <span className="font-bold text-sm text-white">Select Event:</span>
              <select
                value={selectedLeaderboardEventId}
                onChange={e => setSelectedLeaderboardEventId(e.target.value)}
                className="bg-slate-800 border border-white/10 rounded-xl px-3 py-1.5 text-xs font-semibold text-white focus:outline-none"
              >
                {events.map(ev => (
                  <option key={ev.id} value={ev.id}>{ev.title}</option>
                ))}
              </select>
            </div>

            <div className="text-xs text-slate-400">
              Total Participants: <strong className="text-white">{leaderboardData.length}</strong>
            </div>
          </div>

          {leaderboardLoading ? (
            <div className="p-8 text-center text-slate-500 font-bold">Loading live rankings...</div>
          ) : leaderboardData.length === 0 ? (
            <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-white/[0.06]">
              <Trophy size={40} className="mx-auto text-slate-600 mb-2" />
              <p className="text-xs text-slate-400">No participants have sent event gifts for this event yet.</p>
            </div>
          ) : (
            <div className="bg-slate-900/60 border border-white/[0.06] rounded-3xl overflow-hidden">
              <div className="p-4 border-b border-white/[0.06] grid grid-cols-12 text-[11px] font-black uppercase tracking-wider text-slate-400">
                <span className="col-span-1 text-center">Rank</span>
                <span className="col-span-5">User</span>
                <span className="col-span-3 text-right">Event Points</span>
                <span className="col-span-3 text-right">Gifts Sent</span>
              </div>

              <div className="divide-y divide-white/[0.04]">
                {leaderboardData.map((p, idx) => {
                  const rank = idx + 1;
                  return (
                    <div key={p.id || p.uid} className="p-3.5 grid grid-cols-12 items-center text-xs hover:bg-white/[0.02]">
                      <div className="col-span-1 text-center">
                        {rank === 1 ? (
                          <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-amber-400 text-black font-black text-xs">1</span>
                        ) : rank === 2 ? (
                          <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-slate-300 text-black font-black text-xs">2</span>
                        ) : rank === 3 ? (
                          <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-amber-700 text-white font-black text-xs">3</span>
                        ) : (
                          <span className="font-bold text-slate-400">{rank}</span>
                        )}
                      </div>

                      <div className="col-span-5 flex items-center gap-3">
                        <img 
                          src={p.profilePhotoUrl || "https://picsum.photos/100"} 
                          alt={p.displayName} 
                          className="w-8 h-8 rounded-full object-cover border border-white/10"
                        />
                        <div>
                          <div className="font-bold text-white truncate max-w-[140px]">{p.displayName || 'User'}</div>
                          <div className="text-[10px] text-slate-500">ID: {p.uid ? p.uid.substring(0, 8) : 'unknown'}...</div>
                        </div>
                      </div>

                      <div className="col-span-3 text-right font-black text-amber-400">
                        {(p.points || 0).toLocaleString()} pts
                      </div>

                      <div className="col-span-3 text-right font-bold text-slate-300">
                        {(p.giftCount || 0).toLocaleString()}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

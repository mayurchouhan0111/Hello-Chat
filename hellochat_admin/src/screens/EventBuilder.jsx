import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { 
  collection, query, where, orderBy, onSnapshot, 
  addDoc, updateDoc, doc, deleteDoc, Timestamp, writeBatch 
} from 'firebase/firestore';
import { 
  Calendar, Coins, Image, Layers, Plus, Trash2, Edit2, 
  Save, X, Check, AlertCircle, Palette, Type, Layout, 
  Link, Flag, Star, Upload, Eye, FileText, Globe, 
  ChevronDown, ChevronUp, Settings, Zap, Monitor
} from 'lucide-react';

const EVENT_TYPES = [
  { id: 'recharge_bonus', label: 'Recharge Bonus', icon: Coins, desc: 'Bonus on every recharge' },
  { id: 'recharge_milestone', label: 'Recharge Milestone', icon: Flag, desc: 'Rewards at milestones' },
  { id: 'generic', label: 'Generic Event', icon: Star, desc: 'Custom dynamic event' },
];

const BG_TYPES = [
  { id: 'color', label: 'Solid Color' },
  { id: 'gradient', label: 'Gradient' },
  { id: 'image', label: 'Image' },
];

const BUTTON_ACTIONS = [
  { id: 'recharge', label: 'Go to Recharge' },
  { id: 'route', label: 'Internal Route' },
  { id: 'url', label: 'External URL' },
];

const BANNER_ACTIONS = [
  { id: 'none', label: 'No Action' },
  { id: 'recharge', label: 'Recharge Page' },
  { id: 'event', label: 'Dynamic Event' },
  { id: 'room', label: 'Join Room' },
  { id: 'profile', label: 'User Profile' },
  { id: 'external_url', label: 'External URL' },
  { id: 'recharge_event', label: 'Legacy Event Detail' },
];

export const EventBuilder = () => {
  const [events, setEvents] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [message, setMessage] = useState(null);
  const [activeTab, setActiveTab] = useState('basic');
  const [expandedEvent, setExpandedEvent] = useState(null);

  const [form, setForm] = useState({
    title: '', description: '', type: 'recharge_bonus',
    htmlContent: '', bannerImage: '', backgroundImage: '',
    backgroundType: 'color', backgroundColor: '#1a0a2e',
    backgroundGradient: ['#0d1b2a', '#1b2838', '#2d3a4a'],
    themeColor: '#FFD700', icon: 'stars',
    buttonText: 'Join Now', buttonColor: '#D32F2F',
    buttonAction: 'recharge', navigationTarget: '/wallet',
    priority: 1, isActive: true, includeBonus: false,
    startDate: '', endDate: '',
  });

  // Milestones for milestone events
  const [milestones, setMilestones] = useState([]);
  const [showMsForm, setShowMsForm] = useState(false);
  const [editingMsId, setEditingMsId] = useState(null);
  const [msForm, setMsForm] = useState({
    label: '', targetAmount: 10, rewardAmount: 1000000,
    rewardType: 'coins', sortOrder: 1, isActive: true
  });

  // Packages for bonus events
  const [packages, setPackages] = useState([]);
  const [showPkgForm, setShowPkgForm] = useState(false);
  const [editingPkgId, setEditingPkgId] = useState(null);
  const [pkgForm, setPkgForm] = useState({
    rechargeAmount: 1, baseCoins: 1000000, bonusCoins: 2000000,
    sortOrder: 1, isActive: true
  });

  useEffect(() => {
    const q = query(collection(db, 'dynamic_events'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setEvents(snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id, ...data,
          startDate: data.startDate?.toDate().toISOString().substring(0, 16) || '',
          endDate: data.endDate?.toDate().toISOString().substring(0, 16) || '',
        };
      }));
    });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!editingId) return;
    const msQ = query(collection(db, 'recharge_milestones'), where('eventId', '==', editingId), orderBy('sortOrder', 'asc'));
    const unsubMs = onSnapshot(msQ, (snap) => setMilestones(snap.docs.map(d => ({ id: d.id, ...d.data() }))));
    const pkgQ = query(collection(db, 'recharge_bonus_packages'), where('eventId', '==', editingId), orderBy('sortOrder', 'asc'));
    const unsubPkg = onSnapshot(pkgQ, (snap) => setPackages(snap.docs.map(d => ({ id: d.id, ...d.data() }))));
    return () => { unsubMs(); unsubPkg(); };
  }, [editingId]);

  const showMsg = (text, type = 'success') => {
    setMessage({ text, type });
    setTimeout(() => setMessage(null), 5000);
  };

  const resetForm = () => {
    setForm({
      title: '', description: '', type: 'recharge_bonus',
      htmlContent: '', bannerImage: '', backgroundImage: '',
      backgroundType: 'color', backgroundColor: '#1a0a2e',
      backgroundGradient: ['#0d1b2a', '#1b2838', '#2d3a4a'],
      themeColor: '#FFD700', icon: 'stars',
      buttonText: 'Join Now', buttonColor: '#D32F2F',
      buttonAction: 'recharge', navigationTarget: '/wallet',
      priority: 1, isActive: true, includeBonus: false,
      startDate: '', endDate: '',
    });
    setEditingId(null);
    setShowForm(false);
    setActiveTab('basic');
    setMilestones([]);
    setPackages([]);
  };

  const handleEdit = (ev) => {
    setForm({
      title: ev.title || '', description: ev.description || '',
      type: ev.type || 'recharge_bonus',
      htmlContent: ev.htmlContent || '', bannerImage: ev.bannerImage || '',
      backgroundImage: ev.backgroundImage || '',
      backgroundType: ev.backgroundType || 'color',
      backgroundColor: ev.backgroundColor || '#1a0a2e',
      backgroundGradient: ev.backgroundGradient || ['#0d1b2a', '#1b2838'],
      themeColor: ev.themeColor || '#FFD700', icon: ev.icon || 'stars',
      buttonText: ev.buttonText || 'Join Now', buttonColor: ev.buttonColor || '#D32F2F',
      buttonAction: ev.buttonAction || 'recharge', navigationTarget: ev.navigationTarget || '/wallet',
      priority: ev.priority || 1, isActive: ev.isActive !== false,
      includeBonus: ev.includeBonus || false,
      startDate: ev.startDate || '', endDate: ev.endDate || '',
    });
    setEditingId(ev.id);
    setShowForm(true);
    setExpandedEvent(null);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!form.title.trim()) { showMsg('Event title required.', 'error'); return; }
    if (!form.startDate || !form.endDate) { showMsg('Start and End dates required.', 'error'); return; }

    const startTs = Timestamp.fromDate(new Date(form.startDate));
    const endTs = Timestamp.fromDate(new Date(form.endDate));
    if (endTs.toMillis() <= startTs.toMillis()) { showMsg('End must be after Start.', 'error'); return; }

    try {
      const data = {
        title: form.title, description: form.description, type: form.type,
        htmlContent: form.htmlContent, bannerImage: form.bannerImage,
        backgroundImage: form.backgroundImage, backgroundType: form.backgroundType,
        backgroundColor: form.backgroundColor, backgroundGradient: form.backgroundGradient,
        themeColor: form.themeColor, icon: form.icon,
        buttonText: form.buttonText, buttonColor: form.buttonColor,
        buttonAction: form.buttonAction, navigationTarget: form.navigationTarget,
        priority: Number(form.priority), isActive: form.isActive,
        includeBonus: form.includeBonus, startDate: startTs, endDate: endTs,
      };

      if (editingId) {
        await updateDoc(doc(db, 'dynamic_events', editingId), { ...data, updatedAt: Timestamp.now() });
        showMsg('Event updated successfully.');
      } else {
        const ref = await addDoc(collection(db, 'dynamic_events'), { ...data, createdAt: Timestamp.now() });
        setEditingId(ref.id);
        showMsg('Event created! Now configure milestones/packages.');
      }
    } catch (err) {
      showMsg('Error: ' + err.message, 'error');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this event permanently?')) return;
    try {
      await deleteDoc(doc(db, 'dynamic_events', id));
      showMsg('Event deleted.');
    } catch (err) {
      showMsg('Error: ' + err.message, 'error');
    }
  };

  const getStatus = (ev) => {
    const now = new Date();
    const start = new Date(ev.startDate);
    const end = new Date(ev.endDate);
    if (!ev.isActive) return { label: 'DISABLED', color: 'bg-rose-500/10 text-rose-400 border-rose-500/20' };
    if (now > end) return { label: 'EXPIRED', color: 'bg-slate-500/10 text-slate-400 border-white/10' };
    if (now < start) return { label: 'UPCOMING', color: 'bg-amber-500/10 text-amber-400 border-amber-500/20' };
    return { label: 'LIVE', color: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' };
  };

  // ── Milestone CRUD ──
  const handleSaveMs = async (e) => {
    e.preventDefault();
    if (!editingId) { showMsg('Save the event first.', 'error'); return; }
    const data = {
      eventId: editingId, label: msForm.label,
      targetAmount: Number(msForm.targetAmount), rewardAmount: Number(msForm.rewardAmount),
      rewardType: msForm.rewardType, sortOrder: Number(msForm.sortOrder), isActive: msForm.isActive,
    };
    try {
      if (editingMsId) {
        await updateDoc(doc(db, 'recharge_milestones', editingMsId), data);
        showMsg('Milestone updated.');
      } else {
        await addDoc(collection(db, 'recharge_milestones'), data);
        showMsg('Milestone created.');
      }
      setShowMsForm(false);
      setEditingMsId(null);
    } catch (err) { showMsg('Error: ' + err.message, 'error'); }
  };

  const handleDeleteMs = async (id) => {
    if (!window.confirm('Delete this milestone?')) return;
    await deleteDoc(doc(db, 'recharge_milestones', id));
    showMsg('Milestone deleted.');
  };

  // ── Package CRUD ──
  const handleSavePkg = async (e) => {
    e.preventDefault();
    if (!editingId) { showMsg('Save the event first.', 'error'); return; }
    const base = Number(pkgForm.baseCoins);
    const bonus = Number(pkgForm.bonusCoins);
    const data = {
      eventId: editingId, rechargeAmount: Number(pkgForm.rechargeAmount),
      baseCoins: base, bonusCoins: bonus, totalCoins: base + bonus,
      sortOrder: Number(pkgForm.sortOrder), isActive: pkgForm.isActive,
    };
    try {
      if (editingPkgId) {
        await updateDoc(doc(db, 'recharge_bonus_packages', editingPkgId), data);
        showMsg('Package updated.');
      } else {
        await addDoc(collection(db, 'recharge_bonus_packages'), data);
        showMsg('Package created.');
      }
      setShowPkgForm(false);
      setEditingPkgId(null);
    } catch (err) { showMsg('Error: ' + err.message, 'error'); }
  };

  const handleDeletePkg = async (id) => {
    if (!window.confirm('Delete this package?')) return;
    await deleteDoc(doc(db, 'recharge_bonus_packages', id));
    showMsg('Package deleted.');
  };

  const seedEvent = async () => {
    try {
      const now = Timestamp.now();
      const end = Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
      const ref = await addDoc(collection(db, 'dynamic_events'), {
        title: 'Summer Ice Event', description: 'Cool rewards await! Recharge diamonds and earn bonus coins & milestone rewards.',
        type: 'recharge_bonus',
        htmlContent: `<!-- Hero Banner -->
<section style="width:100%;min-height:380px;position:relative;background:linear-gradient(180deg,rgba(0,0,0,0.3) 0%,rgba(18,12,6,1) 100%),url('https://images.unsplash.com/photo-1614732414444-096e5f1122d5?w=800&q=80') center bottom/cover;display:flex;flex-direction:column;align-items:center;padding-top:40px;text-align:center">
  <div style="position:absolute;top:40%;left:50%;transform:translate(-50%,-50%);width:250px;height:250px;background:radial-gradient(circle,rgba(255,215,0,0.2) 0%,transparent 70%);pointer-events:none"></div>
  <h1 style="font-family:'Cinzel',serif;font-size:34px;font-weight:900;text-transform:uppercase;background:linear-gradient(to bottom,#fff 0%,#ffe680 20%,#f5af19 60%,#b36b00 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;text-shadow:0 3px 2px rgba(0,0,0,0.9),0 0 10px rgba(184,134,11,0.6);margin:15px 0 25px;line-height:1.1;letter-spacing:0.5px">
    Recharge <span style="display:block;font-size:38px">Bonus Event</span>
  </h1>
  <div style="position:relative;display:inline-flex;align-items:center;justify-content:center;gap:12px;background:linear-gradient(180deg,#ff4d4d 0%,#b30000 60%,#660000 100%);border:2.5px solid #d4af37;border-radius:50px;padding:8px 30px;font-family:'Cinzel',serif;font-weight:800;font-size:22px;box-shadow:0 6px 12px rgba(0,0,0,0.6),inset 0 2px 4px rgba(255,255,255,0.4),0 0 15px rgba(214,28,28,0.4);margin-bottom:25px;min-width:280px;color:#fff">
    <span style="text-shadow:0 2px 4px rgba(0,0,0,0.8);font-size:24px">1 $</span>
    <span style="color:#ffd700">=</span>
    <span style="background:linear-gradient(to bottom,#fff,#ffd700);-webkit-background-clip:text;-webkit-text-fill-color:transparent;display:inline-flex;align-items:center;gap:4px">3m coins <span style="color:#ffd700;font-size:22px;animation:arrowPulse 1.2s infinite alternate;display:inline-block">▲</span></span>
  </div>
  <a href="hellochat://recharge" style="display:inline-flex;align-items:center;justify-content:center;background:linear-gradient(to bottom,#e60000 0%,#990000 100%);color:#fff;border:3px solid #d4af37;padding:12px 40px;font-size:19px;font-weight:700;border-radius:12px;box-shadow:0 8px 20px rgba(0,0,0,0.7),0 0 10px rgba(230,0,0,0.3);position:relative;overflow:hidden;margin-top:15px;text-decoration:none;text-transform:capitalize">
    <span style="position:absolute;top:-50%;left:-60%;width:30%;height:200%;background:linear-gradient(to right,transparent 0%,rgba(255,255,255,0.4) 50%,transparent 100%);transform:rotate(25deg);animation:btnShine 4s infinite ease-in-out"></span>
    Go to recharge
  </a>
</section>

<!-- Content Area -->
<main style="padding:0 15px 30px;margin-top:-50px;position:relative;z-index:3">

  <!-- Card 1: Event Details -->
  <article style="background:#291a0c;border-left:2px solid #e1b12c;border-right:2px solid #e1b12c;margin-bottom:25px;position:relative;box-shadow:0 10px 30px rgba(0,0,0,0.7)">
    <div style="display:flex;justify-content:center;position:relative;height:36px">
      <svg width="100%" height="36" viewBox="0 0 400 36" preserveAspectRatio="none" style="position:absolute;top:-18px;left:0">
        <path d="M0,18 C100,-5 300,-5 400,18" fill="none" stroke="#e1b12c" stroke-width="3"/>
        <path d="M180,18 L220,18 L200,32 Z" fill="#d61c1c" stroke="#e1b12c" stroke-width="1.5"/>
      </svg>
      <div style="width:16px;height:16px;background:radial-gradient(circle,#ff003c 30%,#4a0000 100%);border:1.5px solid #ffd700;transform:rotate(45deg);box-shadow:0 0 10px #ff003c,0 2px 4px rgba(0,0,0,0.8);position:absolute;top:-2px;z-index:4"></div>
    </div>
    <div style="padding:25px 20px 20px;font-size:14px;line-height:1.6;color:#f5eccd;text-shadow:0 1px 2px rgba(0,0,0,0.8)">
      <h2 style="font-family:'Cinzel',serif;font-size:16px;font-weight:700;color:#fff3a8;margin-bottom:12px;display:flex;align-items:center;gap:8px">
        <span style="color:#ffd700">✦</span> Event Details
      </h2>
      <p>The Recharge Rebate Event is now upgraded! No chest unlocking required &mdash; enjoy massive instant returns. Get 3 million coins for every $1 you recharge.</p>
      <p style="margin-top:8px">Recharge now and claim big rewards instantly! 🎊</p>
    </div>
    <svg width="100%" height="18" viewBox="0 0 400 18" preserveAspectRatio="none" style="position:absolute;bottom:-10px;left:0">
      <path d="M0,0 C100,12 300,12 400,0" fill="none" stroke="#e1b12c" stroke-width="3"/>
    </svg>
  </article>

  <!-- Card 2: Rewards Table -->
  <article style="background:#291a0c;border-left:2px solid #e1b12c;border-right:2px solid #e1b12c;margin-bottom:25px;position:relative;box-shadow:0 10px 30px rgba(0,0,0,0.7)">
    <div style="display:flex;justify-content:center;position:relative;height:36px">
      <svg width="100%" height="36" viewBox="0 0 400 36" preserveAspectRatio="none" style="position:absolute;top:-18px;left:0">
        <path d="M0,18 C100,-5 300,-5 400,18" fill="none" stroke="#e1b12c" stroke-width="3"/>
        <path d="M180,18 L220,18 L200,32 Z" fill="#d61c1c" stroke="#e1b12c" stroke-width="1.5"/>
      </svg>
      <div style="width:16px;height:16px;background:radial-gradient(circle,#ff003c 30%,#4a0000 100%);border:1.5px solid #ffd700;transform:rotate(45deg);box-shadow:0 0 10px #ff003c,0 2px 4px rgba(0,0,0,0.8);position:absolute;top:-2px;z-index:4"></div>
    </div>
    <div style="padding:25px 20px 20px;font-size:14px;line-height:1.6;color:#f5eccd;text-shadow:0 1px 2px rgba(0,0,0,0.8)">
      <p>For every $1 recharged, you will ultimately receive 3 million coins, including 1m basic coins and 2m event bonus coins. The same applies to all other recharge amounts; you can refer to the table below for details.</p>
      <p style="margin-top:8px;font-style:italic;color:#d4af37">Note: Details of the rewards for each recharge can be viewed in the coins Recharge Record.</p>
      <div style="width:100%;margin-top:15px;border-radius:8px;overflow:hidden;border:1px solid #4a331a;box-shadow:0 4px 10px rgba(0,0,0,0.4)">
        <table style="width:100%;border-collapse:collapse;text-align:center;font-size:12px;background:rgba(18,12,6,0.6)">
          <thead>
            <tr>
              <th style="background:linear-gradient(to bottom,#3d2714,#291a0c);font-family:'Cinzel',serif;font-weight:700;color:#fff3a8;padding:10px 4px;font-size:11px;border-bottom:2px solid #5c4024;border-right:1px solid #4a331a">Recharge/$</th>
              <th style="background:linear-gradient(to bottom,#3d2714,#291a0c);font-family:'Cinzel',serif;font-weight:700;color:#fff3a8;padding:10px 4px;font-size:11px;border-bottom:2px solid #5c4024;border-right:1px solid #4a331a">Basic Coins</th>
              <th style="background:linear-gradient(to bottom,#3d2714,#291a0c);font-family:'Cinzel',serif;font-weight:700;color:#fff3a8;padding:10px 4px;font-size:11px;border-bottom:2px solid #5c4024;border-right:1px solid #4a331a">Bonus Coins</th>
              <th style="background:linear-gradient(to bottom,#3d2714,#291a0c);font-family:'Cinzel',serif;font-weight:700;color:#fff3a8;padding:10px 4px;font-size:11px;border-bottom:2px solid #5c4024">Total</th>
            </tr>
          </thead>
          <tbody>
            <tr><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:800;color:#ffd700;font-size:13px">1</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#e5cc80">1,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#ff5252">2,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;font-weight:700;color:#ffd700">3,000,000</td></tr>
            <tr><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:800;color:#ffd700;font-size:13px">5</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#e5cc80">5,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#ff5252">10,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;font-weight:700;color:#ffd700">15,000,000</td></tr>
            <tr><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:800;color:#ffd700;font-size:13px">10</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#e5cc80">10,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#ff5252">20,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;font-weight:700;color:#ffd700">30,000,000</td></tr>
            <tr><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:800;color:#ffd700;font-size:13px">30</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#e5cc80">30,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;border-right:1px solid #4a331a;font-weight:600;color:#ff5252">60,000,000</td><td style="padding:10px 4px;border-bottom:1px solid #4a331a;font-weight:700;color:#ffd700">90,000,000</td></tr>
            <tr><td style="padding:10px 4px;border-bottom:none;border-right:1px solid #4a331a;font-weight:800;color:#ffd700;font-size:13px">100</td><td style="padding:10px 4px;border-bottom:none;border-right:1px solid #4a331a;font-weight:600;color:#e5cc80">100,000,000</td><td style="padding:10px 4px;border-bottom:none;border-right:1px solid #4a331a;font-weight:600;color:#ff5252">200,000,000</td><td style="padding:10px 4px;border-bottom:none;font-weight:700;color:#ffd700">300,000,000</td></tr>
          </tbody>
        </table>
      </div>
    </div>
    <svg width="100%" height="18" viewBox="0 0 400 18" preserveAspectRatio="none" style="position:absolute;bottom:-10px;left:0">
      <path d="M0,0 C100,12 300,12 400,0" fill="none" stroke="#e1b12c" stroke-width="3"/>
    </svg>
  </article>

  <footer style="font-size:11px;color:#a38d75;text-align:center;line-height:1.5;margin-top:10px;padding:0 10px">
    Note: Hayi reserves the right to final interpretation of this event. Please consult customer service for specific rules.
  </footer>
</main>

<style>
@keyframes arrowPulse { 0% { transform: translateY(2px); } 100% { transform: translateY(-3px); } }
@keyframes btnShine { 0% { left: -60%; } 30% { left: 140%; } 100% { left: 140%; } }
</style>`,
        bannerImage: '', backgroundImage: '', backgroundType: 'gradient', backgroundColor: '#0a1628',
        backgroundGradient: ["#0d1b2a", "#1a3a5c", "#0d1b2a"],
        themeColor: '#00BFFF', icon: 'stars', buttonText: 'Recharge Now', buttonColor: '#00BFFF',
        buttonAction: 'recharge', navigationTarget: '/wallet',
        priority: 1, isActive: true, includeBonus: true,
        startDate: now, endDate: end, createdAt: now,
      });
      await addDoc(collection(db, 'recharge_bonus_packages'), { eventId: ref.id, rechargeAmount: 1, baseCoins: 100, bonusCoins: 100, totalCoins: 200, sortOrder: 1, isActive: true });
      await addDoc(collection(db, 'recharge_bonus_packages'), { eventId: ref.id, rechargeAmount: 5, baseCoins: 600, bonusCoins: 700, totalCoins: 1300, sortOrder: 2, isActive: true });
      await addDoc(collection(db, 'recharge_bonus_packages'), { eventId: ref.id, rechargeAmount: 10, baseCoins: 1300, bonusCoins: 1500, totalCoins: 2800, sortOrder: 3, isActive: true });
      await addDoc(collection(db, 'app_banners'), {
        imageUrl: 'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?w=800&q=80',
        title: '❄️ Summer Ice Event', subtitle: 'Get 200% bonus on recharge!',
        buttonText: 'Join Now', actionType: 'event', actionValue: ref.id,
        isActive: true, priority: 1, createdAt: now, createdBy: 'seed',
      });
      showMsg('Summer Ice Event created with 3 bonus packages!');
    } catch (err) { showMsg('Error: ' + err.message, 'error'); }
  };

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-violet-500/20 rounded-2xl border border-violet-500/30">
              <Zap className="text-violet-400" size={28} />
            </div>
            Event Builder
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Create dynamic events without app updates
          </p>
        </div>
        {!showForm && (
          <div className="flex gap-3">
            <button onClick={seedEvent}
              className="flex items-center gap-2 px-6 py-3 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-black uppercase tracking-wider transition-all">
              <Zap size={16} /> Seed Event
            </button>
            <button onClick={() => { resetForm(); setShowForm(true); }}
              className="flex items-center gap-2 px-6 py-3 bg-violet-600 hover:bg-violet-500 text-white rounded-xl text-xs font-black uppercase tracking-wider transition-all">
              <Plus size={16} /> New Event
            </button>
          </div>
        )}
      </div>

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

      {/* ── CREATE/EDIT FORM ── */}
      {showForm && (
        <form onSubmit={handleSave} className="bg-[#111115] border border-white/[0.04] p-8 rounded-3xl space-y-6">
          <div className="flex items-center justify-between border-b border-white/[0.04] pb-4">
            <h3 className="text-lg font-bold flex items-center gap-3">
              {editingId ? 'Edit Event' : 'Create New Event'}
              {editingId && (
                <span className="text-[10px] px-3 py-1 rounded-full bg-violet-500/10 text-violet-400 border border-violet-500/20 uppercase tracking-wider">
                  {form.type.replace('_', ' ')}
                </span>
              )}
            </h3>
            <div className="flex gap-2">
              {/* Tab Navigation */}
              {editingId && ['basic', 'milestones', 'packages'].filter(t => {
                if (t === 'milestones' && form.type !== 'recharge_milestone') return false;
                if (t === 'packages' && form.type !== 'recharge_bonus') return false;
                return true;
              }).map(tab => (
                <button key={tab} type="button" onClick={() => setActiveTab(tab)}
                  className={`px-4 py-2 rounded-lg text-[10px] font-black uppercase tracking-wider ${
                    activeTab === tab ? 'bg-violet-600 text-white' : 'bg-white/5 text-slate-400 hover:text-white'
                  }`}>
                  {tab}
                </button>
              ))}
              <button type="button" onClick={resetForm} className="p-2 hover:bg-white/5 rounded-lg text-slate-400">
                <X size={16} />
              </button>
            </div>
          </div>

          {/* Tab: Basic Settings */}
          {(!editingId || activeTab === 'basic') && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Event Title *</label>
                  <input type="text" placeholder="e.g. Ice Event, Dragon Event"
                    className="glass-input w-full h-14"
                    value={form.title} onChange={e => setForm({...form, title: e.target.value})} />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Event Type</label>
                  <div className="flex gap-2">
                    {EVENT_TYPES.map(et => {
                      const Icon = et.icon;
                      return (
                        <button key={et.id} type="button" onClick={() => setForm({...form, type: et.id})}
                          className={`flex-1 p-3 rounded-xl border text-[10px] font-black uppercase tracking-wider transition-all ${
                            form.type === et.id
                              ? 'bg-violet-600/20 border-violet-500/50 text-violet-300'
                              : 'bg-white/5 border-white/10 text-slate-400 hover:text-white'
                          }`}>
                          <Icon size={16} className="mx-auto mb-1" />
                          {et.label}
                        </button>
                      );
                    })}
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Banner Image URL</label>
                  <input type="text" placeholder="https://..."
                    className="glass-input w-full h-14"
                    value={form.bannerImage} onChange={e => setForm({...form, bannerImage: e.target.value})} />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Description</label>
                <textarea placeholder="Event description..."
                  className="glass-input w-full h-24 py-4 resize-none"
                  value={form.description} onChange={e => setForm({...form, description: e.target.value})} />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Start Date</label>
                  <input type="datetime-local" className="glass-input w-full h-14 text-white"
                    value={form.startDate} onChange={e => setForm({...form, startDate: e.target.value})} />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">End Date</label>
                  <input type="datetime-local" className="glass-input w-full h-14 text-white"
                    value={form.endDate} onChange={e => setForm({...form, endDate: e.target.value})} />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Priority</label>
                  <input type="number" min="1" className="glass-input w-full h-14"
                    value={form.priority} onChange={e => setForm({...form, priority: e.target.value})} />
                </div>
                <div className="flex items-end pb-3">
                  <label className="flex items-center gap-4 cursor-pointer p-4 bg-white/5 border border-white/5 rounded-2xl w-full h-14 hover:bg-white/10 transition-all">
                    <input type="checkbox" className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-violet-600"
                      checked={form.isActive} onChange={e => setForm({...form, isActive: e.target.checked})} />
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Active</span>
                  </label>
                </div>
              </div>

              {/* Background Config */}
              <div className="border-t border-white/[0.04] pt-6">
                <h4 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-4">Background Settings</h4>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Background Type</label>
                    <div className="flex gap-2">
                      {BG_TYPES.map(bt => (
                        <button key={bt.id} type="button" onClick={() => setForm({...form, backgroundType: bt.id})}
                          className={`flex-1 p-2 rounded-lg text-[9px] font-black uppercase tracking-wider border transition-all ${
                            form.backgroundType === bt.id
                              ? 'bg-violet-600/20 border-violet-500/50 text-violet-300'
                              : 'bg-white/5 border-white/10 text-slate-400'
                          }`}>
                          {bt.label}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Color (hex)</label>
                    <div className="flex gap-2">
                      <input type="color" className="w-14 h-14 rounded-xl cursor-pointer"
                        value={form.backgroundColor} onChange={e => setForm({...form, backgroundColor: e.target.value})} />
                      <input type="text" className="glass-input flex-1 h-14"
                        value={form.backgroundColor} onChange={e => setForm({...form, backgroundColor: e.target.value})} />
                    </div>
                  </div>
                  {form.backgroundType === 'gradient' && (
                    <div className="space-y-2 col-span-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Gradient Colors</label>
                      <div className="flex gap-2">
                        {form.backgroundGradient.map((c, i) => (
                          <div key={i} className="flex items-center gap-2 bg-white/5 rounded-xl p-2">
                            <input type="color" className="w-10 h-10 rounded-lg cursor-pointer"
                              value={c} onChange={e => {
                                const g = [...form.backgroundGradient];
                                g[i] = e.target.value;
                                setForm({...form, backgroundGradient: g});
                              }} />
                            <input type="text" className="glass-input w-24 h-10 text-xs"
                              value={c} onChange={e => {
                                const g = [...form.backgroundGradient];
                                g[i] = e.target.value;
                                setForm({...form, backgroundGradient: g});
                              }} />
                          </div>
                        ))}
                        <button type="button" onClick={() => setForm({...form, backgroundGradient: [...form.backgroundGradient, '#000000']})}
                          className="p-2 bg-white/5 rounded-xl hover:bg-white/10">
                          <Plus size={16} />
                        </button>
                      </div>
                    </div>
                  )}
                  {form.backgroundType === 'image' && (
                    <div className="space-y-2 col-span-2">
                      <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Background Image URL</label>
                      <input type="text" placeholder="https://..."
                        className="glass-input w-full h-14"
                        value={form.backgroundImage} onChange={e => setForm({...form, backgroundImage: e.target.value})} />
                    </div>
                  )}
                </div>
              </div>

              {/* Theme & Button Config */}
              <div className="border-t border-white/[0.04] pt-6">
                <h4 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-4">Theme & Button Settings</h4>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Theme Color</label>
                    <div className="flex gap-2">
                      <input type="color" className="w-14 h-14 rounded-xl cursor-pointer"
                        value={form.themeColor} onChange={e => setForm({...form, themeColor: e.target.value})} />
                      <input type="text" className="glass-input flex-1 h-14"
                        value={form.themeColor} onChange={e => setForm({...form, themeColor: e.target.value})} />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Button Color</label>
                    <div className="flex gap-2">
                      <input type="color" className="w-14 h-14 rounded-xl cursor-pointer"
                        value={form.buttonColor} onChange={e => setForm({...form, buttonColor: e.target.value})} />
                      <input type="text" className="glass-input flex-1 h-14"
                        value={form.buttonColor} onChange={e => setForm({...form, buttonColor: e.target.value})} />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Button Text</label>
                    <input type="text" className="glass-input w-full h-14"
                      value={form.buttonText} onChange={e => setForm({...form, buttonText: e.target.value})} />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Button Action</label>
                    <select className="glass-input w-full h-14"
                      value={form.buttonAction} onChange={e => setForm({...form, buttonAction: e.target.value})}>
                      {BUTTON_ACTIONS.map(ba => <option key={ba.id} value={ba.id}>{ba.label}</option>)}
                    </select>
                  </div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Navigation Target</label>
                    <input type="text" placeholder="/wallet, /event/:id, https://..."
                      className="glass-input w-full h-14"
                      value={form.navigationTarget} onChange={e => setForm({...form, navigationTarget: e.target.value})} />
                  </div>
                  {form.type === 'recharge_milestone' && (
                    <div className="flex items-end pb-3">
                      <label className="flex items-center gap-4 cursor-pointer p-4 bg-white/5 border border-white/5 rounded-2xl w-full h-14 hover:bg-white/10 transition-all">
                        <input type="checkbox" className="w-5 h-5 rounded-lg border-white/10 bg-transparent text-violet-600"
                          checked={form.includeBonus} onChange={e => setForm({...form, includeBonus: e.target.checked})} />
                        <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Include Bonus in Progress</span>
                      </label>
                    </div>
                  )}
                </div>
              </div>

              {/* HTML Content */}
              <div className="border-t border-white/[0.04] pt-6">
                <h4 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-4">HTML Content</h4>
                <p className="text-[9px] text-slate-500 mb-3">Supports: headings, paragraphs, images, GIFs, tables, buttons, links, lists</p>
                <textarea placeholder="<h1>Event Title</h1><p>Description here</p><img src='...' />"
                  className="glass-input w-full h-64 py-4 font-mono text-xs resize-none"
                  value={form.htmlContent} onChange={e => setForm({...form, htmlContent: e.target.value})} />
                {form.htmlContent && (
                  <div className="mt-4 border border-white/[0.04] rounded-2xl p-6 bg-white/5">
                    <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Preview</h4>
                    <div className="prose prose-invert max-w-none text-sm"
                      dangerouslySetInnerHTML={{ __html: form.htmlContent }} />
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Tab: Milestones */}
          {editingId && activeTab === 'milestones' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <p className="text-slate-400 text-xs">Define recharge milestones and rewards</p>
                {!showMsForm && (
                  <button type="button" onClick={() => { setShowMsForm(true); setEditingMsId(null); setMsForm({ label: '', targetAmount: 10, rewardAmount: 1000000, rewardType: 'coins', sortOrder: milestones.length + 1, isActive: true }); }}
                    className="flex items-center gap-2 px-4 py-2 bg-violet-600 hover:bg-violet-500 text-white rounded-lg text-[10px] font-black uppercase tracking-wider">
                    <Plus size={14} /> Add Milestone
                  </button>
                )}
              </div>

              {showMsForm && (
                <div className="bg-white/5 rounded-2xl p-6 border border-white/[0.04] space-y-4">
                  <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Label (e.g. 10M)</label>
                      <input type="text" className="glass-input w-full h-12"
                        value={msForm.label} onChange={e => setMsForm({...msForm, label: e.target.value})} />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Target</label>
                      <input type="number" min="1" className="glass-input w-full h-12"
                        value={msForm.targetAmount} onChange={e => setMsForm({...msForm, targetAmount: e.target.value})} />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Reward</label>
                      <input type="number" min="0" className="glass-input w-full h-12"
                        value={msForm.rewardAmount} onChange={e => setMsForm({...msForm, rewardAmount: e.target.value})} />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Order</label>
                      <input type="number" min="1" className="glass-input w-full h-12"
                        value={msForm.sortOrder} onChange={e => setMsForm({...msForm, sortOrder: e.target.value})} />
                    </div>
                    <div className="flex items-end pb-2">
                      <label className="flex items-center gap-2 cursor-pointer p-3 bg-white/5 rounded-xl w-full h-12">
                        <input type="checkbox" className="w-4 h-4"
                          checked={msForm.isActive} onChange={e => setMsForm({...msForm, isActive: e.target.checked})} />
                        <span className="text-[9px] font-black text-slate-400 uppercase">Active</span>
                      </label>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <button type="button" onClick={handleSaveMs}
                      className="px-6 h-10 bg-violet-600 text-white rounded-lg text-[10px] font-black uppercase tracking-wider">
                      <Save size={14} className="inline mr-1" /> {editingMsId ? 'Update' : 'Create'}
                    </button>
                    <button type="button" onClick={() => setShowMsForm(false)}
                      className="px-4 h-10 bg-white/5 text-slate-400 rounded-lg text-[10px] font-black uppercase tracking-wider">
                      Cancel
                    </button>
                  </div>
                </div>
              )}

              <div className="space-y-2">
                {milestones.length === 0 ? (
                  <p className="text-slate-500 text-xs text-center py-8">No milestones configured.</p>
                ) : (
                  milestones.map(ms => (
                    <div key={ms.id} className="flex items-center justify-between bg-white/5 rounded-xl p-4 border border-white/[0.04]">
                      <div className="flex items-center gap-4">
                        <Flag size={16} className="text-violet-400" />
                        <div>
                          <span className="text-sm font-bold text-white">{ms.label || ms.targetAmount}</span>
                          <span className="text-[10px] text-slate-500 ml-3">{ms.targetAmount} target</span>
                          <span className="text-[10px] text-emerald-400 ml-3">+{ms.rewardAmount}</span>
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <button type="button" onClick={() => {
                          setMsForm({ label: ms.label || '', targetAmount: ms.targetAmount, rewardAmount: ms.rewardAmount, rewardType: ms.rewardType || 'coins', sortOrder: ms.sortOrder, isActive: ms.isActive });
                          setEditingMsId(ms.id); setShowMsForm(true);
                        }} className="p-2 hover:bg-violet-600/20 text-violet-400 rounded-lg">
                          <Edit2 size={14} />
                        </button>
                        <button type="button" onClick={() => handleDeleteMs(ms.id)} className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg">
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}

          {/* Tab: Packages */}
          {editingId && activeTab === 'packages' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <p className="text-slate-400 text-xs">Define recharge bonus packages</p>
                {!showPkgForm && (
                  <button type="button" onClick={() => { setShowPkgForm(true); setEditingPkgId(null); setPkgForm({ rechargeAmount: 1, baseCoins: 1000000, bonusCoins: 2000000, sortOrder: packages.length + 1, isActive: true }); }}
                    className="flex items-center gap-2 px-4 py-2 bg-violet-600 hover:bg-violet-500 text-white rounded-lg text-[10px] font-black uppercase tracking-wider">
                    <Plus size={14} /> Add Package
                  </button>
                )}
              </div>

              {showPkgForm && (
                <div className="bg-white/5 rounded-2xl p-6 border border-white/[0.04] space-y-4">
                  <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Recharge \$</label>
                      <input type="number" min="1" className="glass-input w-full h-12"
                        value={pkgForm.rechargeAmount} onChange={e => setPkgForm({...pkgForm, rechargeAmount: e.target.value})} />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Base Coins</label>
                      <input type="number" min="0" className="glass-input w-full h-12"
                        value={pkgForm.baseCoins} onChange={e => setPkgForm({...pkgForm, baseCoins: e.target.value})} />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Bonus Coins</label>
                      <input type="number" min="0" className="glass-input w-full h-12"
                        value={pkgForm.bonusCoins} onChange={e => setPkgForm({...pkgForm, bonusCoins: e.target.value})} />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Total (calc)</label>
                      <div className="glass-input w-full h-12 flex items-center px-4 text-slate-400 font-bold">
                        {(Number(pkgForm.baseCoins || 0) + Number(pkgForm.bonusCoins || 0)).toLocaleString()}
                      </div>
                    </div>
                    <div className="space-y-1">
                      <label className="text-[9px] font-black text-slate-500 uppercase">Order</label>
                      <input type="number" min="1" className="glass-input w-full h-12"
                        value={pkgForm.sortOrder} onChange={e => setPkgForm({...pkgForm, sortOrder: e.target.value})} />
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <button type="button" onClick={handleSavePkg}
                      className="px-6 h-10 bg-violet-600 text-white rounded-lg text-[10px] font-black uppercase tracking-wider">
                      <Save size={14} className="inline mr-1" /> {editingPkgId ? 'Update' : 'Create'}
                    </button>
                    <button type="button" onClick={() => setShowPkgForm(false)}
                      className="px-4 h-10 bg-white/5 text-slate-400 rounded-lg text-[10px] font-black uppercase tracking-wider">
                      Cancel
                    </button>
                  </div>
                </div>
              )}

              <div className="space-y-2">
                {packages.length === 0 ? (
                  <p className="text-slate-500 text-xs text-center py-8">No packages configured.</p>
                ) : (
                  packages.map(pkg => (
                    <div key={pkg.id} className="flex items-center justify-between bg-white/5 rounded-xl p-4 border border-white/[0.04]">
                      <div className="flex items-center gap-4">
                        <Coins size={16} className="text-amber-400" />
                        <div>
                          <span className="text-sm font-bold text-white">\${pkg.rechargeAmount}</span>
                          <span className="text-[10px] text-slate-500 ml-3">{pkg.baseCoins?.toLocaleString()} base</span>
                          <span className="text-[10px] text-amber-400 ml-3">+{pkg.bonusCoins?.toLocaleString()} bonus</span>
                          <span className="text-[10px] text-emerald-400 ml-3">= {pkg.totalCoins?.toLocaleString()} total</span>
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <button type="button" onClick={() => {
                          setPkgForm({ rechargeAmount: pkg.rechargeAmount, baseCoins: pkg.baseCoins, bonusCoins: pkg.bonusCoins, sortOrder: pkg.sortOrder, isActive: pkg.isActive });
                          setEditingPkgId(pkg.id); setShowPkgForm(true);
                        }} className="p-2 hover:bg-violet-600/20 text-violet-400 rounded-lg">
                          <Edit2 size={14} />
                        </button>
                        <button type="button" onClick={() => handleDeletePkg(pkg.id)} className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg">
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}

          {/* Save Event Button (always visible) */}
          <div className="flex gap-4 pt-4 border-t border-white/[0.04]">
            <button type="submit" className="px-8 h-12 bg-violet-600 hover:bg-violet-500 text-white rounded-xl text-xs font-black uppercase tracking-widest flex items-center gap-2">
              <Save size={16} /> {editingId ? 'Update Event' : 'Create Event'}
            </button>
            <button type="button" onClick={resetForm} className="px-6 h-12 bg-white/5 hover:bg-white/10 text-white rounded-xl text-xs font-black uppercase tracking-widest">
              Cancel
            </button>
          </div>
        </form>
      )}

      {/* ── EVENTS LIST ── */}
      <div className="bg-[#111115] border border-white/[0.04] rounded-3xl overflow-hidden shadow-2xl">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-white/[0.02] border-b border-white/[0.04] text-[10px] font-black text-slate-500 uppercase tracking-wider">
              <th className="p-5">Event</th>
              <th className="p-5">Type</th>
              <th className="p-5">Dates</th>
              <th className="p-5">Status</th>
              <th className="p-5 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.02] text-xs">
            {events.length === 0 ? (
              <tr>
                <td colSpan="5" className="p-10 text-center text-slate-500 uppercase font-black">No events created yet.</td>
              </tr>
            ) : (
              events.map(ev => {
                const status = getStatus(ev);
                const isExpanded = expandedEvent === ev.id;
                return (
                  <tr key={ev.id} className="hover:bg-white/[0.01] transition-colors">
                    <td className="p-5">
                      <div className="flex items-center gap-4">
                        {ev.bannerImage ? (
                          <div className="w-20 h-12 rounded-xl overflow-hidden border border-white/5 bg-slate-900">
                            <img src={ev.bannerImage} className="w-full h-full object-cover" alt="" />
                          </div>
                        ) : (
                          <div className="w-20 h-12 rounded-xl bg-violet-500/10 flex items-center justify-center">
                            <Zap size={18} className="text-violet-400" />
                          </div>
                        )}
                        <div>
                          <div className="font-bold text-white">{ev.title}</div>
                          <div className="text-[10px] text-slate-500 mt-0.5 truncate max-w-[200px]">{ev.description}</div>
                        </div>
                      </div>
                    </td>
                    <td className="p-5">
                      <span className="px-3 py-1 rounded-full text-[9px] font-black bg-violet-500/10 text-violet-400 border border-violet-500/20 uppercase">
                        {ev.type?.replace('_', ' ') || 'generic'}
                      </span>
                    </td>
                    <td className="p-5 text-slate-400 font-mono text-[10px]">
                      <div>{ev.startDate?.substring(0, 10)}</div>
                      <div className="text-slate-600">{ev.endDate?.substring(0, 10)}</div>
                    </td>
                    <td className="p-5">
                      <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black border uppercase tracking-widest ${status.color}`}>
                        {status.label === 'LIVE' && <Check size={8} />}
                        {status.label}
                      </span>
                    </td>
                    <td className="p-5 text-right">
                      <div className="flex justify-end gap-2">
                        <button onClick={() => setExpandedEvent(isExpanded ? null : ev.id)}
                          className="p-2 hover:bg-white/10 text-slate-400 rounded-lg transition-all">
                          {isExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                        </button>
                        <button onClick={() => handleEdit(ev)}
                          className="p-2 hover:bg-violet-600/20 text-violet-400 rounded-lg border border-violet-500/10">
                          <Edit2 size={14} />
                        </button>
                        <button onClick={() => handleDelete(ev.id)}
                          className="p-2 hover:bg-rose-600/20 text-rose-400 rounded-lg border border-rose-500/10">
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
  );
};

import { useState, useEffect, useCallback } from 'react';
import { db } from '../firebase';
import { doc, getDoc, setDoc, collection, query, orderBy, onSnapshot, addDoc, updateDoc, deleteDoc, writeBatch } from 'firebase/firestore';
import { RefreshCw, Save, Server, Image, Layers, Plus, Trash2, ToggleLeft, ToggleRight, ExternalLink, Navigation, GripVertical } from 'lucide-react';

const DEFAULT_LEVELS = [
  { level: 1, coinsTarget: 500000, partnerSlots: 4, ownerReward: 25000, partnerReward: 5000, totalReward: 45000 },
  { level: 2, coinsTarget: 1000000, partnerSlots: 5, ownerReward: 50000, partnerReward: 10000, totalReward: 90000 },
  { level: 3, coinsTarget: 3000000, partnerSlots: 6, ownerReward: 150000, partnerReward: 25000, totalReward: 225000 },
  { level: 4, coinsTarget: 5000000, partnerSlots: 7, ownerReward: 250000, partnerReward: 50000, totalReward: 450000 },
  { level: 5, coinsTarget: 10000000, partnerSlots: 7, ownerReward: 500000, partnerReward: 100000, totalReward: 900000 },
  { level: 6, coinsTarget: 20000000, partnerSlots: 7, ownerReward: 1000000, partnerReward: 200000, totalReward: 1800000 },
  { level: 7, coinsTarget: 50000000, partnerSlots: 7, ownerReward: 2500000, partnerReward: 500000, totalReward: 4500000 },
];

const TABS = [
  { id: 'levels', label: 'Levels Config', icon: Layers },
  { id: 'banners', label: 'Room Banners', icon: Image },
];

function LevelsTab({ levels, setLevels, loading, handleSeed, handleSave, saving, message, formatNum }) {
  function updateLevel(idx, field, value) {
    const copy = [...levels];
    const num = parseInt(value) || 0;
    copy[idx] = { ...copy[idx], [field]: num };
    if (field === 'coinsTarget' || field === 'ownerReward' || field === 'partnerReward') {
      copy[idx].totalReward = copy[idx].ownerReward + copy[idx].partnerReward * copy[idx].partnerSlots;
    }
    setLevels(copy);
  }

  return (
    <div>
      <div className="flex gap-3 mb-6">
        <button onClick={handleSeed} disabled={saving}
          className="flex items-center gap-2 px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700 disabled:opacity-50">
          <Server size={16} /> Seed Defaults
        </button>
        <button onClick={() => window.location.reload()}
          className="flex items-center gap-2 px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700">
          <RefreshCw size={16} /> Reload
        </button>
        <button onClick={handleSave} disabled={saving}
          className="flex items-center gap-2 px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 disabled:opacity-50 font-bold">
          <Save size={16} /> {saving ? 'Saving...' : 'Save to Firestore'}
        </button>
      </div>

      {message && (
        <div className="mb-4 p-3 bg-gray-800 rounded-lg text-white text-sm">{message}</div>
      )}

      {loading ? (
        <div className="text-gray-400">Loading...</div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm text-gray-300">
            <thead>
              <tr className="bg-gray-800 text-gray-400 uppercase text-xs">
                <th className="p-3 text-left">Level</th>
                <th className="p-3 text-left">Coins Target</th>
                <th className="p-3 text-left">Partner Slots</th>
                <th className="p-3 text-left">Owner Reward 💎</th>
                <th className="p-3 text-left">Partner Reward 💎</th>
                <th className="p-3 text-left">Max Total 💎</th>
              </tr>
            </thead>
            <tbody>
              {levels.map((lvl, i) => (
                <tr key={i} className="border-b border-gray-800 hover:bg-gray-800/50">
                  <td className="p-3 font-bold text-white">Level {lvl.level}</td>
                  <td className="p-3">
                    <input type="number" value={lvl.coinsTarget}
                      onChange={e => updateLevel(i, 'coinsTarget', e.target.value)}
                      className="w-32 bg-gray-900 text-white px-3 py-1.5 rounded border border-gray-700 focus:border-indigo-500 outline-none" />
                    <span className="text-gray-500 ml-2 text-xs">{formatNum(lvl.coinsTarget)}</span>
                  </td>
                  <td className="p-3">
                    <input type="number" min="1" max="20" value={lvl.partnerSlots}
                      onChange={e => updateLevel(i, 'partnerSlots', e.target.value)}
                      className="w-20 bg-gray-900 text-white px-3 py-1.5 rounded border border-gray-700 focus:border-indigo-500 outline-none" />
                  </td>
                  <td className="p-3">
                    <input type="number" value={lvl.ownerReward}
                      onChange={e => updateLevel(i, 'ownerReward', e.target.value)}
                      className="w-32 bg-gray-900 text-white px-3 py-1.5 rounded border border-gray-700 focus:border-indigo-500 outline-none" />
                  </td>
                  <td className="p-3">
                    <input type="number" value={lvl.partnerReward}
                      onChange={e => updateLevel(i, 'partnerReward', e.target.value)}
                      className="w-32 bg-gray-900 text-white px-3 py-1.5 rounded border border-gray-700 focus:border-indigo-500 outline-none" />
                  </td>
                  <td className="p-3 text-green-400 font-bold">{formatNum(lvl.totalReward)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function BannersTab({ banners, setBanners, saving, setSaving, setMessage }) {
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    imageUrl: '',
    actionType: 'navigation',
    actionValue: '',
    order: 0,
    enabled: true,
  });

  useEffect(() => {
    const q = query(collection(db, 'room_integrated_banners'), orderBy('order', 'asc'));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setBanners(list);
    });
    return unsub;
  }, [setBanners]);

  function resetForm() {
    setForm({ imageUrl: '', actionType: 'navigation', actionValue: '', order: 0, enabled: true });
    setEditingId(null);
    setShowForm(false);
  }

  function editBanner(b) {
    setForm({ imageUrl: b.imageUrl || '', actionType: b.actionType || 'navigation', actionValue: b.actionValue || '', order: b.order || 0, enabled: b.enabled !== false });
    setEditingId(b.id);
    setShowForm(true);
  }

  async function handleSaveBanner() {
    if (!form.imageUrl.trim()) {
      setMessage('❌ Image URL is required');
      return;
    }
    setSaving(true);
    setMessage('');
    try {
      if (editingId) {
        await updateDoc(doc(db, 'room_integrated_banners', editingId), {
          imageUrl: form.imageUrl,
          actionType: form.actionType,
          actionValue: form.actionValue,
          order: Number(form.order),
          enabled: form.enabled,
        });
        setMessage('✅ Banner updated');
      } else {
        await addDoc(collection(db, 'room_integrated_banners'), {
          imageUrl: form.imageUrl,
          actionType: form.actionType,
          actionValue: form.actionValue,
          order: Number(form.order),
          enabled: form.enabled,
        });
        setMessage('✅ Banner created');
      }
      resetForm();
    } catch (e) {
      setMessage('❌ Error: ' + e.message);
    }
    setSaving(false);
  }

  async function handleDelete(id) {
    if (!window.confirm('Delete this banner?')) return;
    try {
      await deleteDoc(doc(db, 'room_integrated_banners', id));
      setMessage('✅ Banner deleted');
    } catch (e) {
      setMessage('❌ Error: ' + e.message);
    }
  }

  async function toggleEnabled(b) {
    try {
      await updateDoc(doc(db, 'room_integrated_banners', b.id), { enabled: !b.enabled });
    } catch (e) {
      setMessage('❌ Error: ' + e.message);
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <p className="text-gray-400 text-sm">Manage integrated banner carousel shown in live rooms. Banners display as a swipeable carousel with auto-scroll.</p>
        <button onClick={() => { resetForm(); setShowForm(true); }}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 font-bold">
          <Plus size={16} /> New Banner
        </button>
      </div>

      {showForm && (
        <div className="mb-6 p-4 bg-gray-800/50 rounded-xl border border-gray-700">
          <h3 className="text-white font-bold mb-4">{editingId ? 'Edit Banner' : 'New Banner'}</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Image URL (Cloudinary)</label>
              <input type="text" value={form.imageUrl}
                onChange={e => setForm({ ...form, imageUrl: e.target.value })}
                placeholder="https://res.cloudinary.com/..."
                className="w-full bg-gray-900 text-white px-3 py-2 rounded border border-gray-700 focus:border-indigo-500 outline-none text-sm" />
              {form.imageUrl && (
                <img src={form.imageUrl} alt="preview"
                  className="mt-2 w-24 h-24 object-cover rounded-lg border border-gray-700"
                  onError={e => e.target.style.display = 'none'} />
              )}
            </div>
            <div className="space-y-3">
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Action Type</label>
                <select value={form.actionType}
                  onChange={e => setForm({ ...form, actionType: e.target.value })}
                  className="w-full bg-gray-900 text-white px-3 py-2 rounded border border-gray-700 focus:border-indigo-500 outline-none text-sm">
                  <option value="navigation">Navigation (internal route)</option>
                  <option value="url">URL (external link)</option>
                </select>
              </div>
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">
                  {form.actionType === 'navigation' ? 'Route Path' : 'External URL'}
                </label>
                <input type="text" value={form.actionValue}
                  onChange={e => setForm({ ...form, actionValue: e.target.value })}
                  placeholder={form.actionType === 'navigation' ? '/room-support' : 'https://...'}
                  list={form.actionType === 'navigation' ? 'route-suggestions' : undefined}
                  className="w-full bg-gray-900 text-white px-3 py-2 rounded border border-gray-700 focus:border-indigo-500 outline-none text-sm" />
                {form.actionType === 'navigation' && (
                  <datalist id="route-suggestions">
                    <option value="/home" />
                    <option value="/wallet" />
                    <option value="/leaderboard" />
                    <option value="/vip-shop" />
                    <option value="/agency-portal" />
                    <option value="/svip-privileges" />
                    <option value="/invite-get-coins" />
                    <option value="/love-house" />
                    <option value="/cp-level" />
                    <option value="/prop-warehouse" />
                    <option value="/family-portal" />
                    <option value="/family-list" />
                    <option value="/settings" />
                    <option value="/room-support" />
                    <option value="/inbox" />
                    <option value="/vip-rewards" />
                    <option value="/recharge-event-detail" />
                  </datalist>
                )}
              </div>
              <div className="flex items-center gap-4">
                <div>
                  <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Display Order</label>
                  <input type="number" min="0" value={form.order}
                    onChange={e => setForm({ ...form, order: e.target.value })}
                    className="w-24 bg-gray-900 text-white px-3 py-2 rounded border border-gray-700 focus:border-indigo-500 outline-none text-sm" />
                </div>
                <div className="flex items-center gap-2 pt-5">
                  <label className="text-gray-400 text-xs uppercase tracking-wider mr-1">Enabled</label>
                  <button onClick={() => setForm({ ...form, enabled: !form.enabled })}
                    className={`p-1.5 rounded ${form.enabled ? 'text-green-400 bg-green-400/10' : 'text-gray-500 bg-gray-800'}`}>
                    {form.enabled ? <ToggleRight size={20} /> : <ToggleLeft size={20} />}
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <button onClick={handleSaveBanner} disabled={saving}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 disabled:opacity-50 font-bold text-sm">
              {saving ? 'Saving...' : editingId ? 'Update Banner' : 'Create Banner'}
            </button>
            <button onClick={resetForm}
              className="px-4 py-2 bg-gray-700 text-white rounded-lg hover:bg-gray-600 text-sm">Cancel</button>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {banners.length === 0 ? (
          <div className="col-span-full text-center py-12 text-gray-500">
            <Image size={40} className="mx-auto mb-3 opacity-30" />
            <p className="font-bold">No banners yet</p>
            <p className="text-sm mt-1">Click "New Banner" to add the first one.</p>
          </div>
        ) : (
          banners.map((b) => (
            <div key={b.id} className={`p-4 rounded-xl border ${b.enabled ? 'border-gray-700 bg-gray-800/50' : 'border-gray-800 bg-gray-900/50 opacity-60'}`}>
              <div className="flex items-start gap-3">
                <div className="w-16 h-16 rounded-lg overflow-hidden flex-shrink-0 bg-gray-900">
                  {b.imageUrl ? (
                    <img src={b.imageUrl} alt="" className="w-full h-full object-cover"
                      onError={e => { e.target.src = ''; e.target.style.display = 'none'; }} />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center"><Image size={20} className="text-gray-600" /></div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1 text-xs text-gray-500 mb-1">
                    {b.actionType === 'navigation' ? <Navigation size={12} /> : <ExternalLink size={12} />}
                    <span className="truncate">{b.actionValue || '-'}</span>
                  </div>
                  <div className="text-xs text-gray-500">Order: {b.order ?? 0}</div>
                </div>
                <div className="flex items-center gap-1">
                  <button onClick={() => toggleEnabled(b)}
                    className={`p-1.5 rounded ${b.enabled ? 'text-green-400' : 'text-gray-600'}`}
                    title={b.enabled ? 'Disable' : 'Enable'}>
                    {b.enabled ? <ToggleRight size={18} /> : <ToggleLeft size={18} />}
                  </button>
                  <button onClick={() => editBanner(b)}
                    className="p-1.5 text-blue-400 hover:text-blue-300" title="Edit">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/></svg>
                  </button>
                  <button onClick={() => handleDelete(b.id)}
                    className="p-1.5 text-red-400 hover:text-red-300" title="Delete">
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export function RoomSupportManagement() {
  const [tab, setTab] = useState('levels');
  const [levels, setLevels] = useState([...DEFAULT_LEVELS]);
  const [banners, setBanners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (tab === 'levels') loadConfig();
  }, [tab]);

  async function loadConfig() {
    setLoading(true);
    try {
      const snap = await getDoc(doc(db, 'room_support_configs', 'settings'));
      if (snap.exists() && snap.data().levels) {
        setLevels(snap.data().levels.map((l, i) => ({ ...DEFAULT_LEVELS[i], ...l })));
      }
    } catch (e) { console.error(e); }
    setLoading(false);
  }

  async function handleSave() {
    setSaving(true);
    setMessage('');
    try {
      await setDoc(doc(db, 'room_support_configs', 'settings'), { levels, updatedAt: new Date() }, { merge: true });
      setMessage('✅ Config saved to Firestore');
    } catch (e) { setMessage('❌ Error: ' + e.message); }
    setSaving(false);
  }

  async function handleSeed() {
    setSaving(true);
    setMessage('');
    try {
      await setDoc(doc(db, 'room_support_configs', 'settings'), { levels: DEFAULT_LEVELS, updatedAt: new Date() }, { merge: true });
      setLevels([...DEFAULT_LEVELS]);
      setMessage('✅ Default config seeded');
    } catch (e) { setMessage('❌ Error: ' + e.message); }
    setSaving(false);
  }

  function formatNum(n) {
    if (n >= 10000000) return (n / 10000000).toFixed(1) + 'Cr';
    if (n >= 100000) return (n / 100000).toFixed(1) + 'L';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return n.toString();
  }

  return (
    <div className="p-8 max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold text-white mb-2">Room Support Config</h1>
      <p className="text-gray-400 mb-6">Manage room support levels and integrated banner carousel</p>

      <div className="flex gap-1 mb-6 border-b border-gray-800">
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`flex items-center gap-2 px-4 py-3 text-xs font-bold uppercase tracking-wider border-b-2 transition-all ${tab === t.id ? 'text-indigo-400 border-indigo-400' : 'text-gray-500 border-transparent hover:text-gray-300'}`}>
            <t.icon size={14} /> {t.label}
          </button>
        ))}
      </div>

      {message && (
        <div className="mb-4 p-3 bg-gray-800 rounded-lg text-white text-sm">{message}</div>
      )}

      {tab === 'levels' && (
        <LevelsTab levels={levels} setLevels={setLevels} loading={loading}
          handleSeed={handleSeed} handleSave={handleSave} saving={saving} message={message} formatNum={formatNum} />
      )}

      {tab === 'banners' && (
        <BannersTab banners={banners} setBanners={setBanners} saving={saving} setSaving={setSaving} setMessage={setMessage} />
      )}
    </div>
  );
}

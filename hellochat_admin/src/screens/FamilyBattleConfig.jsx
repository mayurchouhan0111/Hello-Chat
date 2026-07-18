import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { doc, getDoc, setDoc, collectionGroup, getDocs, query, orderBy, limit, Timestamp } from 'firebase/firestore';
import { RefreshCw, Save, Server, Trophy, Users, Palette, Zap, Activity } from 'lucide-react';

const DEFAULT_THRESHOLDS = [
  0, 5000000, 10000000, 25000000, 50000000,
  100000000, 200000000, 400000000, 600000000, 800000000,
];

const DEFAULT_CAPS = [
  { maxLevel: 2, cap: 100 },
  { maxLevel: 4, cap: 150 },
  { maxLevel: 6, cap: 200 },
  { maxLevel: 8, cap: 300 },
  { maxLevel: 9, cap: 500 },
  { maxLevel: 10, cap: 1000 },
];

export function FamilyBattleConfig() {
  const [tab, setTab] = useState('thresholds');
  const [thresholds, setThresholds] = useState([...DEFAULT_THRESHOLDS]);
  const [caps, setCaps] = useState(DEFAULT_CAPS.map(c => ({ ...c })));
  const [activeBattles, setActiveBattles] = useState([]);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => { loadConfig(); loadActiveBattles(); }, []);

  async function loadConfig() {
    setLoading(true);
    try {
      const snap = await getDoc(doc(db, 'family_battle_configs', 'settings'));
      if (snap.exists()) {
        const d = snap.data();
        if (d.levelThresholds) setThresholds(d.levelThresholds);
        if (d.participantCaps) setCaps(d.participantCaps.map((c, i) => ({ ...(DEFAULT_CAPS[i] || {}), ...c })));
      }
    } catch (e) { console.error(e); }
    setLoading(false);
  }

  async function loadActiveBattles() {
    try {
      const q = query(
        collectionGroup(db, 'battles'),
        orderBy('startedAt', 'desc'),
        limit(50)
      );
      const snap = await getDocs(q);
      const seen = new Set();
      const list = [];
      snap.forEach(d => {
        if (seen.has(d.id)) return;
        seen.add(d.id);
        const data = d.data();
        if (data.status === 'active') list.push({ id: d.id, ...data });
      });
      setActiveBattles(list.slice(0, 20));
    } catch (e) { console.error(e); }
  }

  async function loadLogs() {
    try {
      const q = query(
        collectionGroup(db, 'family_battle_transactions'),
        orderBy('createdAt', 'desc'),
        limit(50)
      );
      const snap = await getDocs(q);
      setLogs(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (e) { console.error(e); }
  }

  async function handleSave() {
    setSaving(true);
    setMessage('');
    try {
      await setDoc(doc(db, 'family_battle_configs', 'settings'), {
        levelThresholds: thresholds,
        participantCaps: caps,
        updatedAt: new Date(),
      }, { merge: true });
      setMessage('✅ Config saved');
    } catch (e) { setMessage('❌ ' + e.message); }
    setSaving(false);
  }

  async function handleSeed() {
    setSaving(true);
    setMessage('');
    try {
      await setDoc(doc(db, 'family_battle_configs', 'settings'), {
        levelThresholds: DEFAULT_THRESHOLDS,
        participantCaps: DEFAULT_CAPS,
        updatedAt: new Date(),
      });
      setThresholds([...DEFAULT_THRESHOLDS]);
      setCaps(DEFAULT_CAPS.map(c => ({ ...c })));
      setMessage('✅ Defaults seeded');
    } catch (e) { setMessage('❌ ' + e.message); }
    setSaving(false);
  }

  async function handleResetRankings(period) {
    if (!window.confirm(`Reset ${period} rankings?`)) return;
    try {
      const snap = await getDocs(query(collectionGroup(db, 'familyRankings'), where('period', '==', period)));
      const batch = writeBatch(db);
      snap.forEach(d => batch.delete(d.ref));
      await batch.commit();
      setMessage(`✅ ${period} rankings reset`);
    } catch (e) { setMessage('❌ ' + e.message); }
  }

  function formatNum(n) {
    if (n >= 100000000) return (n / 100000000).toFixed(1) + 'Cr';
    if (n >= 10000000) return (n / 10000000).toFixed(1) + 'Cr';
    if (n >= 100000) return (n / 100000).toFixed(1) + 'L';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return String(n);
  }

  function formatTS(ts) {
    if (!ts) return '-';
    const d = ts instanceof Timestamp ? ts.toDate() : new Date(ts);
    return d.toLocaleString();
  }

  const tabs = [
    { id: 'thresholds', label: 'Level Thresholds', icon: Trophy },
    { id: 'caps', label: 'Participant Caps', icon: Users },
    { id: 'battles', label: 'Active Battles', icon: Zap },
    { id: 'logs', label: 'Battle Logs', icon: Activity },
  ];

  return (
    <div className="p-8 max-w-6xl mx-auto text-gray-300">
      <h1 className="text-3xl font-bold text-white mb-2">Family Battle Config</h1>
      <p className="text-gray-500 mb-6">Edit system-wide battle settings, thresholds, and caps</p>

      <div className="flex gap-3 mb-6">
        <button onClick={handleSeed} disabled={saving}
          className="flex items-center gap-2 px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700 disabled:opacity-50">
          <Server size={16} /> Seed Defaults
        </button>
        <button onClick={handleSave} disabled={saving}
          className="flex items-center gap-2 px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 disabled:opacity-50 font-bold">
          <Save size={16} /> {saving ? 'Saving...' : 'Save to Firestore'}
        </button>
      </div>

      {message && <div className="mb-4 p-3 bg-gray-800 rounded-lg text-white text-sm">{message}</div>}

      {/* Tabs */}
      <div className="flex gap-1 mb-6 border-b border-gray-800">
        {tabs.map(t => (
          <button key={t.id} onClick={() => { setTab(t.id); if (t.id === 'logs') loadLogs(); if (t.id === 'battles') loadActiveBattles(); }}
            className={`flex items-center gap-2 px-4 py-3 text-xs font-bold uppercase tracking-wider border-b-2 transition-all ${tab === t.id ? 'text-indigo-400 border-indigo-400' : 'text-gray-500 border-transparent hover:text-gray-300'}`}>
            <t.icon size={14} /> {t.label}
          </button>
        ))}
      </div>

      {loading ? <div className="text-gray-500">Loading...</div> : (
        <>
          {tab === 'thresholds' && (
            <div className="space-y-4">
              <p className="text-sm text-gray-500">Points required to reach each family level. Level 1 = 0 base.</p>
              {thresholds.map((val, i) => (
                <div key={i} className="flex items-center gap-4">
                  <span className="w-20 font-bold text-white">Level {i + 1}</span>
                  <span className="text-gray-500 w-20 text-right">{formatNum(val)}</span>
                  <input type="number" value={val}
                    onChange={e => { const c = [...thresholds]; c[i] = parseInt(e.target.value) || 0; setThresholds(c); }}
                    className="flex-1 bg-gray-900 text-white px-3 py-2 rounded border border-gray-700 focus:border-indigo-500 outline-none" />
                  {i > 0 && <span className="text-gray-600 text-xs">(+{formatNum(val - thresholds[i - 1])})</span>}
                </div>
              ))}
            </div>
          )}

          {tab === 'caps' && (
            <div className="space-y-4">
              <p className="text-sm text-gray-500">Maximum participants per battle based on family level.</p>
              <table className="w-full text-sm">
                <thead><tr className="bg-gray-800 text-gray-400 uppercase text-xs">
                  <th className="p-3 text-left">Level Range</th>
                  <th className="p-3 text-left">Max Participants</th>
                </tr></thead>
                <tbody>
                  {caps.map((c, i) => (
                    <tr key={i} className="border-b border-gray-800">
                      <td className="p-3 font-bold text-white">1-{c.maxLevel}</td>
                      <td className="p-3">
                        <input type="number" value={c.cap}
                          onChange={e => { const copy = [...caps]; copy[i] = { ...copy[i], cap: parseInt(e.target.value) || 0 }; setCaps(copy); }}
                          className="w-32 bg-gray-900 text-white px-3 py-1.5 rounded border border-gray-700 focus:border-indigo-500 outline-none" />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {tab === 'battles' && (
            <div>
              <p className="text-sm text-gray-500 mb-4">Currently active battles ({activeBattles.length})</p>
              {activeBattles.length === 0 ? (
                <p className="text-gray-600">No active battles</p>
              ) : (
                <div className="space-y-3">
                  {activeBattles.map(b => (
                    <div key={b.id} className="p-4 bg-gray-900 rounded-xl border border-gray-800">
                      <div className="flex items-center justify-between">
                        <div>
                          <span className="text-emerald-400 font-bold">{b.familyAName || b.familyAId}</span>
                          <span className="text-gray-500 mx-2">vs</span>
                          <span className="text-red-400 font-bold">{b.familyBName || b.familyBId}</span>
                        </div>
                        <div className="flex items-center gap-4 text-sm">
                          <span className="text-emerald-400 font-bold">{b.familyAPoints || 0}</span>
                          <span className="text-gray-400 text-xs">-</span>
                          <span className="text-red-400 font-bold">{b.familyBPoints || 0}</span>
                          <span className="text-gray-500 text-xs ml-2">{formatTS(b.startedAt)}</span>
                        </div>
                      </div>
                      <p className="text-[10px] text-gray-600 mt-1">ID: {b.id}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {tab === 'logs' && (
            <div>
              <p className="text-sm text-gray-500 mb-4">Recent battle transactions</p>
              {logs.length === 0 ? (
                <p className="text-gray-600">No logs yet</p>
              ) : (
                <div className="space-y-2 text-xs">
                  {logs.map(l => (
                    <div key={l.id} className="p-3 bg-gray-900 rounded-lg border border-gray-800">
                      <div className="flex items-center justify-between">
                        <span className={`font-bold ${l.type === 'battle_created' ? 'text-emerald-400' : 'text-indigo-400'}`}>
                          {l.type === 'battle_created' ? '⚔️ Created' : '🏁 Ended'}
                        </span>
                        <span className="text-gray-500">{formatTS(l.createdAt || l.endedAt)}</span>
                      </div>
                      {l.type === 'battle_created' ? (
                        <p className="text-gray-400 mt-1">{l.challengerName} vs {l.opponentName} ({l.participantCount} participants)</p>
                      ) : (
                        <p className="text-gray-400 mt-1">
                          Score: {l.familyAPoints} - {l.familyBPoints}
                          {l.winnerId ? ` • Winner: ${l.winnerId === l.familyAId ? 'Family A' : 'Family B'}` : ' • Draw'}
                        </p>
                      )}
                      <p className="text-gray-600 mt-0.5">Battle: {l.battleId}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}

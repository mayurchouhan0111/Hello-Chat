import { useState, useEffect, useCallback } from 'react';
import { db, functions } from '../firebase';
import { httpsCallable } from 'firebase/functions';
import { collection, getDocs, limit as fsLimit, query } from 'firebase/firestore';
import {
  Activity,
  CalendarDays,
  Target,
  Coins,
  Wallet,
  RefreshCw,
  Users,
  Radio,
} from 'lucide-react';

export const HostMetrics = () => {
  const [payload, setPayload] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await httpsCallable(functions, 'getHostMetrics')({});
      if (res?.data) {
        setPayload(res.data);
        setLoading(false);
        return;
      }
    } catch (e) {
      console.warn('getHostMetrics callable error, falling back to direct Firestore:', e?.message);
    }

    try {
      const snap = await getDocs(query(collection(db, 'users'), fsLimit(100)));
      const rawHosts = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      const mapped = rawHosts.map(u => ({
        uid: u.id,
        displayName: u.displayName || u.username || 'User',
        photoUrl: u.profilePhotoUrl || u.photoUrl || '',
        agencyId: u.agencyId || null,
        agencyName: u.agencyName || null,
        isLive: !!u.isLive,
        liveMinutesTotal: Number(u.liveMinutes || 0),
        liveHoursTotal: Math.round(((Number(u.liveMinutes || 0)) / 60) * 10) / 10,
        liveSessionsTotal: Number(u.liveSessions || 0),
        liveDayCount: 0,
        liveMinutesByDay: [],
        beansEarned: Number(u.beansBalance || u.totalBeansReceived || 0),
        beansTarget: Number(u.monthlyTargetBeans || 0),
        beansProgressPct: Number(u.monthlyTargetBeans) > 0 ? Math.min(100, Math.floor((Number(u.beansBalance || 0) / Number(u.monthlyTargetBeans)) * 100)) : null,
        totalRechargeUSD: typeof u.totalRechargeUSD === 'number' ? u.totalRechargeUSD : null,
        salaryPayoutCount: 0,
        salaryLastPaidAt: null
      }));
      setPayload({ me: mapped[0] || null, roster: { scope: 'global', hosts: mapped } });
    } catch (err) {
      setError(err.message || 'Failed to load host metrics');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const saveTarget = async (hostUid, value) => {
    const target = Number(value);
    if (!Number.isFinite(target) || target < 0) {
      alert('Beans target must be zero or greater.');
      return;
    }
    try {
      await httpsCallable(functions, 'manageHostProfile')({
        hostUid,
        beansTarget: Math.floor(target),
      });
      await load();
    } catch (e) {
      alert('Could not save target: ' + (e.message || e));
    }
  };

  const me = payload?.me || null;
  const roster = payload?.roster || null;
  const hosts = roster?.hosts || [];

  return (
    <div className="space-y-10 animate-fade-in text-white pb-20">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-1">
        <div>
          <h1 className="text-4xl font-black text-white tracking-tighter uppercase flex items-center gap-4">
            <div className="p-3 bg-emerald-500/20 rounded-2xl border border-emerald-500/30">
              <Activity className="text-emerald-400" size={28} />
            </div>
            Host Management
          </h1>
          <p className="text-slate-500 font-bold text-xs uppercase tracking-[0.3em] mt-3">
            Live Time • Live Days • Beans Target • Recharge • Salary
          </p>
        </div>

        <button
          onClick={load}
          className="flex items-center gap-2 px-5 py-3 bg-slate-900 border border-white/10 rounded-2xl text-[10px] font-black uppercase tracking-widest text-slate-400 hover:text-white transition-all"
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      {error && (
        <div className="border border-red-500/30 bg-red-500/10 rounded-2xl p-6 text-sm text-red-300 font-bold">
          {error}
        </div>
      )}

      {loading ? (
        <div className="py-40 text-center animate-pulse font-black text-slate-700 uppercase tracking-widest">
          Loading host metrics...
        </div>
      ) : (
        <>
          {me && <StatRow me={me} />}

          <section>
            <div className="flex items-center gap-3 mb-5">
              <Users size={18} className="text-slate-500" />
              <h2 className="text-sm font-black uppercase tracking-[0.25em] text-slate-400">
                {roster?.scope === 'single' ? 'Selected Host' : `Roster (${hosts.length})`}
              </h2>
            </div>

            {hosts.length === 0 ? (
              <div className="py-32 text-center border-2 border-dashed border-white/5 rounded-[40px] bg-slate-900/20">
                <Radio className="text-slate-800 mx-auto mb-4" size={48} />
                <p className="text-slate-600 font-black uppercase text-xs tracking-widest">
                  No hosts in your scope yet
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {hosts.map((h) => (
                  <HostCard key={h.uid} host={h} onSaveTarget={saveTarget} />
                ))}
              </div>
            )}
          </section>
        </>
      )}
    </div>
  );
};

const StatRow = ({ me }) => {
  const stats = [
    {
      label: 'Live Time',
      value: `${me.liveHoursTotal}h`,
      sub: `${me.liveMinutesTotal.toLocaleString()} min total`,
      icon: Activity,
      tone: 'text-emerald-400',
    },
    {
      label: 'Live Days',
      value: me.liveDayCount,
      sub: `${me.liveSessionsTotal} sessions`,
      icon: CalendarDays,
      tone: 'text-sky-400',
    },
    {
      label: 'Beans Progress',
      value: me.beansProgressPct === null ? '—' : `${me.beansProgressPct}%`,
      sub: `${me.beansEarned.toLocaleString()} / ${me.beansTarget.toLocaleString()}`,
      icon: Target,
      tone: 'text-amber-400',
    },
    {
      label: 'Recharge',
      value: me.totalRechargeUSD === null ? '•••' : `$${me.totalRechargeUSD.toFixed(2)}`,
      sub: 'Lifetime generated',
      icon: Coins,
      tone: 'text-purple-400',
    },
    {
      label: 'Salary',
      value: me.salaryPayoutCount,
      sub: me.salaryLastPaidAt ? 'Payouts completed' : 'No payouts yet',
      icon: Wallet,
      tone: 'text-blue-400',
    },
  ];

  return (
    <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
      {stats.map((s) => (
        <div key={s.label} className="bg-slate-900/60 border border-white/5 rounded-2xl p-5">
          <div className="flex items-center gap-2 mb-3">
            <s.icon size={14} className={s.tone} />
            <span className="text-[9px] font-black uppercase tracking-widest text-slate-500">
              {s.label}
            </span>
          </div>
          <div className="text-2xl font-black text-white tracking-tight">{s.value}</div>
          <div className="text-[10px] font-bold text-slate-600 uppercase mt-1">{s.sub}</div>
        </div>
      ))}
    </div>
  );
};

const HostCard = ({ host, onSaveTarget }) => {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(String(host.beansTarget ?? 0));

  const submit = async () => {
    await onSaveTarget(host.uid, draft);
    setEditing(false);
  };

  const pct = host.beansProgressPct ?? 0;

  return (
    <div className="bg-slate-900/60 border border-white/5 rounded-3xl p-6 relative overflow-hidden">
      <div className="flex items-start justify-between gap-4 mb-5">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-2xl bg-slate-800 border border-white/10 flex items-center justify-center overflow-hidden">
            {host.photoUrl ? (
              <img src={host.photoUrl} alt="" className="w-full h-full object-cover" />
            ) : (
              <Users size={18} className="text-slate-500" />
            )}
          </div>
          <div>
            <div className="font-black text-white leading-tight">{host.displayName}</div>
            <div className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">
              {host.agencyName || host.agencyId || 'Unassigned'}
            </div>
          </div>
        </div>
        {host.isLive && (
          <span className="px-3 py-1 rounded-lg bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-[9px] font-black uppercase tracking-widest">
            Live
          </span>
        )}
      </div>

      <div className="grid grid-cols-3 gap-3 mb-5">
        <MiniStat label="Live" value={`${host.liveHoursTotal}h`} />
        <MiniStat label="Days" value={host.liveDayCount} />
        <MiniStat label="Sessions" value={host.liveSessionsTotal} />
      </div>

      {/* Beans target + progress */}
      <div className="mb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-[9px] font-black uppercase tracking-widest text-slate-500">
            Beans Target
          </span>
          {editing ? (
            <div className="flex items-center gap-2">
              <input
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                type="number"
                min="0"
                className="w-24 bg-slate-800 border border-white/10 rounded-lg px-2 py-1 text-xs font-bold text-white"
              />
              <button
                onClick={submit}
                className="px-3 py-1 rounded-lg bg-emerald-500 text-slate-950 text-[9px] font-black uppercase tracking-widest"
              >
                Save
              </button>
              <button
                onClick={() => setEditing(false)}
                className="px-3 py-1 rounded-lg bg-slate-800 text-slate-400 text-[9px] font-black uppercase tracking-widest"
              >
                Cancel
              </button>
            </div>
          ) : (
            <button
              onClick={() => {
                setDraft(String(host.beansTarget ?? 0));
                setEditing(true);
              }}
              className="px-3 py-1 rounded-lg bg-slate-800 border border-white/10 text-[9px] font-black uppercase tracking-widest text-slate-400 hover:text-white"
            >
              Edit
            </button>
          )}
        </div>

        <div className="text-lg font-black text-white">
          {host.beansEarned.toLocaleString()}{' '}
          <span className="text-xs font-bold text-slate-500">/ {host.beansTarget.toLocaleString()}</span>
          {host.beansProgressPct !== null && (
            <span className="ml-2 text-xs font-black text-amber-400">{host.beansProgressPct}%</span>
          )}
        </div>

        <div className="mt-2 h-2 rounded-full bg-slate-800 overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-amber-500 to-orange-500 transition-all"
            style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
          />
        </div>
      </div>

      <div className="flex items-center justify-between text-[10px] font-bold text-slate-600 uppercase">
        <span>
          Recharge:{' '}
          {host.totalRechargeUSD === null ? (
            <span title="Restricted to your own scope">Hidden</span>
          ) : (
            `$${host.totalRechargeUSD.toFixed(2)}`
          )}
        </span>
        <span>{host.salaryPayoutCount} salary payouts</span>
      </div>

      {host.liveMinutesByDay?.length > 0 && (
        <div className="mt-4 pt-4 border-t border-white/5">
          <div className="text-[9px] font-black uppercase tracking-widest text-slate-500 mb-2">
            Last 14 active days (minutes)
          </div>
          <div className="flex flex-wrap gap-1.5">
            {host.liveMinutesByDay.map((d) => (
              <span
                key={d.day}
                title={`${d.day}: ${d.minutes} min`}
                className="px-2 py-1 rounded bg-slate-800 text-[9px] font-bold text-slate-400"
              >
                {d.day.slice(5)} · {d.minutes}m
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

const MiniStat = ({ label, value }) => (
  <div className="bg-slate-800/60 rounded-xl px-3 py-2 text-center">
    <div className="text-sm font-black text-white">{value}</div>
    <div className="text-[8px] font-black uppercase tracking-widest text-slate-500">{label}</div>
  </div>
);

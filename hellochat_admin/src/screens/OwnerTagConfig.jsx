import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';

export default function OwnerTagConfig() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  const [hostThresholds, setHostThresholds] = useState({
    level1: 0,
    level2: 200000,
    level3: 500000,
    level4: 1000000,
    level5: 2500000,
  });

  const [hostColors, setHostColors] = useState({
    level1: '#4A90E2',
    level2: '#9013FE',
    level3: '#F5A623',
    level4: '#D0021B',
    level5: '#7ED321',
  });

  const [agencyThresholds, setAgencyThresholds] = useState({
    level1: 0,
    level2: 500000,
    level3: 1500000,
    level4: 3000000,
    level5: 5000000,
  });

  const [agencyColors, setAgencyColors] = useState({
    level1: '#20B2AA',
    level2: '#8A2BE2',
    level3: '#FF7F50',
    level4: '#FF1493',
    level5: '#FFD700',
  });

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      setLoading(true);
      const docRef = doc(db, 'system_config', 'dynamic_tags');
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        const data = docSnap.data();
        if (data.hostThresholds) setHostThresholds(data.hostThresholds);
        if (data.hostColors) setHostColors(data.hostColors);
        if (data.agencyThresholds) setAgencyThresholds(data.agencyThresholds);
        if (data.agencyColors) setAgencyColors(data.agencyColors);
      }
    } catch (err) {
      console.error('Error fetching dynamic tag config:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      setSaving(true);
      setMessage('');
      const docRef = doc(db, 'system_config', 'dynamic_tags');
      await setDoc(docRef, {
        hostThresholds,
        hostColors,
        agencyThresholds,
        agencyColors,
        updatedAt: new Date(),
      }, { merge: true });

      setMessage('Dynamic Tag Configuration updated successfully! Mobile apps will update in real time.');
    } catch (err) {
      console.error('Error saving tag config:', err);
      setMessage('Failed to update config: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div style={{ padding: '20px', color: '#fff' }}>Loading Dynamic Tag Configurations...</div>;
  }

  return (
    <div style={{ padding: '24px', color: '#fff', maxWidth: '1000px' }}>
      <h2 style={{ fontSize: '24px', fontWeight: 'bold', marginBottom: '8px' }}>
        🏷️ Owner Panel — Dynamic Tag Color System Config
      </h2>
      <p style={{ color: '#aaa', marginBottom: '24px' }}>
        Exclusive App Owner Control. Adjust Diamond targets and tag hex colors for Host and Agency levels. Changes take effect instantly on all active client apps without redeployment.
      </p>

      {message && (
        <div style={{
          padding: '12px 16px',
          borderRadius: '8px',
          marginBottom: '20px',
          background: message.includes('Failed') ? 'rgba(239, 68, 68, 0.2)' : 'rgba(34, 197, 94, 0.2)',
          border: message.includes('Failed') ? '1px solid #ef4444' : '1px solid #22c55e',
          color: '#fff'
        }}>
          {message}
        </div>
      )}

      <form onSubmit={handleSave}>
        {/* HOST ROLE CONFIG */}
        <div style={{ background: '#1e1e2d', padding: '20px', borderRadius: '12px', marginBottom: '24px' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '16px', color: '#60a5fa' }}>
            🎤 Host Role Level Tags (Levels 1 – 5)
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #333', textAlign: 'left' }}>
                <th style={{ padding: '10px' }}>Level Tier</th>
                <th style={{ padding: '10px' }}>Diamond Target Milestone</th>
                <th style={{ padding: '10px' }}>Hex Color Code</th>
                <th style={{ padding: '10px' }}>Live Tag Preview</th>
              </tr>
            </thead>
            <tbody>
              {[1, 2, 3, 4, 5].map((lvl) => (
                <tr key={`host-${lvl}`} style={{ borderBottom: '1px solid #2a2a3c' }}>
                  <td style={{ padding: '10px', fontWeight: 'bold' }}>Level {lvl}</td>
                  <td style={{ padding: '10px' }}>
                    <input
                      type="number"
                      disabled={lvl === 1}
                      value={hostThresholds[`level${lvl}`]}
                      onChange={(e) => setHostThresholds({ ...hostThresholds, [`level${lvl}`]: parseInt(e.target.value) || 0 })}
                      style={{
                        padding: '8px',
                        borderRadius: '6px',
                        background: '#12121a',
                        color: '#fff',
                        border: '1px solid #444',
                        width: '160px'
                      }}
                    />
                  </td>
                  <td style={{ padding: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <input
                        type="color"
                        value={hostColors[`level${lvl}`]}
                        onChange={(e) => setHostColors({ ...hostColors, [`level${lvl}`]: e.target.value })}
                        style={{ border: 'none', width: '32px', height: '32px', cursor: 'pointer', background: 'transparent' }}
                      />
                      <input
                        type="text"
                        value={hostColors[`level${lvl}`]}
                        onChange={(e) => setHostColors({ ...hostColors, [`level${lvl}`]: e.target.value })}
                        style={{
                          padding: '8px',
                          borderRadius: '6px',
                          background: '#12121a',
                          color: '#fff',
                          border: '1px solid #444',
                          width: '100px'
                        }}
                      />
                    </div>
                  </td>
                  <td style={{ padding: '10px' }}>
                    <span style={{
                      padding: '4px 10px',
                      borderRadius: '10px',
                      background: hostColors[`level${lvl}`],
                      color: '#fff',
                      fontSize: '11px',
                      fontWeight: 'bold'
                    }}>
                      Host L{lvl}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* AGENCY ROLE CONFIG */}
        <div style={{ background: '#1e1e2d', padding: '20px', borderRadius: '12px', marginBottom: '24px' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '16px', color: '#a78bfa' }}>
            🏢 Agency Role Level Tags (Levels 1 – 5)
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #333', textAlign: 'left' }}>
                <th style={{ padding: '10px' }}>Level Tier</th>
                <th style={{ padding: '10px' }}>Diamond Target Milestone</th>
                <th style={{ padding: '10px' }}>Hex Color Code</th>
                <th style={{ padding: '10px' }}>Live Tag Preview</th>
              </tr>
            </thead>
            <tbody>
              {[1, 2, 3, 4, 5].map((lvl) => (
                <tr key={`agency-${lvl}`} style={{ borderBottom: '1px solid #2a2a3c' }}>
                  <td style={{ padding: '10px', fontWeight: 'bold' }}>Level {lvl}</td>
                  <td style={{ padding: '10px' }}>
                    <input
                      type="number"
                      disabled={lvl === 1}
                      value={agencyThresholds[`level${lvl}`]}
                      onChange={(e) => setAgencyThresholds({ ...agencyThresholds, [`level${lvl}`]: parseInt(e.target.value) || 0 })}
                      style={{
                        padding: '8px',
                        borderRadius: '6px',
                        background: '#12121a',
                        color: '#fff',
                        border: '1px solid #444',
                        width: '160px'
                      }}
                    />
                  </td>
                  <td style={{ padding: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <input
                        type="color"
                        value={agencyColors[`level${lvl}`]}
                        onChange={(e) => setAgencyColors({ ...agencyColors, [`level${lvl}`]: e.target.value })}
                        style={{ border: 'none', width: '32px', height: '32px', cursor: 'pointer', background: 'transparent' }}
                      />
                      <input
                        type="text"
                        value={agencyColors[`level${lvl}`]}
                        onChange={(e) => setAgencyColors({ ...agencyColors, [`level${lvl}`]: e.target.value })}
                        style={{
                          padding: '8px',
                          borderRadius: '6px',
                          background: '#12121a',
                          color: '#fff',
                          border: '1px solid #444',
                          width: '100px'
                        }}
                      />
                    </div>
                  </td>
                  <td style={{ padding: '10px' }}>
                    <span style={{
                      padding: '4px 10px',
                      borderRadius: '10px',
                      background: agencyColors[`level${lvl}`],
                      color: '#fff',
                      fontSize: '11px',
                      fontWeight: 'bold'
                    }}>
                      Agency L{lvl}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <button
          type="submit"
          disabled={saving}
          style={{
            padding: '12px 28px',
            borderRadius: '8px',
            background: 'linear-gradient(135deg, #6366f1, #8b5cf6)',
            color: '#fff',
            fontWeight: 'bold',
            border: 'none',
            cursor: saving ? 'not-allowed' : 'pointer',
            fontSize: '15px'
          }}
        >
          {saving ? 'Saving Configurations...' : '💾 Save Dynamic Tag Settings'}
        </button>
      </form>
    </div>
  );
}

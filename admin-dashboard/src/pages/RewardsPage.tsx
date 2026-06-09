import React, { useEffect, useState, useCallback } from 'react';
import { fetchPendingRedemptions, fulfillRedemption } from '../hooks/useFirestore';
import { RewardRedemption } from '../types';

export default function RewardsPage() {
  const [items, setItems]   = useState<RewardRedemption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]   = useState('');
  const [toast, setToast]   = useState('');
  const [note, setNote]     = useState('');
  const [modal, setModal]   = useState<RewardRedemption | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      setItems(await fetchPendingRedemptions());
    } catch (e: any) {
      setError('Failed to load: ' + e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(''), 3000);
  };

  const tierLabel = (tier: number) => {
    if (tier >= 5000) return '🎁 Premium Gift (5000 pts)';
    if (tier >= 2000) return '⭐ Special Reward (2000 pts)';
    return '📋 Admin Task Request (1000 pts)';
  };

  const handleAction = async (status: 'fulfilled' | 'rejected') => {
    if (!modal) return;
    setSaving(true);
    try {
      await fulfillRedemption(modal.id, status, note);
      showToast(status === 'fulfilled' ? '✅ Marked as fulfilled' : '❌ Rejected');
      setModal(null);
      setNote('');
      await load();
    } catch (e: any) {
      setError('Action failed: ' + e.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Reward Requests</h1>
          <p className="page-subtitle">Review and fulfill member reward redemptions</p>
        </div>
        <button className="btn btn-ghost" onClick={load}>↻ Refresh</button>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {loading ? (
        <div className="loading-row"><div className="spinner" /> Loading…</div>
      ) : items.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: 48 }}>
          <div style={{ fontSize: '2.5rem', marginBottom: 12 }}>⭐</div>
          <p style={{ color: 'var(--text-secondary)' }}>No pending reward requests</p>
        </div>
      ) : (
        <div className="review-grid">
          {items.map(item => (
            <div key={item.id} className="review-card card" onClick={() => { setModal(item); setNote(''); }}>
              <div className="review-card-header">
                <span className="badge badge-pending">Pending</span>
                <span className="review-time">{item.requestedAt.toLocaleString()}</span>
              </div>
              <h3>{item.userName}</h3>
              <p className="review-subtitle">{tierLabel(item.tier)}</p>
              <p style={{ marginTop: 8, fontSize: '0.9rem' }}>{item.message}</p>
            </div>
          ))}
        </div>
      )}

      {modal && (
        <div className="modal-overlay" onClick={() => setModal(null)}>
          <div className="modal card" onClick={e => e.stopPropagation()}>
            <h2>{modal.userName}</h2>
            <p className="review-subtitle">{tierLabel(modal.tier)}</p>
            <p style={{ margin: '12px 0' }}>{modal.message}</p>
            <div className="form-group">
              <label>Admin Note (optional)</label>
              <textarea className="input" rows={3} value={note} onChange={e => setNote(e.target.value)} />
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button className="btn btn-primary" disabled={saving} onClick={() => handleAction('fulfilled')}>
                ✅ Mark Fulfilled
              </button>
              <button className="btn btn-ghost" disabled={saving} onClick={() => handleAction('rejected')}>
                ❌ Reject
              </button>
              <button className="btn btn-ghost" onClick={() => setModal(null)}>Cancel</button>
            </div>
          </div>
        </div>
      )}

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

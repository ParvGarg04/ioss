import React, { useState, useEffect } from 'react';
import { sendEmergencyAlert, fetchAllMembers } from '../hooks/useFirestore';
import { UserProfile } from '../types';

type TargetMode = 'all' | 'specific';

export default function EmergencyPage() {
  const [title, setTitle]       = useState('');
  const [message, setMessage]   = useState('');
  const [saving, setSaving]     = useState(false);
  const [toast, setToast]       = useState('');
  const [error, setError]       = useState('');
  const [targetMode, setTargetMode] = useState<TargetMode>('all');
  const [members, setMembers]   = useState<UserProfile[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [loadingMembers, setLoadingMembers] = useState(false);
  const [search, setSearch]     = useState('');

  useEffect(() => {
    setLoadingMembers(true);
    fetchAllMembers()
      .then(setMembers)
      .catch(() => {})
      .finally(() => setLoadingMembers(false));
  }, []);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(''), 3500);
  };

  const toggleMember = (id: string) => {
    setSelectedIds(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  const selectAll = () => {
    const filtered = filteredMembers.map(m => m.id!).filter(Boolean);
    setSelectedIds(new Set(filtered));
  };

  const clearAll = () => setSelectedIds(new Set());

  const filteredMembers = members.filter(m =>
    m.name.toLowerCase().includes(search.toLowerCase()) ||
    m.email.toLowerCase().includes(search.toLowerCase())
  );

  const handleSend = async () => {
    if (!title.trim() || !message.trim()) {
      setError('Title and message are required.');
      return;
    }
    if (targetMode === 'specific' && selectedIds.size === 0) {
      setError('Please select at least one member.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      if (targetMode === 'all') {
        await sendEmergencyAlert(title.trim(), message.trim());
        showToast('🚨 Emergency alert sent to all members!');
      } else {
        // Send individual alerts per user (targetUserId field)
        await sendEmergencyAlert(title.trim(), message.trim(), Array.from(selectedIds));
        showToast(`🚨 Alert sent to ${selectedIds.size} member${selectedIds.size !== 1 ? 's' : ''}!`);
      }
      setTitle('');
      setMessage('');
      setSelectedIds(new Set());
    } catch (e: any) {
      setError('Failed to send alert: ' + e.message);
    } finally {
      setSaving(false);
    }
  };

  const initials = (name: string) =>
    name.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase();

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Emergency Alert</h1>
          <p className="page-subtitle">Send an instant notification to members</p>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card" style={{ maxWidth: 620 }}>
        {/* Target selector */}
        <div className="form-group">
          <label>Send To</label>
          <div style={{ display: 'flex', gap: 10 }}>
            <button
              onClick={() => setTargetMode('all')}
              style={{
                flex: 1,
                padding: '10px 0',
                borderRadius: 10,
                border: `2px solid ${targetMode === 'all' ? '#dc2626' : 'var(--border)'}`,
                background: targetMode === 'all' ? '#fef2f2' : 'var(--card-bg)',
                color: targetMode === 'all' ? '#dc2626' : 'var(--text-secondary)',
                fontWeight: 600,
                cursor: 'pointer',
                fontSize: '0.9rem',
              }}
            >
              🌐 All Members
            </button>
            <button
              onClick={() => setTargetMode('specific')}
              style={{
                flex: 1,
                padding: '10px 0',
                borderRadius: 10,
                border: `2px solid ${targetMode === 'specific' ? '#dc2626' : 'var(--border)'}`,
                background: targetMode === 'specific' ? '#fef2f2' : 'var(--card-bg)',
                color: targetMode === 'specific' ? '#dc2626' : 'var(--text-secondary)',
                fontWeight: 600,
                cursor: 'pointer',
                fontSize: '0.9rem',
              }}
            >
              👤 Specific Members
            </button>
          </div>
        </div>

        {/* Member picker */}
        {targetMode === 'specific' && (
          <div className="form-group">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <label style={{ marginBottom: 0 }}>Select Members</label>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  className="btn btn-outline"
                  style={{ padding: '4px 10px', fontSize: '0.78rem' }}
                  onClick={selectAll}
                >
                  Select All
                </button>
                <button
                  className="btn btn-outline"
                  style={{ padding: '4px 10px', fontSize: '0.78rem' }}
                  onClick={clearAll}
                >
                  Clear
                </button>
              </div>
            </div>

            <input
              className="input"
              placeholder="Search members…"
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{ marginBottom: 10 }}
            />

            {loadingMembers ? (
              <div style={{ textAlign: 'center', padding: 20 }}>
                <div className="spinner" style={{ margin: '0 auto' }} />
              </div>
            ) : (
              <div style={{
                maxHeight: 260,
                overflowY: 'auto',
                border: '1px solid var(--border)',
                borderRadius: 10,
                display: 'flex',
                flexDirection: 'column',
                gap: 1,
              }}>
                {filteredMembers.length === 0 ? (
                  <div style={{ padding: 16, textAlign: 'center', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                    No members found
                  </div>
                ) : filteredMembers.map(m => {
                  const id = m.id!;
                  const checked = selectedIds.has(id);
                  return (
                    <label
                      key={id}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 12,
                        padding: '10px 14px',
                        cursor: 'pointer',
                        background: checked ? '#fef2f2' : 'var(--card-bg)',
                        transition: 'background 0.15s',
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={() => toggleMember(id)}
                        style={{ accentColor: '#dc2626', width: 16, height: 16 }}
                      />
                      <div style={{
                        width: 34, height: 34, borderRadius: '50%',
                        background: checked ? '#dc2626' : 'var(--accent, #e879a0)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        color: '#fff', fontWeight: 700, fontSize: '0.75rem', flexShrink: 0,
                      }}>
                        {initials(m.name)}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: 600, fontSize: '0.88rem', color: 'var(--text-primary)' }}>{m.name}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.email}</div>
                      </div>
                      {checked && <span style={{ color: '#dc2626', fontSize: '0.8rem', fontWeight: 600 }}>✓</span>}
                    </label>
                  );
                })}
              </div>
            )}

            {selectedIds.size > 0 && (
              <p style={{ fontSize: '0.82rem', color: '#dc2626', marginTop: 8, fontWeight: 600 }}>
                {selectedIds.size} member{selectedIds.size !== 1 ? 's' : ''} selected
              </p>
            )}
          </div>
        )}

        <div className="form-group">
          <label>Alert Title</label>
          <input
            className="input"
            placeholder="e.g. Urgent Action Required"
            value={title}
            onChange={e => setTitle(e.target.value)}
          />
        </div>

        <div className="form-group">
          <label>Message</label>
          <textarea
            className="input"
            rows={4}
            placeholder="Describe what members need to do immediately…"
            value={message}
            onChange={e => setMessage(e.target.value)}
          />
        </div>

        <p style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', marginBottom: 16 }}>
          {targetMode === 'all'
            ? 'All app members will receive an instant critical notification. Use for urgent situations only.'
            : 'Selected members will receive a critical push notification immediately.'}
        </p>

        <button
          className="btn btn-primary"
          style={{ background: '#dc2626', borderColor: '#dc2626', width: '100%', padding: '12px 0', fontSize: '1rem' }}
          disabled={saving}
          onClick={handleSend}
        >
          {saving
            ? 'Sending…'
            : targetMode === 'all'
              ? '🚨 Send to All Members'
              : `🚨 Send to ${selectedIds.size || '?'} Member${selectedIds.size !== 1 ? 's' : ''}`}
        </button>
      </div>

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

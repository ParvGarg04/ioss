import React, { useState } from 'react';
import { sendEmergencyAlert } from '../hooks/useFirestore';

export default function EmergencyPage() {
  const [title, setTitle]   = useState('');
  const [message, setMessage] = useState('');
  const [saving, setSaving] = useState(false);
  const [toast, setToast]   = useState('');
  const [error, setError]   = useState('');

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(''), 3500);
  };

  const handleSend = async () => {
    if (!title.trim() || !message.trim()) {
      setError('Title and message are required.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      await sendEmergencyAlert(title.trim(), message.trim());
      setTitle('');
      setMessage('');
      showToast('🚨 Emergency alert sent to all members!');
    } catch (e: any) {
      setError('Failed to send alert: ' + e.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>Emergency Alert</h1>
          <p className="page-subtitle">Send an instant notification to all app members</p>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card" style={{ maxWidth: 560 }}>
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
            rows={5}
            placeholder="Describe what members need to do immediately…"
            value={message}
            onChange={e => setMessage(e.target.value)}
          />
        </div>

        <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: 16 }}>
          Members with the app open will receive an instant notification with sound.
          Use for urgent, time-sensitive instructions only.
        </p>

        <button
          className="btn btn-primary"
          style={{ background: '#dc2626', borderColor: '#dc2626' }}
          disabled={saving}
          onClick={handleSend}
        >
          {saving ? 'Sending…' : '🚨 Send Emergency Alert'}
        </button>
      </div>

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

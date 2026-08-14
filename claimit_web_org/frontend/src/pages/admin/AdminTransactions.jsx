import { useEffect, useState } from 'react'
import api from '../../utils/api'

// ─────────────────────────────────────────────────────────────────────────────
// Admin → Transactions: every shop-registration payment with full shop + user
// + payment details (read-only list).
// ─────────────────────────────────────────────────────────────────────────────

const th = { textAlign: 'left', padding: '10px 12px', fontSize: 12, fontWeight: 700, color: '#374151', borderBottom: '2px solid #e5e7eb', whiteSpace: 'nowrap' }
const td = { padding: '10px 12px', fontSize: 13, color: '#111827', borderBottom: '1px solid #f1f5f9', verticalAlign: 'top' }

const money = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`
const fmtDate = (s) => (s ? new Date(s).toLocaleString('en-IN') : '—')

const statusPill = (st) => {
  const paid = st === 'paid'
  return (
    <span style={{
      fontSize: 11, fontWeight: 700, padding: '3px 8px', borderRadius: 20,
      background: paid ? '#e8f5e9' : '#fff8e1',
      color: paid ? '#2e7d32' : '#8a6d00',
    }}>{paid ? 'PAID' : 'FREE'}</span>
  )
}

export default function AdminTransactions() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [q, setQ] = useState('')

  useEffect(() => {
    api.admin.listTransactions()
      .then(setRows)
      .catch(e => setError(e?.response?.data?.detail || 'Could not load transactions'))
      .finally(() => setLoading(false))
  }, [])

  const filtered = rows.filter(r => {
    if (!q.trim()) return true
    const s = q.toLowerCase()
    return [r.shop_name, r?.user?.name, r?.user?.email, r?.user?.phone,
            r.plan, r.razorpay_payment_id]
      .some(v => (v || '').toString().toLowerCase().includes(s))
  })

  const totalPaid = rows.reduce((sum, r) => sum + (r.payment_status === 'paid' ? Number(r.amount || 0) : 0), 0)

  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12, marginBottom: 16 }}>
        <h2 style={{ fontSize: 22, fontWeight: 800, margin: 0 }}>Transactions</h2>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <span style={{ fontSize: 13, color: '#374151' }}>
            {rows.length} total · collected <b>{money(totalPaid)}</b>
          </span>
          <input
            placeholder="Search shop / user / payment id"
            value={q}
            onChange={e => setQ(e.target.value)}
            style={{ padding: '8px 12px', border: '1px solid #d1d5db', borderRadius: 8, fontSize: 13, width: 260, fontFamily: 'inherit' }}
          />
        </div>
      </div>

      {error && <div style={{ background: '#fdecea', color: '#b71c1c', padding: '10px 14px', borderRadius: 8, marginBottom: 12 }}>{error}</div>}
      {loading ? (
        <div style={{ color: '#6b7280' }}>Loading…</div>
      ) : filtered.length === 0 ? (
        <div style={{ color: '#6b7280' }}>No transactions yet.</div>
      ) : (
        <div style={{ overflowX: 'auto', background: '#fff', borderRadius: 12, border: '1px solid #eee' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 900 }}>
            <thead>
              <tr>
                <th style={th}>Date</th>
                <th style={th}>Shop</th>
                <th style={th}>Category / Type</th>
                <th style={th}>Owner</th>
                <th style={th}>Contact</th>
                <th style={th}>Plan</th>
                <th style={th}>Amount</th>
                <th style={th}>Status</th>
                <th style={th}>Payment ID</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(r => (
                <tr key={r.id}>
                  <td style={td}>{fmtDate(r.created_at)}</td>
                  <td style={td}>
                    <div style={{ fontWeight: 700 }}>{r.shop_name || '—'}</div>
                    <div style={{ fontSize: 11, color: '#6b7280' }}>{r?.shop?.location || ''}</div>
                  </td>
                  <td style={td}>
                    <div>{r?.shop?.category || '—'}</div>
                    <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'capitalize' }}>{r?.shop?.shop_type || ''}</div>
                  </td>
                  <td style={td}>{r?.user?.name || '—'}</td>
                  <td style={td}>
                    <div>{r?.user?.email || '—'}</div>
                    <div style={{ fontSize: 11, color: '#6b7280' }}>{r?.user?.phone || ''}</div>
                  </td>
                  <td style={{ ...td, textTransform: 'capitalize' }}>{r.plan || '—'}</td>
                  <td style={{ ...td, fontWeight: 700 }}>{money(r.amount)}</td>
                  <td style={td}>{statusPill(r.payment_status)}</td>
                  <td style={{ ...td, fontSize: 11, color: '#6b7280' }}>{r.razorpay_payment_id || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

import { useEffect, useState } from 'react'
import api from '../../utils/api'

// ─── Reusable shell ──────────────────────────────────────────
function PageShell({ title, subtitle, children }) {
  return (
    <div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>{title}</h1>
      {subtitle && <p style={{ color: '#666', fontSize: 13, marginBottom: 22 }}>{subtitle}</p>}
      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e0e0e0', overflow: 'hidden' }}>
        {children}
      </div>
    </div>
  )
}

const th = { padding: '12px 16px', textAlign: 'left', fontSize: 12, color: '#666', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, background: '#f8f9fa' }
const td = { padding: '14px 16px', fontSize: 13, borderBottom: '1px solid #f5f5f5' }

const dangerBtn = {
  background: '#fff', border: '1px solid #e57373', color: '#c62828',
  padding: '6px 10px', borderRadius: 6, fontSize: 12, cursor: 'pointer',
  fontFamily: 'Poppins',
}
const ghostBtn = {
  background: '#fff', border: '1px solid #ccc', color: '#333',
  padding: '6px 10px', borderRadius: 6, fontSize: 12, cursor: 'pointer',
  fontFamily: 'Poppins',
}

const empty = (icon, msg) => (
  <div style={{ padding: 60, textAlign: 'center', color: '#999' }}>
    <div style={{ fontSize: 40, marginBottom: 8 }}>{icon}</div>
    <div style={{ fontSize: 14 }}>{msg}</div>
  </div>
)

// ─── Users ───────────────────────────────────────────────────
export function AdminUsers() {
  const [filter, setFilter] = useState('all')
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)

  const load = (role) => {
    setLoading(true)
    api.admin.listUsers(role).then(setUsers).finally(() => setLoading(false))
  }
  useEffect(() => { load(filter) }, [filter])

  const remove = async (id) => {
    if (!confirm('Delete user and ALL their data? This cannot be undone.')) return
    await api.admin.deleteUser(id)
    load(filter)
  }

  return (
    <PageShell title="Users" subtitle="Everyone registered across the 3 portals.">
      <div style={{ display: 'flex', gap: 8, padding: 16, borderBottom: '1px solid #f0f0f0' }}>
        {['all', 'advertiser', 'sales', 'shop'].map(f => (
          <button key={f}
            onClick={() => setFilter(f)}
            style={{
              padding: '6px 14px', border: '1px solid #ddd', borderRadius: 6,
              background: filter === f ? '#1a237e' : '#fff',
              color: filter === f ? '#fff' : '#333',
              fontSize: 12, cursor: 'pointer', fontFamily: 'Poppins', textTransform: 'capitalize',
            }}>{f}</button>
        ))}
      </div>
      {loading ? <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading…</div>
       : users.length === 0 ? empty('👥', 'No users found')
       : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr>
            <th style={th}>Name</th><th style={th}>Phone</th><th style={th}>Email</th>
            <th style={th}>Role</th><th style={th}>Joined</th><th style={th}></th>
          </tr></thead>
          <tbody>
            {users.map(u => (
              <tr key={u.id}>
                <td style={td}><strong>{u.name}</strong></td>
                <td style={td}>{u.phone}</td>
                <td style={td}>{u.email}</td>
                <td style={td}><span style={{ background:'#eee', padding:'2px 8px', borderRadius:4, fontSize:11 }}>{u.role}</span></td>
                <td style={td}>{u.created_at?.slice(0,10)}</td>
                <td style={td}><button style={dangerBtn} onClick={() => remove(u.id)}>Delete</button></td>
              </tr>
            ))}
          </tbody>
        </table>
       )}
    </PageShell>
  )
}

// ─── Ads ─────────────────────────────────────────────────────
export function AdminAds() {
  const [ads, setAds] = useState([]); const [loading, setLoading] = useState(true)
  const load = () => { setLoading(true); api.admin.listAds().then(setAds).finally(() => setLoading(false)) }
  useEffect(() => { load() }, [])

  const setStatus = async (id, status) => { await api.admin.updateAd(id, { status }); load() }
  const remove = async (id) => { if (confirm('Delete this ad?')) { await api.admin.deleteAd(id); load() } }

  return (
    <PageShell title="Ads" subtitle="Every ad created across all advertisers.">
      {loading ? <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading…</div>
       : ads.length === 0 ? empty('📢', 'No ads yet')
       : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr>
            <th style={th}>Title</th><th style={th}>Type</th><th style={th}>Pincode</th>
            <th style={th}>Publish</th><th style={th}>Amount</th><th style={th}>Status</th><th style={th}></th>
          </tr></thead>
          <tbody>
            {ads.map(a => (
              <tr key={a.id}>
                <td style={td}><strong>{a.title}</strong></td>
                <td style={td}>{a.ad_type}</td>
                <td style={td}>{a.pincode}</td>
                <td style={td}>{a.publish_date}</td>
                <td style={td}>₹{a.amount}</td>
                <td style={td}>
                  <select value={a.status} onChange={e => setStatus(a.id, e.target.value)}
                    style={{ padding: '4px 8px', borderRadius: 4, border: '1px solid #ccc', fontSize: 12 }}>
                    <option value="active">active</option>
                    <option value="scheduled">scheduled</option>
                    <option value="paused">paused</option>
                  </select>
                </td>
                <td style={td}><button style={dangerBtn} onClick={() => remove(a.id)}>Delete</button></td>
              </tr>
            ))}
          </tbody>
        </table>
       )}
    </PageShell>
  )
}

// ─── Shops ───────────────────────────────────────────────────
export function AdminShops() {
  const [shops, setShops] = useState([]); const [loading, setLoading] = useState(true)
  const load = () => { setLoading(true); api.admin.listShops().then(setShops).finally(() => setLoading(false)) }
  useEffect(() => { load() }, [])

  const setStatus = async (id, status) => { await api.admin.updateShop(id, { status }); load() }
  const remove = async (id) => { if (confirm('Delete this shop?')) { await api.admin.deleteShop(id); load() } }

  return (
    <PageShell title="Shops" subtitle="Registered shops and their approval state.">
      {loading ? <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading…</div>
       : shops.length === 0 ? empty('🏪', 'No shops yet')
       : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr>
            <th style={th}>Shop</th><th style={th}>Address</th><th style={th}>Category</th>
            <th style={th}>Discount</th><th style={th}>Status</th><th style={th}></th>
          </tr></thead>
          <tbody>
            {shops.map(s => (
              <tr key={s.id}>
                <td style={td}><strong>{s.shop_name}</strong></td>
                <td style={td}>{s.shop_address}</td>
                <td style={td}>{s.category}</td>
                <td style={td}>{s.discount_percentage ?? 0}%</td>
                <td style={td}>
                  <select value={s.status || 'pending'} onChange={e => setStatus(s.id, e.target.value)}
                    style={{ padding: '4px 8px', borderRadius: 4, border: '1px solid #ccc', fontSize: 12 }}>
                    <option value="pending">pending</option>
                    <option value="active">active</option>
                    <option value="suspended">suspended</option>
                  </select>
                </td>
                <td style={td}><button style={dangerBtn} onClick={() => remove(s.id)}>Delete</button></td>
              </tr>
            ))}
          </tbody>
        </table>
       )}
    </PageShell>
  )
}

// ─── Reviews ─────────────────────────────────────────────────
export function AdminReviews() {
  const [reviews, setReviews] = useState([]); const [loading, setLoading] = useState(true)
  const load = () => { setLoading(true); api.admin.listReviews().then(setReviews).finally(() => setLoading(false)) }
  useEffect(() => { load() }, [])

  const remove = async (id) => { if (confirm('Delete this review?')) { await api.admin.deleteReview(id); load() } }

  return (
    <PageShell title="Reviews" subtitle="Customer reviews left on shops.">
      {loading ? <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading…</div>
       : reviews.length === 0 ? empty('⭐', 'No reviews yet')
       : (
        <div>
          {reviews.map(r => (
            <div key={r.id} style={{ borderBottom: '1px solid #f0f0f0', padding: '14px 18px', display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:16 }}>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 4 }}>
                  <strong style={{ fontSize: 14 }}>{r.name}</strong>
                  <span style={{ color: '#F5A623' }}>{'★'.repeat(r.rating)}{'☆'.repeat(5 - r.rating)}</span>
                  <span style={{ fontSize: 11, color: '#888' }}>{r.date}</span>
                </div>
                <div style={{ fontSize: 13, color: '#444' }}>{r.comment}</div>
                {r.reply && <div style={{ fontSize: 12, color: '#1a237e', marginTop: 4 }}>↳ Owner: {r.reply}</div>}
              </div>
              <button style={dangerBtn} onClick={() => remove(r.id)}>Delete</button>
            </div>
          ))}
        </div>
       )}
    </PageShell>
  )
}

// ─── Tickets ─────────────────────────────────────────────────
export function AdminTickets() {
  const [tickets, setTickets] = useState([]); const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState({})

  const load = () => { setLoading(true); api.admin.listTickets().then(setTickets).finally(() => setLoading(false)) }
  useEffect(() => { load() }, [])

  const setStatus = async (id, status) => { await api.admin.updateTicket(id, { status }); load() }
  const sendReply = async (id) => {
    const reply = (editing[id] || '').trim()
    if (!reply) return
    await api.admin.updateTicket(id, { reply, status: 'resolved' })
    setEditing(prev => { const n = {...prev}; delete n[id]; return n })
    load()
  }

  return (
    <PageShell title="Support Tickets" subtitle="User-submitted support requests.">
      {loading ? <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading…</div>
       : tickets.length === 0 ? empty('🎫', 'No tickets yet')
       : (
        <div>
          {tickets.map(t => (
            <div key={t.id} style={{ borderBottom: '1px solid #f0f0f0', padding: 18 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <div style={{ fontWeight: 600, fontSize: 14 }}>{t.subject}</div>
                  <div style={{ fontSize: 12, color: '#777', marginTop: 2 }}>
                    {t.user_name} ({t.role}) · {t.user_email} · {t.user_phone}
                  </div>
                  <div style={{ fontSize: 12, color: '#999' }}>{String(t.created_at).slice(0, 16)} · {t.category}</div>
                </div>
                <select value={t.status || 'open'} onChange={e => setStatus(t.id, e.target.value)}
                  style={{ padding: '4px 8px', borderRadius: 4, border: '1px solid #ccc', fontSize: 12 }}>
                  <option value="open">open</option>
                  <option value="resolved">resolved</option>
                  <option value="closed">closed</option>
                </select>
              </div>
              <div style={{ fontSize: 13, marginTop: 10, color: '#333' }}>{t.message}</div>
              {t.reply && (
                <div style={{ fontSize: 12, color: '#1a237e', marginTop: 8, background: '#f4f6ff', padding: 8, borderRadius: 6 }}>
                  ↳ Admin reply: {t.reply}
                </div>
              )}
              <div style={{ marginTop: 10, display: 'flex', gap: 8 }}>
                <input
                  className="input-field" placeholder="Reply to user..."
                  style={{ fontSize: 13, padding: '8px 12px' }}
                  value={editing[t.id] || ''}
                  onChange={e => setEditing(prev => ({ ...prev, [t.id]: e.target.value }))}
                />
                <button style={ghostBtn} onClick={() => sendReply(t.id)}>Send Reply</button>
              </div>
            </div>
          ))}
        </div>
       )}
    </PageShell>
  )
}

// ─── PDFs viewer ─────────────────────────────────────────────
export function AdminPDFs() {
  const labels = {
    shop: 'Shop Registration flow',
    sales: 'Sales / Affiliate flow',
    advertiser: 'Create Ad flow',
  }
  const [pdfs, setPdfs] = useState([])
  const [active, setActive] = useState(null)
  const [blobUrl, setBlobUrl] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  // Load list once
  useEffect(() => {
    api.admin.listPdfs().then(list => {
      setPdfs(list)
      const first = list.find(p => p.exists) || list[0]
      if (first) setActive(first.key)
    }).catch(() => setError('Could not list project PDFs'))
  }, [])

  // Fetch the active PDF as a blob (the JWT goes via the axios interceptor)
  useEffect(() => {
    if (!active) return
    let url = ''
    setLoading(true); setError('')
    api.admin.getPdfBlob(active)
      .then(blob => {
        url = URL.createObjectURL(blob)
        setBlobUrl(url)
      })
      .catch(() => setError('Could not load PDF — check the file exists in the project root.'))
      .finally(() => setLoading(false))
    // Revoke the previous blob URL when switching tabs / unmounting.
    return () => { if (url) URL.revokeObjectURL(url) }
  }, [active])

  return (
    <PageShell title="Project PDFs" subtitle="Original design specifications uploaded with the project.">
      <div style={{ display: 'flex', gap: 8, padding: 16, borderBottom: '1px solid #f0f0f0', flexWrap: 'wrap' }}>
        {pdfs.length === 0 && <div style={{ color: '#888', fontSize: 13 }}>No PDFs available</div>}
        {pdfs.map(p => (
          <button key={p.key}
            onClick={() => setActive(p.key)}
            disabled={!p.exists}
            style={{
              padding: '8px 14px', border: '1px solid #ddd', borderRadius: 6,
              background: active === p.key ? '#1a237e' : '#fff',
              color: active === p.key ? '#fff' : (p.exists ? '#333' : '#bbb'),
              fontSize: 12, cursor: p.exists ? 'pointer' : 'not-allowed',
              fontFamily: 'Poppins',
            }}>
            {labels[p.key] || p.filename}{!p.exists && ' (missing)'}
          </button>
        ))}
        {blobUrl && (
          <a href={blobUrl} target="_blank" rel="noreferrer"
            style={{ marginLeft: 'auto', alignSelf: 'center', color: '#1a237e', fontSize: 12, fontWeight: 600 }}>
            Open in new tab ↗
          </a>
        )}
      </div>
      {error && <div style={{ padding: 16, color: '#c62828', fontSize: 13 }}>{error}</div>}
      {loading && <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading PDF…</div>}
      {!loading && blobUrl && (
        <iframe key={blobUrl} src={blobUrl}
          style={{ width: '100%', height: 'calc(100vh - 220px)', border: 'none' }}
          title="Project PDF"
        />
      )}
    </PageShell>
  )
}

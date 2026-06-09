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

// ─── Sales Team ──────────────────────────────────────────────
const SUB_ROLE_LABEL = {
  sales_head:             'Sales Head',
  sales_executive:        'Sales Executive',
  advertising_executive:  'Advertising Executive',
  freelancer:             'Freelancer',
}
const SUB_ROLE_COLOR = {
  sales_head:             { bg: '#FFF8E1', color: '#F57F17' },
  sales_executive:        { bg: '#E8F5E9', color: '#2E7D32' },
  advertising_executive:  { bg: '#E3F2FD', color: '#1565C0' },
  freelancer:             { bg: '#F3E5F5', color: '#6A1B9A' },
}

export function AdminSalesTeam() {
  const [employees, setEmployees] = useState([])
  const [loading, setLoading]   = useState(true)
  const [filter, setFilter]     = useState('all')
  const [search, setSearch]     = useState('')

  useEffect(() => {
    api.sales.getAllEmployees()
      .then(setEmployees)
      .catch(() => setEmployees([]))
      .finally(() => setLoading(false))
  }, [])

  const filtered = employees.filter(e => {
    if (filter !== 'all' && e.sub_role !== filter) return false
    if (search) {
      const q = search.toLowerCase()
      return e.name.toLowerCase().includes(q) ||
        e.unique_id?.toLowerCase().includes(q) ||
        e.phone?.includes(q) ||
        e.email?.toLowerCase().includes(q)
    }
    return true
  })

  const counts = {
    all: employees.length,
    sales_head: employees.filter(e => e.sub_role === 'sales_head').length,
    sales_executive: employees.filter(e => e.sub_role === 'sales_executive').length,
    advertising_executive: employees.filter(e => e.sub_role === 'advertising_executive').length,
    freelancer: employees.filter(e => e.sub_role === 'freelancer').length,
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>Sales Team</h1>
          <p style={{ color: '#666', fontSize: 13 }}>All registered sales employees with their unique IDs</p>
        </div>
        <div style={{ background: '#1565C0', color: '#fff', borderRadius: 10, padding: '10px 18px', textAlign: 'center' }}>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{employees.length}</div>
          <div style={{ fontSize: 11, opacity: 0.85 }}>Total Employees</div>
        </div>
      </div>

      {/* Summary cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 20 }}>
        {[
          { key: 'sales_head',             label: 'Sales Heads' },
          { key: 'sales_executive',        label: 'Sales Executives' },
          { key: 'advertising_executive',  label: 'Ad Executives' },
          { key: 'freelancer',             label: 'Freelancers' },
        ].map(r => {
          const c = SUB_ROLE_COLOR[r.key] || { bg: '#f5f5f5', color: '#333' }
          return (
            <div key={r.key}
              onClick={() => setFilter(filter === r.key ? 'all' : r.key)}
              style={{
                background: filter === r.key ? c.bg : '#fff',
                border: `1.5px solid ${filter === r.key ? c.color : '#eee'}`,
                borderRadius: 10, padding: '14px 16px', cursor: 'pointer',
                transition: 'all 0.15s'
              }}>
              <div style={{ fontSize: 22, fontWeight: 700, color: c.color }}>{counts[r.key]}</div>
              <div style={{ fontSize: 12, color: '#666', marginTop: 2 }}>{r.label}</div>
            </div>
          )
        })}
      </div>

      {/* Search + table */}
      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e0e0e0', overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid #f0f0f0', display: 'flex', gap: 12, alignItems: 'center' }}>
          <input
            placeholder="Search by name, ID, phone or email…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{
              flex: 1, padding: '9px 14px', border: '1px solid #ddd',
              borderRadius: 8, fontSize: 13, fontFamily: 'Poppins', outline: 'none'
            }}
          />
          {filter !== 'all' && (
            <button onClick={() => setFilter('all')}
              style={{ ...ghostBtn, fontSize: 12 }}>Clear filter ✕</button>
          )}
        </div>

        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
        ) : filtered.length === 0 ? (
          <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
            <div style={{ fontSize: 40, marginBottom: 10 }}>👥</div>
            <div style={{ fontWeight: 500 }}>No employees found</div>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                {['Employee', 'Unique ID', 'Role', 'Phone', 'Referred By (Head ID)', 'Shops', 'Joined'].map(h => (
                  <th key={h} style={th}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((e, i) => {
                const c = SUB_ROLE_COLOR[e.sub_role] || { bg: '#f5f5f5', color: '#555' }
                return (
                  <tr key={e.id || i} style={{ background: i % 2 === 0 ? '#fff' : '#fafafa' }}>
                    <td style={td}>
                      <div style={{ fontWeight: 600 }}>{e.name}</div>
                      <div style={{ fontSize: 11, color: '#888', marginTop: 2 }}>{e.email}</div>
                    </td>
                    <td style={td}>
                      <span style={{
                        background: '#EEF4FF', color: '#1565C0',
                        fontWeight: 700, fontSize: 13, padding: '4px 10px',
                        borderRadius: 6, fontFamily: 'monospace', letterSpacing: 0.5
                      }}>
                        {e.unique_id || '—'}
                      </span>
                    </td>
                    <td style={td}>
                      <span style={{
                        background: c.bg, color: c.color,
                        fontSize: 11, fontWeight: 600, padding: '3px 8px', borderRadius: 20
                      }}>
                        {SUB_ROLE_LABEL[e.sub_role] || e.sub_role || '—'}
                      </span>
                    </td>
                    <td style={{ ...td, fontFamily: 'monospace' }}>{e.phone || '—'}</td>
                    <td style={{ ...td, fontFamily: 'monospace', color: '#1565C0', fontWeight: 600 }}>
                      {e.referred_by || <span style={{ color: '#ccc', fontFamily: 'Poppins', fontWeight: 400 }}>—</span>}
                    </td>
                    <td style={td}>
                      <span style={{ background: '#E8F5E9', color: '#2E7D32', fontSize: 12, fontWeight: 600, padding: '3px 8px', borderRadius: 6 }}>
                        {e.total_shops}
                      </span>
                    </td>
                    <td style={{ ...td, color: '#888' }}>{e.created_at?.slice(0, 10) || '—'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

// ─── Bill Reviews ─────────────────────────────────────────────
// ─── Bill Reviews ─────────────────────────────────────────────
export function AdminBillReviews() {
  const [reviews, setReviews]   = useState([])
  const [loading, setLoading]   = useState(true)
  const [filter, setFilter]     = useState('pending')
  const [selected, setSelected] = useState(null)
  const [pts, setPts]           = useState('')
  const [cb, setCb]             = useState('')
  const [note, setNote]         = useState('')
  const [actioning, setActioning] = useState(false)

  const load = (status = filter) => {
    setLoading(true)
    api.admin.listBillReviews(status)
      .then(data => setReviews(Array.isArray(data) ? data : []))
      .catch(() => setReviews([]))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [filter])

  const handleAction = async (action) => {
    if (!selected) return
    setActioning(true)
    try {
      await api.admin.actionBillReview(selected.id, {
        action,
        reward_points: pts ? parseInt(pts) : undefined,
        cashback:      cb  ? parseFloat(cb) : undefined,
        admin_note:    note || undefined,
      })
      setSelected(null); setPts(''); setCb(''); setNote('')
      load()
    } catch (e) {
      alert(e?.response?.data?.detail || 'Action failed')
    } finally { setActioning(false) }
  }

  const REASON_LABEL = { missing_fields: 'Missing fields', wrong_data: 'Wrong OCR data' }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>Bill Reviews</h1>
          <p style={{ color: '#666', fontSize: 13 }}>Manual bill submissions awaiting verification</p>
        </div>
      </div>

      {/* Filter tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {[
          { key: 'pending',  label: 'Pending',  color: '#F57C00' },
          { key: 'approved', label: 'Approved', color: '#2E7D32' },
          { key: 'rejected', label: 'Rejected', color: '#C62828' },
          { key: 'all',      label: 'All',      color: '#555' },
        ].map(t => (
          <button key={t.key} onClick={() => setFilter(t.key)}
            style={{
              padding: '8px 18px', borderRadius: 20, cursor: 'pointer', fontFamily: 'Poppins', fontSize: 13,
              fontWeight: filter === t.key ? 700 : 500,
              background: filter === t.key ? t.color : '#f5f5f5',
              color: filter === t.key ? '#fff' : '#555',
              border: `1.5px solid ${filter === t.key ? t.color : '#e0e0e0'}`,
            }}>{t.label}</button>
        ))}
      </div>

      {/* Reviews table */}
      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e0e0e0', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
        ) : reviews.length === 0 ? (
          <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
            <div style={{ fontSize: 40, marginBottom: 10 }}>🧾</div>
            <div style={{ fontWeight: 500 }}>No {filter} reviews</div>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                {['User ID', 'Shop', 'Amount', 'Reason', 'Date', 'Status', 'Actions'].map(h => (
                  <th key={h} style={th}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {reviews.map((r, i) => {
                const statusColor = r.status === 'approved' ? '#2E7D32' : r.status === 'rejected' ? '#C62828' : '#F57C00'
                const statusBg    = r.status === 'approved' ? '#E8F5E9' : r.status === 'rejected' ? '#FFEBEE' : '#FFF3E0'
                return (
                  <tr key={r.id || i} style={{ background: i % 2 === 0 ? '#fff' : '#fafafa' }}>
                    <td style={{ ...td, fontFamily: 'monospace', fontSize: 11 }}>{(r.user_id || '').slice(-8) || '—'}</td>
                    <td style={{ ...td, fontWeight: 600 }}>{r.shop_name || '—'}</td>
                    <td style={{ ...td, fontWeight: 700, color: '#1565C0' }}>₹{r.total_amount}</td>
                    <td style={td}>
                      <span style={{ background: '#EEF4FF', color: '#1565C0', fontSize: 11, padding: '2px 7px', borderRadius: 4, fontWeight: 600 }}>
                        {REASON_LABEL[r.manual_reason] || r.manual_reason}
                      </span>
                    </td>
                    <td style={{ ...td, color: '#888', fontSize: 12 }}>{(r.submitted_at || '').slice(0, 10)}</td>
                    <td style={td}>
                      <span style={{ background: statusBg, color: statusColor, fontSize: 11, padding: '3px 8px', borderRadius: 20, fontWeight: 700 }}>
                        {r.status}
                      </span>
                    </td>
                    <td style={td}>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button onClick={() => setSelected({ ...r, _viewOnly: true })} style={ghostBtn}>View Bill</button>
                        {r.status === 'pending' && (
                          <button onClick={() => { setSelected(r); setPts(Math.round(r.total_amount * 0.1).toString()); setCb((r.total_amount * 0.01).toFixed(2)) }}
                            style={{ ...ghostBtn, borderColor: '#4CAF50', color: '#2E7D32' }}>
                            Review
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal: view bill + approve/reject */}
      {selected && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#fff', borderRadius: 16, padding: 28, width: 560, maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 20px 60px rgba(0,0,0,0.3)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
              <h3 style={{ fontWeight: 700, fontSize: 18 }}>{selected._viewOnly ? 'Bill Image' : 'Review Bill'}</h3>
              <button onClick={() => { setSelected(null); setPts(''); setCb(''); setNote('') }}
                style={{ background: 'none', border: 'none', fontSize: 22, cursor: 'pointer', color: '#666' }}>✕</button>
            </div>

            {/* Bill details */}
            <div style={{ background: '#f8f9fa', borderRadius: 10, padding: 14, marginBottom: 16 }}>
              {[
                ['Shop', selected.shop_name || '—'],
                ['Amount', `₹${selected.total_amount}`],
                ['Bill Date', selected.bill_date || '—'],
                ['Bill Number', selected.bill_number || '—'],
                ['Reason', REASON_LABEL[selected.manual_reason] || selected.manual_reason],
                ['User ID', selected.user_id],
              ].map(([label, value]) => (
                <div key={label} style={{ display: 'flex', justifyContent: 'space-between', padding: '5px 0', borderBottom: '1px solid #eee' }}>
                  <span style={{ color: '#888', fontSize: 13 }}>{label}</span>
                  <span style={{ fontWeight: 600, fontSize: 13 }}>{value}</span>
                </div>
              ))}
            </div>

            {/* Bill image */}
            {selected.image_url && (
              <div style={{ marginBottom: 16 }}>
                <p style={{ fontSize: 12, color: '#888', marginBottom: 8, fontWeight: 600 }}>BILL IMAGE</p>
                <img
                  src={selected.image_url}
                  alt="Bill"
                  style={{ width: '100%', borderRadius: 10, border: '1px solid #e0e0e0' }}
                />
              </div>
            )}

            {/* Approve/reject form */}
            {!selected._viewOnly && selected.status === 'pending' && (
              <>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
                  <div>
                    <label style={{ fontSize: 12, fontWeight: 600, color: '#555', display: 'block', marginBottom: 4 }}>Reward Points</label>
                    <input value={pts} onChange={e => setPts(e.target.value)} type="number"
                      placeholder={`Default: ${Math.round(selected.total_amount * 0.1)}`}
                      style={{ width: '100%', padding: '8px 10px', border: '1px solid #ddd', borderRadius: 7, fontSize: 13, fontFamily: 'Poppins', boxSizing: 'border-box' }} />
                  </div>
                  <div>
                    <label style={{ fontSize: 12, fontWeight: 600, color: '#555', display: 'block', marginBottom: 4 }}>Cashback (₹)</label>
                    <input value={cb} onChange={e => setCb(e.target.value)} type="number" step="0.01"
                      placeholder={`Default: ${(selected.total_amount * 0.01).toFixed(2)}`}
                      style={{ width: '100%', padding: '8px 10px', border: '1px solid #ddd', borderRadius: 7, fontSize: 13, fontFamily: 'Poppins', boxSizing: 'border-box' }} />
                  </div>
                </div>
                <div style={{ marginBottom: 16 }}>
                  <label style={{ fontSize: 12, fontWeight: 600, color: '#555', display: 'block', marginBottom: 4 }}>Admin Note (optional)</label>
                  <textarea value={note} onChange={e => setNote(e.target.value)} rows={2}
                    placeholder="Reason for approval or rejection…"
                    style={{ width: '100%', padding: '8px 10px', border: '1px solid #ddd', borderRadius: 7, fontSize: 13, fontFamily: 'Poppins', resize: 'vertical', boxSizing: 'border-box' }} />
                </div>
                <div style={{ display: 'flex', gap: 10 }}>
                  <button onClick={() => handleAction('approve')} disabled={actioning}
                    style={{ flex: 1, padding: '12px', background: '#2E7D32', color: '#fff', border: 'none', borderRadius: 10, fontWeight: 700, fontSize: 14, cursor: 'pointer', fontFamily: 'Poppins', opacity: actioning ? 0.6 : 1 }}>
                    {actioning ? 'Processing…' : '✓ Approve & Add Rewards'}
                  </button>
                  <button onClick={() => handleAction('reject')} disabled={actioning}
                    style={{ flex: 1, padding: '12px', background: '#C62828', color: '#fff', border: 'none', borderRadius: 10, fontWeight: 700, fontSize: 14, cursor: 'pointer', fontFamily: 'Poppins', opacity: actioning ? 0.6 : 1 }}>
                    {actioning ? 'Processing…' : '✕ Reject'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}


// ─── Bonus Settings ───────────────────────────────────────────
export function AdminBonusSettings() {
  const [pts, setPts]       = useState('')
  const [cb, setCb]         = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving]   = useState(false)
  const [saved, setSaved]     = useState(false)
  const [error, setError]     = useState('')

  useEffect(() => {
    api.admin.getAppConfig()
      .then(cfg => {
        setPts(String(cfg.reward_points ?? 1000))
        setCb(String(cfg.cashback ?? 10))
      })
      .catch(() => { setPts('1000'); setCb('10') })
      .finally(() => setLoading(false))
  }, [])

  const handleSave = async () => {
    setError('')
    const p = parseInt(pts, 10)
    const c = parseFloat(cb)
    if (isNaN(p) || p < 0) { setError('Reward points must be a number ≥ 0'); return }
    if (isNaN(c) || c < 0) { setError('Cashback must be a number ≥ 0'); return }
    setSaving(true)
    try {
      await api.admin.updateAppConfig({ reward_points: p, cashback: c })
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (e) {
      setError(e?.response?.data?.detail || 'Failed to save. Please try again.')
    } finally { setSaving(false) }
  }

  const inputStyle = {
    width: '100%', padding: '10px 14px', border: '1.5px solid #ddd',
    borderRadius: 8, fontSize: 15, fontFamily: 'Poppins', outline: 'none',
    boxSizing: 'border-box', transition: 'border-color 0.15s',
  }

  return (
    <div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>New User Bonus Settings</h1>
      <p style={{ color: '#666', fontSize: 13, marginBottom: 28 }}>
        Configure the welcome reward every new user receives when they first scan a bill.
        Changes take effect immediately — new wallets created after saving will use the updated values.
      </p>

      {loading ? (
        <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading current settings…</div>
      ) : (
        <div style={{ maxWidth: 520 }}>
          {/* Current values card */}
          <div style={{
            background: 'linear-gradient(135deg, #1a237e 0%, #1565C0 100%)',
            borderRadius: 14, padding: 24, marginBottom: 28, color: '#fff',
          }}>
            <div style={{ fontSize: 13, opacity: 0.8, marginBottom: 12, fontWeight: 600, letterSpacing: 0.5 }}>
              CURRENT NEW USER WELCOME BONUS
            </div>
            <div style={{ display: 'flex', gap: 32 }}>
              <div>
                <div style={{ fontSize: 34, fontWeight: 800 }}>{pts}</div>
                <div style={{ fontSize: 12, opacity: 0.75, marginTop: 2 }}>Reward Points</div>
              </div>
              <div style={{ width: 1, background: 'rgba(255,255,255,0.25)' }} />
              <div>
                <div style={{ fontSize: 34, fontWeight: 800 }}>₹{parseFloat(cb || '0').toFixed(0)}</div>
                <div style={{ fontSize: 12, opacity: 0.75, marginTop: 2 }}>Cashback</div>
              </div>
            </div>
          </div>

          {/* Edit form */}
          <div style={{ background: '#fff', borderRadius: 14, border: '1px solid #e0e0e0', padding: 28 }}>
            <div style={{ marginBottom: 20 }}>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, color: '#333', marginBottom: 8 }}>
                Reward Points
              </label>
              <input
                type="number" min="0" step="1" value={pts}
                onChange={e => { setPts(e.target.value); setSaved(false) }}
                style={inputStyle}
                placeholder="e.g. 1000"
              />
              <p style={{ fontSize: 12, color: '#888', marginTop: 6 }}>
                Points credited to every new user's wallet on signup.
              </p>
            </div>

            <div style={{ marginBottom: 24 }}>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, color: '#333', marginBottom: 8 }}>
                Cashback (₹)
              </label>
              <input
                type="number" min="0" step="0.5" value={cb}
                onChange={e => { setCb(e.target.value); setSaved(false) }}
                style={inputStyle}
                placeholder="e.g. 10"
              />
              <p style={{ fontSize: 12, color: '#888', marginTop: 6 }}>
                Cashback (in rupees) added to every new user's cashback wallet on signup.
              </p>
            </div>

            {error && (
              <div style={{ background: '#FFEBEE', color: '#C62828', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 13 }}>
                {error}
              </div>
            )}

            {saved && (
              <div style={{ background: '#E8F5E9', color: '#2E7D32', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 13, fontWeight: 600 }}>
                ✓ Settings saved successfully!
              </div>
            )}

            <button
              onClick={handleSave}
              disabled={saving}
              style={{
                width: '100%', padding: '13px', background: saving ? '#90A4AE' : '#1a237e',
                color: '#fff', border: 'none', borderRadius: 10,
                fontWeight: 700, fontSize: 15, cursor: saving ? 'not-allowed' : 'pointer',
                fontFamily: 'Poppins', transition: 'background 0.15s',
              }}
            >
              {saving ? 'Saving…' : 'Save Settings'}
            </button>
          </div>

          {/* Info box */}
          <div style={{ background: '#FFF8E1', borderRadius: 10, padding: '14px 18px', marginTop: 20, border: '1px solid #FFE082' }}>
            <div style={{ fontSize: 13, color: '#5D4037', fontWeight: 600, marginBottom: 4 }}>ℹ️ How this works</div>
            <div style={{ fontSize: 12, color: '#6D4C41', lineHeight: 1.6 }}>
              When a new user scans their first bill, the app creates a wallet for them.
              The wallet starts with the reward points and cashback you set here.
              Existing users are not affected — only new wallets created after saving.
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

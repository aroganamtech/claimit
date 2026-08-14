import { useEffect, useState } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import api from '../../utils/api'

// ─────────────────────────────────────────────────────────────────────────────
// Admin → Shops → single shop landing page. Everything about one shop in one
// place: owner, address/location, category/type, plan & payment, photos,
// stats. Read-only except status (kept from the list page).
// ─────────────────────────────────────────────────────────────────────────────

const card = { background: '#fff', borderRadius: 12, border: '1px solid #e0e0e0', padding: 20, marginBottom: 18 }
const label = { fontSize: 11, fontWeight: 700, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }
const value = { fontSize: 14, color: '#222', marginBottom: 14 }
const grid = { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 4 }
const sectionTitle = { fontSize: 15, fontWeight: 700, marginBottom: 14, color: '#1a237e' }

const money = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`
const fmtDate = (s) => (s ? new Date(s).toLocaleString('en-IN') : '—')

const Field = ({ l, v }) => (
  <div>
    <div style={label}>{l}</div>
    <div style={value}>{v || v === 0 ? v : '—'}</div>
  </div>
)

const statusPill = (st) => {
  const color = st === 'active' ? '#2e7d32' : st === 'suspended' ? '#b71c1c' : '#8a6d00'
  const bg = st === 'active' ? '#e8f5e9' : st === 'suspended' ? '#fdecea' : '#fff8e1'
  return <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 10px', borderRadius: 20, background: bg, color, textTransform: 'uppercase' }}>{st || 'pending'}</span>
}

export default function AdminShopDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [shop, setShop] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = () => {
    setLoading(true)
    api.admin.getShop(id)
      .then(setShop)
      .catch(e => setError(e?.response?.data?.detail || 'Could not load this shop'))
      .finally(() => setLoading(false))
  }
  useEffect(() => { load() }, [id])

  const setStatus = async (status) => { await api.admin.updateShop(id, { status }); load() }
  const remove = async () => {
    if (!confirm('Delete this shop? This cannot be undone.')) return
    await api.admin.deleteShop(id)
    navigate('/admin/shops')
  }

  if (loading) return <div style={{ padding: 30, textAlign: 'center', color: '#888' }}>Loading…</div>
  if (error) return <div style={{ background: '#fdecea', color: '#b71c1c', padding: '10px 14px', borderRadius: 8 }}>{error}</div>
  if (!shop) return null

  const t = shop.transaction

  return (
    <div style={{ maxWidth: 980 }}>
      <Link to="/admin/shops" style={{ fontSize: 13, color: '#1a237e', textDecoration: 'none' }}>&larr; Back to Shops</Link>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 10, marginBottom: 20, flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0 }}>{shop.shop_name || 'Shop'}</h1>
          <div style={{ fontSize: 13, color: '#777', marginTop: 4 }}>{shop.category} · {shop.shop_type}</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          {statusPill(shop.status)}
          <select value={shop.status || 'pending'} onChange={e => setStatus(e.target.value)}
            style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid #ccc', fontSize: 12 }}>
            <option value="pending">pending</option>
            <option value="active">active</option>
            <option value="suspended">suspended</option>
          </select>
          <button onClick={remove} style={{ background: '#fff', border: '1px solid #e57373', color: '#c62828', padding: '7px 14px', borderRadius: 6, fontSize: 12, cursor: 'pointer', fontFamily: 'Poppins' }}>Delete shop</button>
        </div>
      </div>

      {(shop.image_url || (shop.image_urls || []).length > 0) && (
        <div style={card}>
          <div style={sectionTitle}>Photos</div>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            {[shop.image_url, ...(shop.image_urls || [])].filter(Boolean).map((u, i) => (
              <img key={i} src={u} alt="" style={{ width: 140, height: 140, objectFit: 'cover', borderRadius: 8, border: '1px solid #eee' }} />
            ))}
          </div>
        </div>
      )}

      <div style={card}>
        <div style={sectionTitle}>Address & Location</div>
        <div style={grid}>
          <Field l="Address" v={shop.shop_address} />
          <Field l="Locality" v={shop.location} />
          <Field l="Country" v={shop.country} />
          <Field l="State" v={shop.state} />
          <Field l="District" v={shop.district} />
          <Field l="City" v={shop.city} />
          <Field l="Pincode" v={shop.pincode} />
          <Field l="Phone" v={shop.phone} />
          <Field l="Timing" v={shop.timing} />
          <Field l="Lat / Lng" v={shop.lat && shop.lng ? `${shop.lat}, ${shop.lng}` : '—'} />
        </div>
      </div>

      <div style={card}>
        <div style={sectionTitle}>Category & Offer</div>
        <div style={grid}>
          <Field l="Category" v={shop.category} />
          <Field l="Shop type" v={shop.shop_type} />
          <Field l="Discount %" v={shop.discount_percentage != null ? `${shop.discount_percentage}%` : '—'} />
          <Field l="Rating" v={shop.rating} />
          <Field l="Favorites" v={shop.favorites_count ?? 0} />
          <Field l="Total reward given" v={shop.total_reward_given ?? 0} />
          <Field l="Total redeem used" v={shop.total_redeem_used ?? 0} />
          <Field l="Registered" v={fmtDate(shop.created_at)} />
        </div>
        {shop.about && (
          <div style={{ marginTop: 6 }}>
            <div style={label}>About</div>
            <div style={{ ...value, marginBottom: 0 }}>{shop.about}</div>
          </div>
        )}
      </div>

      <div style={card}>
        <div style={sectionTitle}>Owner</div>
        <div style={grid}>
          <Field l="Name" v={t?.user?.name} />
          <Field l="Email" v={shop.user_email} />
          <Field l="Phone" v={t?.user?.phone || shop.phone} />
          <Field l="User ID" v={shop.user_id} />
        </div>
      </div>

      <div style={card}>
        <div style={sectionTitle}>Plan & Payment</div>
        {t ? (
          <div style={grid}>
            <Field l="Plan" v={t.plan} />
            <Field l="Amount" v={money(t.amount)} />
            <Field l="Status" v={(t.payment_status || '').toUpperCase()} />
            <Field l="Razorpay order ID" v={t.razorpay_order_id} />
            <Field l="Razorpay payment ID" v={t.razorpay_payment_id} />
            <Field l="Paid on" v={fmtDate(t.created_at)} />
          </div>
        ) : (
          <div style={grid}>
            <Field l="Plan" v={shop.plan} />
            <Field l="Amount paid" v={shop.amount_paid != null ? money(shop.amount_paid) : '—'} />
          </div>
        )}
      </div>
    </div>
  )
}

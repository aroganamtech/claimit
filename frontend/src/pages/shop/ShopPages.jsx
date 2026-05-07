import { useState, useEffect } from 'react'
import ShopSidebar from './ShopSidebar'
import api from '../../utils/api'

// ─── Offer Management ─────────────────────────────────────────────────────────
export function OfferManagement() {
  const [current, setCurrent] = useState(15)
  const [selected, setSelected] = useState(null)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const options = [10, 15, 20, 25, 30, 35]

  useEffect(() => {
    api.get('/shop/offer').then(r => { setCurrent(r.data.discount_percentage); setSelected(r.data.discount_percentage) }).catch(() => {})
  }, [])

  const handlePublish = async () => {
    if (!selected) return
    setSaving(true)
    try {
      await api.put('/shop/offer', { discount_percentage: selected })
      setCurrent(selected)
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
    } catch (e) {}
    finally { setSaving(false) }
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <ShopSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Offer Management</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>Setup Your Offer For the customer you give</p>

        {/* Current Offer */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28, marginBottom: 20, maxWidth: 700 }}>
          <div style={{ fontSize: 14, color: '#888', marginBottom: 8 }}>Your Current Discount Offer</div>
          <div style={{ fontSize: 42, fontWeight: 700 }}>{current}%</div>
        </div>

        {/* Choose Offer */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28, maxWidth: 700 }}>
          <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 20 }}>Choose the discount you want to offer customers</div>
          <div style={{
            display: 'flex', gap: 12, flexWrap: 'wrap',
            border: '1.5px solid #eee', borderRadius: 10, padding: '16px 20px',
            marginBottom: 20
          }}>
            {options.map(opt => (
              <label key={opt} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 15, fontWeight: 500 }}>
                <input
                  type="radio"
                  name="discount"
                  checked={selected === opt}
                  onChange={() => setSelected(opt)}
                  style={{ accentColor: '#1565C0' }}
                />
                {opt}%
              </label>
            ))}
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              className="btn-primary"
              style={{ width: 'auto', padding: '10px 24px' }}
              onClick={handlePublish}
              disabled={saving}
            >
              {saving ? 'Saving...' : saved ? '✓ Saved!' : 'Publish Offer'}
            </button>
          </div>
        </div>
      </main>
    </div>
  )
}

// ─── Store Details Management ──────────────────────────────────────────────────
export function StoreDetailsManagement() {
  const [details, setDetails] = useState(null)
  const [editing, setEditing] = useState({})
  const [editValues, setEditValues] = useState({})
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    api.get('/shop/store-details').then(r => setDetails(r.data)).catch(() => {
      setDetails({
        shop_name: 'Santhosh Super Market',
        about: 'A great supermarket with wide variety.',
        shop_address: 'C33, 2nd Avenue ANNANAGAR CHENNAI: 600040, Anna Nagar, Chennai',
        geo_location: '36M4+X9 Chennai, Tamil Nadu',
        category: 'Super market',
        shop_type: 'Redeem Shop'
      })
    })
  }, [])

  const fields = [
    { key: 'shop_name', label: 'Shop Name', editLabel: 'Edit Shop Name' },
    { key: 'about', label: 'Description', editLabel: 'Edit Shop Description' },
    { key: 'shop_address', label: 'Shop Address', editLabel: 'Edit Shop Address' },
    { key: 'geo_location', label: 'Shop Geo Location', editLabel: 'Edit Geo location' },
    { key: 'category', label: 'Category', editLabel: 'Edit Shop Category' },
    { key: 'shop_type', label: 'Shop Type', editLabel: 'Edit Shop Type' },
  ]

  const handleEdit = (key) => {
    setEditing(prev => ({ ...prev, [key]: true }))
    setEditValues(prev => ({ ...prev, [key]: details?.[key] || '' }))
  }

  const handleSave = async (key) => {
    setSaving(true)
    try {
      await api.put('/shop/store-details', { [key]: editValues[key] })
      setDetails(prev => ({ ...prev, [key]: editValues[key] }))
      setEditing(prev => ({ ...prev, [key]: false }))
    } catch (e) {
      setDetails(prev => ({ ...prev, [key]: editValues[key] }))
      setEditing(prev => ({ ...prev, [key]: false }))
    } finally { setSaving(false) }
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <ShopSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Store Details Management</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>Edit Your Store Details</p>

        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28, maxWidth: 800 }}>
          <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Shop Information</h3>
          {fields.map(field => (
            <div key={field.key} style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              border: '1px solid #eee', borderRadius: 8, padding: '16px 18px', marginBottom: 12
            }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12, color: '#888', marginBottom: 4 }}>{field.label}</div>
                {editing[field.key] ? (
                  <input
                    className="input-field"
                    value={editValues[field.key] || ''}
                    onChange={e => setEditValues(prev => ({ ...prev, [field.key]: e.target.value }))}
                    style={{ marginTop: 4, padding: '8px 12px', fontSize: 13 }}
                  />
                ) : (
                  <div style={{ fontWeight: 600, fontSize: 14 }}>{details?.[field.key] || '—'}</div>
                )}
              </div>
              {editing[field.key] ? (
                <button
                  onClick={() => handleSave(field.key)}
                  style={{
                    marginLeft: 16, padding: '8px 16px', background: '#1565C0',
                    color: '#fff', border: 'none', borderRadius: 8, fontSize: 13,
                    cursor: 'pointer', fontFamily: 'Poppins', fontWeight: 600
                  }}
                >
                  {saving ? '...' : 'Save'}
                </button>
              ) : (
                <button
                  onClick={() => handleEdit(field.key)}
                  style={{
                    marginLeft: 16, padding: '8px 16px', background: '#fff',
                    border: '1px solid #ddd', borderRadius: 8, fontSize: 13,
                    cursor: 'pointer', fontFamily: 'Poppins', fontWeight: 500
                  }}
                >
                  {field.editLabel}
                </button>
              )}
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}

// ─── Ratings & Reviews ─────────────────────────────────────────────────────────
export function RatingsAndReviews() {
  const [data, setData] = useState(null)
  const [tab, setTab] = useState('all')
  const [replyText, setReplyText] = useState({})

  useEffect(() => {
    api.get('/shop/ratings').then(r => setData(r.data)).catch(() => {
      setData({
        average_rating: 4.5, total_reviews: 42, positive_percentage: 94,
        reviews: [
          { name: 'Varunn', date: '08/08/2025', rating: 3, comment: 'Good store with decent variety. Staff was helpful and the offers were attractive.' },
          { name: 'Arun', date: '08/08/2025', rating: 4, comment: 'Great shopping experience. The cashback rewards are a nice touch. Will visit again.' },
          { name: 'Tharun', date: '08/08/2025', rating: 5, comment: 'Excellent store! Best deals in the area. The loyalty program is fantastic.' },
        ]
      })
    })
  }, [])

  const renderStars = (count) => {
    return '★'.repeat(count) + '☆'.repeat(5 - count)
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <ShopSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Ratings & Reviews</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>Welcome to your advertising overview</p>

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, maxWidth: 700, marginBottom: 28 }}>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>⭐</div>
            <div className="stat-value">{data?.average_rating ?? '4.5'}</div>
            <div className="stat-label">Average Rating</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>💬</div>
            <div className="stat-value">{data?.total_reviews ?? 42}</div>
            <div className="stat-label">Total Reviews</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>👍</div>
            <div className="stat-value">{data?.positive_percentage ?? 94}%</div>
            <div className="stat-label">Positive Reviews</div>
          </div>
        </div>

        {/* Reviews */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px', borderBottom: '1px solid #eee' }}>
            <h3 style={{ fontWeight: 600, fontSize: 16 }}>Recent Reviews</h3>
            <div style={{ display: 'flex', gap: 4 }}>
              <button className={`tab-btn ${tab === 'all' ? 'active' : ''}`} onClick={() => setTab('all')}>All</button>
              <button className={`tab-btn ${tab === 'oldest' ? 'active' : ''}`} onClick={() => setTab('oldest')}>Oldest</button>
            </div>
          </div>

          {(data?.reviews || []).map((review, i) => (
            <div key={i} style={{ padding: '20px 24px', borderBottom: '1px solid #f5f5f5' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{
                    width: 40, height: 40, borderRadius: '50%',
                    background: '#1565C0', display: 'flex', alignItems: 'center',
                    justifyContent: 'center', color: '#fff', fontWeight: 700
                  }}>
                    {review.name?.[0]}
                  </div>
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>{review.name}</div>
                    <div style={{ fontSize: 12, color: '#888' }}>{review.date}</div>
                  </div>
                </div>
                <div style={{ color: '#F5A623', fontSize: 18 }}>{renderStars(review.rating)}</div>
              </div>
              <p style={{ color: '#555', fontSize: 13, lineHeight: 1.6, marginBottom: 10 }}>{review.comment}</p>
              {replyText[i] !== undefined ? (
                <div style={{ display: 'flex', gap: 8 }}>
                  <input
                    className="input-field"
                    placeholder="Write a reply..."
                    value={replyText[i]}
                    onChange={e => setReplyText(prev => ({ ...prev, [i]: e.target.value }))}
                    style={{ fontSize: 13, padding: '8px 12px' }}
                  />
                  <button
                    onClick={() => setReplyText(prev => { const n = {...prev}; delete n[i]; return n })}
                    style={{
                      padding: '8px 16px', background: '#1565C0', color: '#fff',
                      border: 'none', borderRadius: 8, fontSize: 13, cursor: 'pointer',
                      fontFamily: 'Poppins', flexShrink: 0
                    }}
                  >Post</button>
                </div>
              ) : (
                <button
                  onClick={() => setReplyText(prev => ({ ...prev, [i]: '' }))}
                  style={{ color: '#1565C0', background: 'none', border: 'none', fontSize: 13, cursor: 'pointer', fontWeight: 600, padding: 0 }}
                >
                  Reply
                </button>
              )}
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}

// ─── Account Settings ──────────────────────────────────────────────────────────
export function ShopSettings() {
  const [data, setData] = useState(null)

  useEffect(() => {
    api.get('/shop/settings').then(r => setData(r.data)).catch(() => {
      setData({ email: 'Your@gmail.com', phone: '8452035561', annual_price: 999, next_renewal: '08/12/2026' })
    })
  }, [])

  return (
    <div style={{ paddingTop: 64 }}>
      <ShopSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Account Settings</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>Make a update on setting Your Account</p>

        <div style={{ maxWidth: 700 }}>
          {/* Your Information */}
          <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28, marginBottom: 20 }}>
            <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Your Information</h3>
            <div style={{ marginBottom: 16 }}>
              <label style={{ display: 'block', fontSize: 13, color: '#888', marginBottom: 6 }}>Email Address</label>
              <input className="input-field" value={data?.email || ''} readOnly style={{ background: '#f9f9f9' }} />
            </div>
            <div>
              <label style={{ display: 'block', fontSize: 13, color: '#888', marginBottom: 6 }}>Phone Number</label>
              <input className="input-field" value={data?.phone || ''} readOnly style={{ background: '#f9f9f9' }} />
            </div>
          </div>

          {/* Annual Subscription */}
          <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28 }}>
            <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Annual Subscription</h3>
            <div style={{ background: '#1565C0', borderRadius: 12, padding: '20px 24px', color: '#fff' }}>
              <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>Price Summary</div>
              <div style={{ fontSize: 32, fontWeight: 700 }}>₹{data?.annual_price || 999}</div>
              <div style={{ fontSize: 13, opacity: 0.75, marginTop: 4 }}>
                Next renewal date - {data?.next_renewal || '08/12/2026'}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

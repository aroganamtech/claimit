import { useState, useEffect } from 'react'
import ShopSidebar from './ShopSidebar'
import api from '../../utils/api'

// ─── Helper: file → base64 ─────────────────────────────────────
function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
}

// ─── Offer Management ─────────────────────────────────────────────────────────
export function OfferManagement() {
  const [current, setCurrent] = useState(0)
  const [selected, setSelected] = useState(null)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const options = [10, 15, 20, 25, 30, 35]

  useEffect(() => {
    api.shop.getOffer().then(d => {
      setCurrent(d?.discount_percentage || 0)
      setSelected(d?.discount_percentage || null)
    }).catch(() => {})
  }, [])

  const handlePublish = async () => {
    if (!selected) return
    setSaving(true)
    try {
      await api.shop.setOffer({ discount_percentage: selected })
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

  // Gallery state
  const [gallery, setGallery] = useState({ cover_photo_b64: null, gallery_photos: [] })
  const [galleryLoading, setGalleryLoading] = useState(false)
  const [uploadingCover, setUploadingCover] = useState(false)
  const [uploadingGallery, setUploadingGallery] = useState(false)
  const [editingGallery, setEditingGallery] = useState(false)

  useEffect(() => {
    api.shop.getStoreDetails()
      .then(setDetails)
      .catch(() => setDetails({}))
    // Load gallery
    setGalleryLoading(true)
    api.shop.getGallery()
      .then(setGallery)
      .catch(() => setGallery({ cover_photo_b64: null, gallery_photos: [] }))
      .finally(() => setGalleryLoading(false))
  }, [])

  const handleCoverUpload = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setUploadingCover(true)
    try {
      const b64 = await fileToBase64(file)
      await api.shop.updateCoverPhoto({ photo_b64: b64 })
      setGallery(prev => ({ ...prev, cover_photo_b64: b64 }))
    } catch (err) {
      alert('Failed to upload cover photo')
    } finally { setUploadingCover(false) }
  }

  const handleGalleryUpload = async (e) => {
    const files = Array.from(e.target.files || [])
    if (files.length === 0) return
    setUploadingGallery(true)
    try {
      for (const file of files) {
        const b64 = await fileToBase64(file)
        await api.shop.addGalleryPhoto({ photo_b64: b64 })
        setGallery(prev => ({ ...prev, gallery_photos: [...prev.gallery_photos, b64] }))
      }
    } catch (err) {
      alert('Failed to upload photo')
    } finally { setUploadingGallery(false) }
  }

  const handleDeleteGalleryPhoto = async (index) => {
    if (!window.confirm('Remove this photo?')) return
    try {
      await api.shop.deleteGalleryPhoto(index)
      setGallery(prev => ({
        ...prev,
        gallery_photos: prev.gallery_photos.filter((_, i) => i !== index)
      }))
    } catch (err) {
      alert('Failed to delete photo')
    }
  }

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
      await api.shop.updateStoreDetails({ [key]: editValues[key] })
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

        {/* ── Gallery Photos ───────────────────────────────── */}
        {/* Hidden file inputs — triggered via htmlFor on the dropzone labels */}
        <input
          id="cover-upload-input"
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={handleCoverUpload}
        />
        <input
          id="gallery-upload-input"
          type="file"
          accept="image/*"
          multiple
          style={{ display: 'none' }}
          onChange={handleGalleryUpload}
        />

        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28, maxWidth: 800, marginTop: 20 }}>
          <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Upload Gallery Photos</h3>

          {/* Cover photo upload */}
          <div style={{ marginBottom: 20 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 10, margin: '0 0 10px' }}>
              Cover Photo
            </p>
            {/* label htmlFor ties to the hidden input above — no onClick needed, no double-trigger */}
            <label
              htmlFor="cover-upload-input"
              style={{
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', justifyContent: 'center',
                border: '2px dashed #ddd', borderRadius: 10,
                padding: '20px', cursor: 'pointer',
                background: gallery.cover_photo_b64 ? '#e8f5e9' : '#fafafa'
              }}
            >
              {gallery.cover_photo_b64 ? (
                <img
                  src={gallery.cover_photo_b64}
                  alt="cover"
                  style={{ width: 100, height: 100, objectFit: 'cover', borderRadius: 8, marginBottom: 8 }}
                />
              ) : (
                <span style={{ fontSize: 28, marginBottom: 6 }}>⬆</span>
              )}
              <span style={{ fontSize: 13, color: gallery.cover_photo_b64 ? '#2e7d32' : '#888' }}>
                {uploadingCover ? 'Uploading...' : gallery.cover_photo_b64 ? 'Click to change cover photo' : 'Click to upload cover photo'}
              </span>
            </label>
          </div>

          {/* Gallery multi-upload */}
          <div style={{ marginBottom: 24 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 10, margin: '0 0 10px' }}>
              Shop Photos
            </p>
            <label
              htmlFor="gallery-upload-input"
              style={{
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', justifyContent: 'center',
                border: '2px dashed #ddd', borderRadius: 10,
                padding: '20px', cursor: 'pointer',
                background: '#fafafa'
              }}
            >
              <span style={{ fontSize: 28, marginBottom: 6 }}>⬆</span>
              <span style={{ fontSize: 13, color: '#888' }}>
                {uploadingGallery ? 'Uploading...' : 'Click to upload shop photos'}
              </span>
            </label>
          </div>

          {/* Current gallery photos */}
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontSize: 14, fontWeight: 600, color: '#333' }}>Current Gallery Photos</span>
              <button
                onClick={() => setEditingGallery(prev => !prev)}
                style={{
                  background: 'none', border: '1px solid #ddd', borderRadius: 6,
                  padding: '5px 12px', fontSize: 12, cursor: 'pointer',
                  fontFamily: 'Poppins', color: '#555', fontWeight: 500
                }}
              >
                {editingGallery ? 'Done' : 'Edit Photo Gallery'}
              </button>
            </div>

            {galleryLoading ? (
              <div style={{ color: '#888', fontSize: 13 }}>Loading photos...</div>
            ) : gallery.gallery_photos.length === 0 && !gallery.cover_photo_b64 ? (
              <div style={{ color: '#bbb', fontSize: 13 }}>No photos uploaded yet. Use the upload areas above to add images.</div>
            ) : (
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {/* Cover photo thumbnail */}
                {gallery.cover_photo_b64 && (
                  <div style={{ position: 'relative' }}>
                    <img
                      src={gallery.cover_photo_b64}
                      alt="cover"
                      style={{ width: 90, height: 90, objectFit: 'cover', borderRadius: 8, border: '2px solid #1565C0' }}
                    />
                    <span style={{
                      position: 'absolute', bottom: 4, left: 4,
                      fontSize: 9, background: '#1565C0', color: '#fff',
                      borderRadius: 3, padding: '1px 4px'
                    }}>Cover</span>
                    {editingGallery && (
                      <label
                        htmlFor="cover-upload-input"
                        title="Change cover photo"
                        style={{
                          position: 'absolute', top: -6, right: -6,
                          width: 22, height: 22, borderRadius: '50%',
                          background: '#1565C0', border: 'none', color: '#fff',
                          fontSize: 11, cursor: 'pointer', lineHeight: '22px',
                          display: 'flex', alignItems: 'center', justifyContent: 'center'
                        }}
                      >✎</label>
                    )}
                  </div>
                )}
                {/* Gallery thumbnails */}
                {gallery.gallery_photos.map((src, i) => (
                  <div key={i} style={{ position: 'relative' }}>
                    <img
                      src={src}
                      alt={`shop ${i + 1}`}
                      style={{
                        width: 90, height: 90, objectFit: 'cover', borderRadius: 8,
                        border: '1px solid #eee',
                        opacity: editingGallery ? 0.8 : 1
                      }}
                    />
                    {editingGallery && (
                      <button
                        onClick={() => handleDeleteGalleryPhoto(i)}
                        style={{
                          position: 'absolute', top: -6, right: -6,
                          width: 22, height: 22, borderRadius: '50%',
                          background: '#e53935', border: 'none', color: '#fff',
                          fontSize: 12, cursor: 'pointer',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontFamily: 'Poppins', padding: 0
                        }}
                      >✕</button>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
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
    api.shop.getRatings()
      .then(setData)
      .catch(() => setData({ average_rating: 0, total_reviews: 0, positive_percentage: 0, reviews: [] }))
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
            <div className="stat-value">{data?.average_rating ?? 0}</div>
            <div className="stat-label">Average Rating</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>💬</div>
            <div className="stat-value">{data?.total_reviews ?? 0}</div>
            <div className="stat-label">Total Reviews</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>👍</div>
            <div className="stat-value">{data?.positive_percentage ?? 0}%</div>
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

          {(data?.reviews || []).length === 0 && (
            <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>💬</div>
              <div style={{ fontSize: 15, fontWeight: 500 }}>No reviews yet</div>
              <div style={{ fontSize: 13, marginTop: 4 }}>Customer reviews will appear here</div>
            </div>
          )}
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
    api.shop.getSettings()
      .then(setData)
      .catch(() => setData({ email: '', phone: '', annual_price: 999, next_renewal: '' }))
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
              <div style={{ fontSize: 32, fontWeight: 700 }}>₹{data?.annual_price ?? 999}</div>
              <div style={{ fontSize: 13, opacity: 0.75, marginTop: 4 }}>
                Next renewal date - {data?.next_renewal || '—'}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

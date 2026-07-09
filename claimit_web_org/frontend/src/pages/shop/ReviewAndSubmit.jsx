import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

export function ReviewAndSubmit() {
  const navigate = useNavigate()
  const basic = JSON.parse(sessionStorage.getItem('shop_basic') || '{}')
  const category = sessionStorage.getItem('shop_category') || '—'
  const shopType = sessionStorage.getItem('shop_type') || 'redeem'
  const shopDiscount = sessionStorage.getItem('shop_discount') || '15'
  const coverUrl = sessionStorage.getItem('shop_cover_url')
  const photosUrlsRaw = sessionStorage.getItem('shop_photos_urls')
  const galleryPreviews = photosUrlsRaw ? JSON.parse(photosUrlsRaw) : []

  return (
    <div className="auth-layout">
      <div className="auth-left">
        <img
          src="/assets/images/submit_shop.png"
          alt="Review and submit"
          style={{ width: 380, height: 380, borderRadius: 12, marginBottom: 32 }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Keep Your Customers Coming Back for More
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Offer the gift of rewards and watch your retention rates soar as customers return to redeem and earn again.
        </p>
      </div>

      <div className="auth-right">
        <div style={{
          width: '100%', background: '#fff',
          borderRadius: 16, padding: 36, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Review & Submit</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>Please review your information before submitting</p>

          {/* Shop Details */}
          <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 20, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <span style={{ fontWeight: 600, fontSize: 14 }}>Shop Details</span>
              <span
                style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer', fontWeight: 600 }}
                onClick={() => navigate('/shop/onboard/register')}
              >Edit</span>
            </div>
            {[
              { label: 'Shop Name', value: basic.shopName || '—' },
              { label: 'Shop Address', value: basic.shopAddress || '—' },
              { label: 'City / Area', value: basic.location || '—' },
              { label: 'Phone', value: basic.phone || '—' },
              { label: 'Timing', value: basic.timing || '—' },
              { label: 'Pincode', value: basic.pincode || '—' },
              { label: 'Description', value: basic.about || '—' },
            ].map(item => (
              <div key={item.label} style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 8, marginBottom: 8 }}>
                <span style={{ fontSize: 13, color: '#888' }}>{item.label}:</span>
                <span style={{ fontSize: 13, color: '#333', fontWeight: 500 }}>{item.value}</span>
              </div>
            ))}
          </div>

          {/* Photos */}
          <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 20, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontWeight: 600, fontSize: 14 }}>Shop Photos</span>
              <span
                style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer', fontWeight: 600 }}
                onClick={() => navigate('/shop/onboard/photos')}
              >Edit</span>
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {coverUrl && (
                <div style={{ position: 'relative' }}>
                  <img src={coverUrl} alt="cover" style={{ width: 60, height: 60, objectFit: 'cover', borderRadius: 6, border: '2px solid #1565C0' }} />
                  <span style={{ position: 'absolute', bottom: 2, left: 2, fontSize: 9, background: '#1565C0', color: '#fff', borderRadius: 3, padding: '1px 3px' }}>Cover</span>
                </div>
              )}
              {galleryPreviews.slice(0, 3).map((src, i) => (
                <img key={i} src={src} alt={`shop ${i + 1}`} style={{ width: 60, height: 60, objectFit: 'cover', borderRadius: 6, border: '1px solid #c5d0f0' }} />
              ))}
              {!coverUrl && galleryPreviews.length === 0 && (
                [1, 2, 3].map(i => (
                  <div key={i} style={{ width: 60, height: 60, background: '#d0daf0', borderRadius: 6 }} />
                ))
              )}
            </div>
          </div>

          {/* Category + Shop Type */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 24 }}>
            <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={{ fontWeight: 600, fontSize: 13 }}>Category</span>
                <span
                  style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer', fontWeight: 600 }}
                  onClick={() => navigate('/shop/onboard/category')}
                >Edit</span>
              </div>
              <div style={{ fontSize: 14, fontWeight: 500, textTransform: 'capitalize' }}>
                🏪 {category}
              </div>
            </div>
            <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={{ fontWeight: 600, fontSize: 13 }}>Shop Type</span>
                <span
                  style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer', fontWeight: 600 }}
                  onClick={() => navigate('/shop/onboard/shop-type')}
                >Edit</span>
              </div>
              <div style={{ fontSize: 14, fontWeight: 600, color: '#1565C0', textTransform: 'capitalize' }}>
                {shopType === 'redeem' ? '🏪' : '🎯'} {shopType.charAt(0).toUpperCase() + shopType.slice(1)} Shop
              </div>
              <div style={{ fontSize: 12, color: '#888', marginTop: 4 }}>{shopDiscount}% discount</div>
            </div>
          </div>

          <button
            className="btn-primary"
            onClick={() => navigate('/shop/onboard/payment')}
          >
            Submit & Pay
          </button>
        </div>
      </div>
    </div>
  )
}

export function ShopPayment() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState(null)
  const [loading, setLoading] = useState(false)
  const [paid, setPaid] = useState(false)
  const [photoWarning, setPhotoWarning] = useState('')

  const handlePay = async () => {
    if (!selected) return
    setLoading(true)

    try {
      const basic = JSON.parse(sessionStorage.getItem('shop_basic') || '{}')
      const category = sessionStorage.getItem('shop_category') || ''
      const shopType = sessionStorage.getItem('shop_type')
      const shopDiscount = sessionStorage.getItem('shop_discount') || '15'

      // BUG FIX: never silently default the shop type — a lost sessionStorage
      // value used to register the shop as 'redeem' even when the owner had
      // chosen 'Reward Shop'. Send the user back to choose explicitly.
      if (shopType !== 'reward' && shopType !== 'redeem') {
        alert('Please choose your shop type (Reward or Redeem) again before submitting.')
        setLoading(false)
        navigate('/shop/onboard/shop-type')
        return
      }

      // ── Step 1: Register shop basic info ──────────────────
      const formData = new FormData()
      formData.append('shop_name', basic.shopName || '')
      formData.append('shop_address', basic.shopAddress || '')
      formData.append('pincode', basic.pincode || '')
      formData.append('about', basic.about || '')
      formData.append('location', basic.location || '')
      formData.append('phone', basic.phone || '')
      formData.append('timing', basic.timing || '')
      formData.append('category', category)
      formData.append('shop_type', shopType)
      formData.append('discount_percentage', shopDiscount)
      if (basic.lat != null) formData.append('lat', basic.lat)
      if (basic.lng != null) formData.append('lng', basic.lng)

      await api.shop.register(formData)

      // ── Step 2: Register S3 keys from the photos already uploaded to S3
      // in the ShopPhotos step (presigned-URL flow — same as brand/nearby deals).
      // Keys are already in S3; we just tell the backend which keys belong to
      // this shop. No image bytes go through the backend or nginx.
      const coverKey = sessionStorage.getItem('shop_cover_key')
      const photosKeysRaw = sessionStorage.getItem('shop_photos_keys')
      let imageUploadFailed = false

      if (coverKey) {
        try {
          await api.shop.setCoverPhotoKey({ s3_key: coverKey })
        } catch (err) {
          console.error('Cover key registration failed', err)
          imageUploadFailed = true
        }
      }
      if (photosKeysRaw) {
        try {
          const keyArr = JSON.parse(photosKeysRaw)
          for (const key of keyArr) {
            try {
              await api.shop.addGalleryPhotoKey({ s3_key: key })
            } catch (err) {
              console.error('Gallery key registration failed', err)
              imageUploadFailed = true
            }
          }
        } catch (err) {
          console.error('Failed to parse stored photo keys', err)
        }
      }

      if (imageUploadFailed) {
        setPhotoWarning(
          'Your shop was submitted, but one or more photos failed to save. ' +
          'Please add them again from Store Details Management in your dashboard.'
        )
      }

      // ── Cleanup ───────────────────────────────────────────
      sessionStorage.removeItem('shop_basic')
      sessionStorage.removeItem('shop_category')
      sessionStorage.removeItem('shop_type')
      sessionStorage.removeItem('shop_discount')
      sessionStorage.removeItem('shop_cover_key')
      sessionStorage.removeItem('shop_cover_url')
      sessionStorage.removeItem('shop_photos_keys')
      sessionStorage.removeItem('shop_photos_urls')
      setPaid(true)
    } catch (e) {
      alert(e?.response?.data?.detail || 'Could not register shop')
    } finally {
      setLoading(false)
    }
  }

  if (paid) {
    return (
      <div style={{
        paddingTop: 64, minHeight: '100vh',
        display: 'flex', alignItems: 'center', justifyContent: 'center'
      }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{
            width: 80, height: 80, borderRadius: '50%',
            background: '#E8F5E9', margin: '0 auto 16px',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 36
          }}>✅</div>
          <h2 style={{ fontWeight: 700, fontSize: 26, marginBottom: 8 }}>Payment Successful!</h2>
          <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>
            Your advertisement has been scheduled successfully
          </p>
          {photoWarning && (
            <div style={{
              background: '#FFF3E0', border: '1px solid #FFB74D', borderRadius: 10,
              padding: '12px 16px', marginBottom: 24, maxWidth: 360,
              fontSize: 13, color: '#7a4a00', textAlign: 'left'
            }}>
              ⚠ {photoWarning}
            </div>
          )}
          <button className="btn-primary" style={{ width: 240 }} onClick={() => navigate('/shop/dashboard')}>
            Go to Dashboard
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="auth-layout">
      <div className="auth-left">
        <img
          src="/assets/images/payment_shop.png"
          alt="Finish payment"
          style={{ width: 380, height: 380, borderRadius: 12, marginBottom: 32 }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Master the Art of Customer Retention
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Join our network to provide a rewarding experience that guarantees satisfaction and keeps your registers ringing every single day.
        </p>
      </div>

      <div className="auth-right">
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 36, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 4 }}>Finish Your Payment</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 20 }}>Publish your shop instantly.</p>

          <div style={{ background: '#1565C0', borderRadius: 12, padding: '20px 24px', color: '#fff', marginBottom: 24 }}>
            <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>Price Summary</div>
            <div style={{ fontSize: 32, fontWeight: 700 }}>₹999</div>
            <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>Annually payment</div>
          </div>

          <h3 style={{ fontWeight: 600, fontSize: 14, marginBottom: 14 }}>Select Payment Method</h3>

          {[
            { id: 'upi', label: 'UPI', icons: '🟡 🟢 🔵 ⚡' },
            { id: 'cards', label: 'Cards', icons: '💳 💳 💳' },
            { id: 'netbanking', label: 'Netbanking', icons: '🏦 🏦 🏦' },
          ].map(method => (
            <div
              key={method.id}
              onClick={() => setSelected(method.id)}
              style={{
                border: `1.5px solid ${selected === method.id ? '#1565C0' : '#eee'}`,
                borderRadius: 10, padding: '14px 18px', marginBottom: 10,
                cursor: 'pointer', background: selected === method.id ? '#f0f4ff' : '#fff'
              }}
            >
              <div style={{ fontWeight: 600, fontSize: 14 }}>{method.label}</div>
              <div style={{ fontSize: 16, marginTop: 4 }}>{method.icons}</div>
            </div>
          ))}

          <button
            className="btn-primary"
            style={{ marginTop: 8, opacity: selected && !loading ? 1 : 0.6 }}
            onClick={handlePay}
            disabled={!selected || loading}
          >
            {loading ? 'Processing...' : 'Pay now'}
          </button>
        </div>
      </div>
    </div>
  )
}

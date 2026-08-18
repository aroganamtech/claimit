import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

export function ReviewAndSubmit() {
  const navigate = useNavigate()
  const basic = JSON.parse(sessionStorage.getItem('shop_basic') || '{}')
  const category = sessionStorage.getItem('shop_category') || '—'
  const shopType = sessionStorage.getItem('shop_type') || 'redeem'
  const shopDiscount = sessionStorage.getItem('shop_discount') || '15'
  const shopPlan = sessionStorage.getItem('shop_plan') || 'premium'
  const shopAmount = sessionStorage.getItem('shop_amount') || '0'
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
              <div style={{ fontSize: 12, color: '#1565C0', marginTop: 4, textTransform: 'capitalize' }}>
                {shopPlan} plan · ₹{shopAmount}
              </div>
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

  const shopPlan = sessionStorage.getItem('shop_plan') || 'premium'
  const shopAmount = Number(sessionStorage.getItem('shop_amount') || '0')

  // Load Razorpay Checkout script once.
  const loadRazorpay = () => new Promise((resolve) => {
    if (window.Razorpay) return resolve(true)
    const s = document.createElement('script')
    s.src = 'https://checkout.razorpay.com/v1/checkout.js'
    s.onload = () => resolve(true)
    s.onerror = () => resolve(false)
    document.body.appendChild(s)
  })

  // Register the shop, attach photo keys, clean up, and show success. Called
  // after payment succeeds (paid plans) or directly (free ₹0 "other" plan).
  const finalizeRegistration = async (formData) => {
    try {
      const regRes = await api.shop.register(formData)
      const newShopId = regRes?.shop?.id
      if (newShopId) localStorage.setItem('claimit_active_shop', newShopId)

      const coverKey = sessionStorage.getItem('shop_cover_key')
      const photosKeysRaw = sessionStorage.getItem('shop_photos_keys')
      let imageUploadFailed = false
      if (coverKey) {
        try { await api.shop.setCoverPhotoKey({ s3_key: coverKey }) }
        catch (err) { console.error('Cover key registration failed', err); imageUploadFailed = true }
      }
      if (photosKeysRaw) {
        try {
          const keyArr = JSON.parse(photosKeysRaw)
          for (const key of keyArr) {
            try { await api.shop.addGalleryPhotoKey({ s3_key: key }) }
            catch (err) { console.error('Gallery key registration failed', err); imageUploadFailed = true }
          }
        } catch (err) { console.error('Failed to parse stored photo keys', err) }
      }
      if (imageUploadFailed) {
        setPhotoWarning(
          'Your shop was submitted, but one or more photos failed to save. ' +
          'Please add them again from Store Details Management in your dashboard.'
        )
      }
      ;['shop_basic', 'shop_category', 'shop_type', 'shop_discount', 'shop_plan',
        'shop_amount', 'shop_cover_key', 'shop_cover_url', 'shop_photos_keys',
        'shop_photos_urls'].forEach(k => sessionStorage.removeItem(k))
      setPaid(true)
    } catch (e) {
      alert(e?.response?.data?.detail || 'Could not register shop')
    } finally {
      setLoading(false)
    }
  }

  const handlePay = async () => {
    // Razorpay's own modal handles the payment-method choice, so no on-page
    // method selection is required.
    setLoading(true)

    const basic = JSON.parse(sessionStorage.getItem('shop_basic') || '{}')
    const category = sessionStorage.getItem('shop_category') || ''
    const shopType = sessionStorage.getItem('shop_type')
    const shopDiscount = sessionStorage.getItem('shop_discount') || '15'
    const plan = sessionStorage.getItem('shop_plan') || 'premium'
    const amt = Number(sessionStorage.getItem('shop_amount') || '0')

    // Never silently default the shop type — send the user back to choose.
    if (shopType !== 'reward' && shopType !== 'redeem') {
      alert('Please choose your shop type (Reward or Redeem) again before submitting.')
      setLoading(false)
      navigate('/shop/onboard/shop-type')
      return
    }

    const formData = new FormData()
    formData.append('shop_name', basic.shopName || '')
    formData.append('shop_address', basic.shopAddress || '')
    formData.append('pincode', basic.pincode || '')
    formData.append('about', basic.about || '')
    formData.append('location', basic.location || '')
    formData.append('phone', basic.phone || '')
    formData.append('timing', basic.timing || '')
    formData.append('country', basic.country || '')
    formData.append('state', basic.state || '')
    formData.append('district', basic.district || '')
    formData.append('city', basic.city || '')
    formData.append('category', category)
    formData.append('shop_type', shopType)
    formData.append('discount_percentage', shopDiscount)
    formData.append('plan', plan)
    formData.append('amount', String(amt))
    if (basic.lat != null) formData.append('lat', basic.lat)
    if (basic.lng != null) formData.append('lng', basic.lng)

    // Free "other" plan (₹0) → register with no payment.
    if (!amt || amt <= 0) {
      await finalizeRegistration(formData)
      return
    }

    // Paid plan → real Razorpay Checkout, then register with the payment proof.
    try {
      const ok = await loadRazorpay()
      if (!ok) { alert('Could not load the payment gateway. Check your connection.'); setLoading(false); return }
      const order = await api.shop.createPayOrder(amt, plan)
      const rzp = new window.Razorpay({
        key: order.key_id,
        order_id: order.order_id,
        amount: order.amount,
        currency: order.currency || 'INR',
        name: 'Claimit',
        description: `${plan.charAt(0).toUpperCase() + plan.slice(1)} shop plan`,
        prefill: { name: basic.shopName || '', contact: basic.phone || '' },
        theme: { color: '#1565C0' },
        handler: (resp) => {
          formData.append('razorpay_order_id', resp.razorpay_order_id)
          formData.append('razorpay_payment_id', resp.razorpay_payment_id)
          formData.append('razorpay_signature', resp.razorpay_signature)
          finalizeRegistration(formData)   // server re-verifies the signature
        },
        modal: { ondismiss: () => setLoading(false) },
      })
      rzp.on('payment.failed', (r) => {
        alert('Payment failed: ' + (r?.error?.description || 'please try again'))
        setLoading(false)
      })
      rzp.open()
    } catch (e) {
      alert(e?.response?.data?.detail || 'Could not start payment')
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
            <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>
              Price Summary · <span style={{ textTransform: 'capitalize' }}>{shopPlan}</span> plan
            </div>
            <div style={{ fontSize: 32, fontWeight: 700 }}>₹{shopAmount}</div>
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
            style={{ marginTop: 8, opacity: loading ? 0.6 : 1 }}
            onClick={handlePay}
            disabled={loading}
          >
            {loading ? 'Processing...' : 'Pay now'}
          </button>
        </div>
      </div>
    </div>
  )
}

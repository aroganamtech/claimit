// ─────────────────────────────────────────────────────────────────────────
// Shop registration — mobile-first "claim" flow.
//   mobile → (shops with that number?) → pick one → email OTP →
//   Redeem/Reward → plan (Premium/Standard/Other custom, 0 to any) →
//   real Razorpay payment → done. If no shop is found for the number, fall
//   back to the full manual registration form (the old flow).
// ─────────────────────────────────────────────────────────────────────────
import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

const BLUE = '#2563eb'
const wrap = { maxWidth: 560, margin: '0 auto', padding: '90px 24px 40px', minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center', boxSizing: 'border-box' }
const card = { background: '#fff', borderRadius: 14, padding: 22, boxShadow: '0 1px 6px rgba(0,0,0,0.07)', marginBottom: 16 }
const input = { width: '100%', padding: '12px 14px', border: '1px solid #d1d5db', borderRadius: 10, fontSize: 15, boxSizing: 'border-box', fontFamily: 'inherit' }
const label = { fontSize: 13, fontWeight: 600, color: '#374151', margin: '0 0 6px' }
const primaryBtn = { width: '100%', padding: 13, background: BLUE, color: '#fff', border: 'none', borderRadius: 10, fontSize: 15, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit' }

// Fallback shown until the live prices load from GET /shop/pricing (admin-
// configurable). Kept in sync with utils/pricing.py's DEFAULT_PRICING.
const DEFAULT_PLANS = [
  { id: 'premium',  name: 'Premium',  price: 720, note: 'Top placement + full visibility' },
  { id: 'standard', name: 'Standard', price: 365, note: 'Priority listing' },
  { id: 'other',    name: 'Other',    price: 0,   note: 'Enter any amount (0 or more)' },
]

const loadRazorpay = () => new Promise((resolve) => {
  if (window.Razorpay) return resolve(true)
  const s = document.createElement('script')
  s.src = 'https://checkout.razorpay.com/v1/checkout.js'
  s.onload = () => resolve(true)
  s.onerror = () => resolve(false)
  document.body.appendChild(s)
})
const DISCOUNTS = [5, 10, 15, 20, 25, 30]

export default function ShopClaim() {
  const navigate = useNavigate()
  const [step, setStep] = useState('mobile')  // mobile|select|email|otp|type|plan|pay|done
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')

  const [mobile, setMobile] = useState('')
  const [shops, setShops] = useState([])
  const [shopId, setShopId] = useState('')
  const [shopName, setShopName] = useState('')

  const [email, setEmail] = useState('')
  const [otp, setOtp] = useState('')
  const [devOtp, setDevOtp] = useState('')

  const [shopType, setShopType] = useState('')     // redeem | reward
  const [discount, setDiscount] = useState(15)
  const [planId, setPlanId] = useState('premium')
  const [customAmount, setCustomAmount] = useState('')
  const [imageKey, setImageKey] = useState('')
  const [imagePreview, setImagePreview] = useState('')
  const [plans, setPlans] = useState(DEFAULT_PLANS)

  useEffect(() => {
    api.shop.getPricing()
      .then(p => setPlans([
        { id: 'premium',  name: 'Premium',  price: p.premium,  note: 'Top placement + full visibility' },
        { id: 'standard', name: 'Standard', price: p.standard, note: 'Priority listing' },
        { id: 'other',    name: 'Other',    price: 0,          note: 'Enter any amount (0 or more)' },
      ]))
      .catch(() => {}) // keep DEFAULT_PLANS on failure
  }, [])

  const amount = planId === 'other'
    ? Number(customAmount || 0)
    : (plans.find(p => p.id === planId)?.price || 0)

  const err = (e) => setError(e?.response?.data?.detail || e?.message || 'Something went wrong')

  // ── Step handlers ──────────────────────────────────────────────────────────
  const lookup = async () => {
    setError('')
    const digits = mobile.replace(/[^0-9]/g, '')
    if (digits.length < 10) { setError('Enter a valid 10-digit mobile number'); return }
    setBusy('Checking…')
    try {
      const res = await api.shop.lookupByMobile(digits)
      const list = res.shops || []
      if (list.length === 0) {
        // No existing shop for this number → full manual registration.
        navigate('/shop/onboard/register')
        return
      }
      setShops(list)
      setStep('select')
    } catch (e) { err(e) } finally { setBusy('') }
  }

  const chooseShop = (s) => { setShopId(s.id); setShopName(s.shop_name) }

  const sendOtp = async () => {
    setError('')
    if (!/^[^@]+@[^@]+\.[^@]+$/.test(email.trim())) { setError('Enter a valid email'); return }
    setBusy('Sending OTP…')
    try {
      const res = await api.shop.sendEmailOtp(email.trim())
      setDevOtp(res.dev_otp || '')   // shown only if SMTP isn't configured (testing)
      setStep('otp')
    } catch (e) { err(e) } finally { setBusy('') }
  }

  const verifyOtp = async () => {
    setError('')
    setBusy('Verifying…')
    try {
      await api.shop.verifyEmailOtp(email.trim(), otp.trim())
      setStep('type')
    } catch (e) { err(e) } finally { setBusy('') }
  }

  const pickImage = async (file) => {
    if (!file) return
    setError('')
    try {
      const presign = await api.shop.presignImage()
      // The shop presign is signed for image/jpeg, so the PUT must match it.
      await fetch(presign.upload_url, { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' }, body: file })
      setImageKey(presign.key)
      setImagePreview(URL.createObjectURL(file))
    } catch (e) { err(e) }
  }

  const finalizeClaim = async (paymentProof) => {
    setBusy('Registering…')
    try {
      await api.shop.claimShop({
        shop_id: shopId,
        shop_type: shopType,
        discount_percentage: shopType === 'redeem' ? discount : 0,
        plan: planId,
        amount,
        email: email.trim(),
        image_key: imageKey || undefined,
        ...paymentProof,
      })
      setStep('done')
    } catch (e) { err(e) } finally { setBusy('') }
  }

  const pay = async () => {
    setError('')
    if (planId === 'other' && amount < 0) { setError('Enter a valid amount'); return }
    setBusy('')

    // Free "other" plan (₹0) → register with no payment.
    if (!amount || amount <= 0) {
      await finalizeClaim({})
      return
    }

    // Paid plan → real Razorpay Checkout, then claim with the payment proof.
    setBusy('Opening payment…')
    try {
      const ok = await loadRazorpay()
      if (!ok) { setError('Could not load the payment gateway. Check your connection.'); setBusy(''); return }
      const order = await api.shop.createPayOrder(amount, planId)
      const rzp = new window.Razorpay({
        key: order.key_id,
        order_id: order.order_id,
        amount: order.amount,
        currency: order.currency || 'INR',
        name: 'Claimit',
        description: `${planId.charAt(0).toUpperCase() + planId.slice(1)} shop plan`,
        prefill: { name: shopName, email: email.trim() },
        theme: { color: BLUE },
        handler: (resp) => {
          finalizeClaim({
            razorpay_order_id: resp.razorpay_order_id,
            razorpay_payment_id: resp.razorpay_payment_id,
            razorpay_signature: resp.razorpay_signature,
          })
        },
        modal: { ondismiss: () => setBusy('') },
      })
      rzp.on('payment.failed', (r) => {
        setError('Payment failed: ' + (r?.error?.description || 'please try again'))
        setBusy('')
      })
      rzp.open()
    } catch (e) { err(e); setBusy('') }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  const Header = ({ title, sub }) => (
    <div style={{ marginBottom: 18 }}>
      <h1 style={{ fontSize: 22, fontWeight: 800, color: BLUE, margin: 0 }}>{title}</h1>
      {sub && <p style={{ color: '#6b7280', margin: '6px 0 0', fontSize: 14 }}>{sub}</p>}
    </div>
  )

  return (
    <div style={wrap}>
      {error && <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>}

      {step === 'mobile' && (
        <div style={card}>
          <Header title="Register Your Shop" sub="Enter your business mobile number to get started." />
          <p style={label}>Mobile Number</p>
          <input style={input} type="tel" placeholder="10-digit mobile number" value={mobile}
                 onChange={e => setMobile(e.target.value.replace(/[^0-9]/g, '').slice(0, 12))} />
          <div style={{ height: 16 }} />
          <button style={primaryBtn} onClick={lookup} disabled={!!busy}>{busy || 'Continue'}</button>
        </div>
      )}

      {step === 'select' && (
        <div style={card}>
          <Header title="Select Your Shop" sub={`We found ${shops.length} shop(s) for ${mobile}. Pick yours.`} />
          {shops.map(s => (
            <label key={s.id} style={{
              display: 'flex', gap: 10, alignItems: 'flex-start', padding: 12, marginBottom: 10,
              border: `1.5px solid ${shopId === s.id ? BLUE : '#e5e7eb'}`, borderRadius: 10, cursor: 'pointer',
            }}>
              <input type="radio" name="shop" checked={shopId === s.id} onChange={() => chooseShop(s)} style={{ marginTop: 4 }} />
              <span>
                <b>{s.shop_name}</b>
                <div style={{ fontSize: 13, color: '#6b7280' }}>{s.address || s.location}</div>
                {s.phone && <div style={{ fontSize: 12, color: '#9ca3af', marginTop: 2 }}>📱 {s.phone}</div>}
              </span>
            </label>
          ))}
          <button style={{ ...primaryBtn, marginTop: 8 }} disabled={!shopId} onClick={() => setStep('email')}>Continue</button>
          <button onClick={() => navigate('/shop/onboard/register')}
                  style={{ width: '100%', marginTop: 10, padding: 11, background: '#fff', color: BLUE, border: `1px solid ${BLUE}`, borderRadius: 10, fontWeight: 600, cursor: 'pointer' }}>
            None of these — register a new shop
          </button>
        </div>
      )}

      {step === 'email' && (
        <div style={card}>
          <Header title="Verify Your Email" sub="We'll send a one-time code to confirm it's you." />
          <p style={label}>Email</p>
          <input style={input} type="email" placeholder="you@example.com" value={email} onChange={e => setEmail(e.target.value)} />
          <div style={{ height: 16 }} />
          <button style={primaryBtn} onClick={sendOtp} disabled={!!busy}>{busy || 'Send OTP'}</button>
        </div>
      )}

      {step === 'otp' && (
        <div style={card}>
          <Header title="Enter OTP" sub={`Code sent to ${email}.`} />
          {devOtp && <div style={{ fontSize: 13, color: '#b26a00', marginBottom: 8 }}>Testing code: <b>{devOtp}</b></div>}
          {!devOtp && (
            <div style={{ fontSize: 13, color: '#6b7280', marginBottom: 8 }}>
              Don't see it? Check your spam/junk folder — it can take a minute to arrive.
            </div>
          )}
          <input style={input} inputMode="numeric" placeholder="6-digit code" value={otp}
                 onChange={e => setOtp(e.target.value.replace(/[^0-9]/g, '').slice(0, 6))} />
          <div style={{ height: 16 }} />
          <button style={primaryBtn} onClick={verifyOtp} disabled={!!busy}>{busy || 'Verify'}</button>
          <button onClick={sendOtp} style={{ width: '100%', marginTop: 10, padding: 10, background: 'none', color: BLUE, border: 'none', cursor: 'pointer' }}>Resend code</button>
        </div>
      )}

      {step === 'type' && (
        <div style={card}>
          <Header title="Choose Shop Type" sub={`For "${shopName}".`} />
          {[
            { id: 'redeem', t: 'Redeem Shop', d: 'Customers redeem points for a discount at your shop.' },
            { id: 'reward', t: 'Reward Shop', d: 'Customers earn reward points on every bill.' },
          ].map(o => (
            <label key={o.id} style={{
              display: 'flex', gap: 10, padding: 14, marginBottom: 10,
              border: `1.5px solid ${shopType === o.id ? BLUE : '#e5e7eb'}`, borderRadius: 10, cursor: 'pointer',
            }}>
              <input type="radio" name="type" checked={shopType === o.id} onChange={() => setShopType(o.id)} />
              <span><b>{o.t}</b><div style={{ fontSize: 13, color: '#6b7280' }}>{o.d}</div></span>
            </label>
          ))}
          {shopType === 'redeem' && (
            <div style={{ marginTop: 8 }}>
              <p style={label}>Redeem discount %</p>
              <select style={input} value={discount} onChange={e => setDiscount(Number(e.target.value))}>
                {DISCOUNTS.map(d => <option key={d} value={d}>{d}%</option>)}
              </select>
            </div>
          )}
          <div style={{ marginTop: 14 }}>
            <p style={label}>Shop photo (optional — replaces the default category image)</p>
            <input type="file" accept="image/*" onChange={e => pickImage(e.target.files?.[0])} />
            {imagePreview && <img src={imagePreview} alt="" style={{ marginTop: 8, width: 80, height: 80, objectFit: 'cover', borderRadius: 8 }} />}
          </div>
          <button style={{ ...primaryBtn, marginTop: 16 }} disabled={!shopType} onClick={() => setStep('plan')}>Continue</button>
        </div>
      )}

      {step === 'plan' && (
        <div style={card}>
          <Header title="Choose a Plan" />
          {plans.map(p => (
            <label key={p.id} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: 14, marginBottom: 10,
              border: `1.5px solid ${planId === p.id ? BLUE : '#e5e7eb'}`, borderRadius: 10, cursor: 'pointer',
            }}>
              <span style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                <input type="radio" name="plan" checked={planId === p.id} onChange={() => setPlanId(p.id)} />
                <span><b>{p.name}</b><div style={{ fontSize: 13, color: '#6b7280' }}>{p.note}</div></span>
              </span>
              {p.id !== 'other' && <b style={{ color: BLUE }}>₹{p.price}</b>}
            </label>
          ))}
          {planId === 'other' && (
            <input style={input} inputMode="numeric" placeholder="Enter amount (₹)" value={customAmount}
                   onChange={e => setCustomAmount(e.target.value.replace(/[^0-9]/g, ''))} />
          )}
          <button style={{ ...primaryBtn, marginTop: 16 }} onClick={() => setStep('pay')}>Continue</button>
        </div>
      )}

      {step === 'pay' && (
        <div style={card}>
          <Header title="Payment" />
          <div style={{ background: '#eff6ff', borderRadius: 10, padding: 14, marginBottom: 14 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>{shopName}</span><b>{shopType === 'redeem' ? `${discount}% Redeem` : 'Reward'}</b></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 18, fontWeight: 800, color: BLUE }}>
              <span>Total</span><span>₹{amount}</span>
            </div>
          </div>
          <button style={primaryBtn} onClick={pay} disabled={!!busy}>
            {busy || (amount > 0 ? `Pay ₹${amount} & Register` : 'Register (Free)')}
          </button>
          {amount > 0 && (
            <p style={{ fontSize: 12, color: '#9ca3af', marginTop: 10, textAlign: 'center' }}>
              You'll be taken to Razorpay's secure checkout to complete payment.
            </p>
          )}
        </div>
      )}

      {step === 'done' && (
        <div style={{ ...card, textAlign: 'center' }}>
          <div style={{ fontSize: 46 }}>✅</div>
          <h1 style={{ fontSize: 22, fontWeight: 800, color: '#111827' }}>Shop Registered!</h1>
          <p style={{ color: '#6b7280' }}>
            <b>{shopName}</b> is now live as a {shopType} shop. You can edit its photo and details anytime from your dashboard.
          </p>
          <button style={{ ...primaryBtn, marginTop: 12 }} onClick={() => navigate('/shop/dashboard')}>Go to Dashboard</button>
        </div>
      )}
    </div>
  )
}

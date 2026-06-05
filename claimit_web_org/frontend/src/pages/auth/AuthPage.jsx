import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import api from '../../utils/api'

const PORTAL_CONFIG = {
  advertiser: {
    role: 'advertiser',
    title: 'Maximize Your Revenue with Claimit',
    subtitle: 'Join the affiliate network where every sale generates extra value for your business and a cashback bonus for you.',
    otpTitle: 'Turn Every Bill Into a Reward for You',
    otpSubtitle: 'Experience the joy of a platform that gives back to the merchant, ensuring you profit from every loyal interaction.',
    dashPath: '/advertiser/dashboard',
    extraFields: false,
  },
  sales: {
    role: 'sales',
    title: 'Join the Claimit Sales Network',
    subtitle: 'Register as a Sales Head, Executive, Advertising Executive or Freelancer. Your unique ID tracks every sale you close.',
    otpTitle: 'Boost Your Profits with Every Sale',
    otpSubtitle: 'Benefit from our incentive programme while helping businesses grow through our unique loyalty platform.',
    dashPath: '/sales/dashboard',
    extraFields: true,
  },
  shop: {
    role: 'shop',
    title: 'Scale Your Business Like Never Before',
    subtitle: 'Join Claimit to turn every transaction into a growth opportunity and reach a wider, more loyal customer base effortlessly.',
    otpTitle: 'Take Your Business to the Next Level',
    otpSubtitle: 'Empower your brand with our loyalty ecosystem, designed to increase your footfall and maximise your long-term revenue potential.',
    dashPath: '/shop/onboard',
    extraFields: false,
  }
}

const SUB_ROLES = [
  { value: 'sales_head',            label: 'Sales Head',             desc: 'Leads a team of sales executives' },
  { value: 'sales_executive',       label: 'Sales Executive',        desc: 'Onboards shops to Claimit' },
  { value: 'advertising_executive', label: 'Advertising Executive',  desc: 'Sells ad slots to businesses' },
  { value: 'freelancer',            label: 'Freelancer',             desc: 'Independent sales affiliate' },
]

export default function AuthPage({ portal }) {
  const config = PORTAL_CONFIG[portal] || PORTAL_CONFIG.advertiser
  const navigate = useNavigate()
  const { login } = useAuth()

  const [step, setStep]         = useState('register') // register | otp | details
  const [phone, setPhone]       = useState('')
  const [email, setEmail]       = useState('')
  const [otp, setOtp]           = useState(['', '', '', '', '', ''])
  const [name, setName]         = useState('')
  const [address, setAddress]   = useState('')
  const [pincode, setPincode]   = useState('')
  const [lat, setLat]           = useState(null)
  const [lng, setLng]           = useState(null)
  const [subRole, setSubRole]   = useState('')
  const [referredBy, setReferredBy] = useState('')
  const [locating, setLocating] = useState(false)
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState('')
  const [devOtp, setDevOtp]     = useState('')

  const isSales = portal === 'sales'

  const handleUseLocation = () => {
    if (!navigator.geolocation) { setError('Geolocation not supported'); return }
    setError(''); setLocating(true)
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        const { latitude, longitude } = pos.coords
        setLat(latitude); setLng(longitude)
        try {
          const data = await api.geo.reverse(latitude, longitude)
          if (data.address) setAddress(data.address)
          if (data.pincode) setPincode(data.pincode)
        } catch { setError('Could not look up address') }
        finally { setLocating(false) }
      },
      (err) => { setLocating(false); setError(err.message || 'Could not access location') },
      { enableHighAccuracy: true, timeout: 10000 }
    )
  }

  const handleSendOtp = async () => {
    if (!phone || !email) { setError('Please fill all fields'); return }
    if (isSales && !subRole) { setError('Please select your role type'); return }
    setError(''); setLoading(true)
    try {
      const data = await api.auth.sendOtp({
        phone, email, role: config.role,
        sub_role: isSales ? subRole : undefined,
        referred_by: (isSales && referredBy.trim()) ? referredBy.trim() : undefined,
      })
      if (data.dev_otp) setDevOtp(data.dev_otp)
      setStep('otp')
    } catch (e) {
      setError(e.response?.data?.detail || 'Failed to send OTP')
    } finally { setLoading(false) }
  }

  const handleVerifyOtp = async () => {
    const otpStr = otp.join('')
    if (otpStr.length < 6) { setError('Enter complete OTP'); return }
    setError(''); setLoading(true)
    try {
      await api.auth.verifyOtp({ phone, email, otp: otpStr, role: config.role })
      setStep('details')
    } catch (e) {
      setError(e.response?.data?.detail || 'Invalid OTP')
    } finally { setLoading(false) }
  }

  const handleCompleteReg = async () => {
    if (!name || !address || !pincode) { setError('Please fill all fields'); return }
    setError(''); setLoading(true)
    try {
      const data = await api.auth.register({
        phone, email, name, address, pincode, lat, lng,
        role: config.role,
        sub_role: isSales ? subRole : undefined,
        referred_by: (isSales && referredBy.trim()) ? referredBy.trim() : undefined,
      })
      login(data)
      // Show unique ID if sales
      if (data.unique_id) {
        sessionStorage.setItem('new_unique_id', data.unique_id)
        sessionStorage.setItem('new_sub_role', data.sub_role || '')
      }
      navigate(config.dashPath)
    } catch (e) {
      setError(e.response?.data?.detail || 'Registration failed')
    } finally { setLoading(false) }
  }

  const handleOtpInput = (val, idx) => {
    const newOtp = [...otp]; newOtp[idx] = val.slice(-1); setOtp(newOtp)
    if (val && idx < 5) document.getElementById(`otp-${idx + 1}`)?.focus()
  }
  const handleOtpKeyDown = (e, idx) => {
    if (e.key === 'Backspace' && !otp[idx] && idx > 0)
      document.getElementById(`otp-${idx - 1}`)?.focus()
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', paddingTop: 64 }}>
      {/* Left panel */}
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <img
          src={step === 'register' ? '/assets/images/register.png' : '/assets/images/otp.png'}
          alt="claimit"
          style={{ width: 380, height: '100%', borderRadius: 12, marginBottom: 32, objectFit: 'cover' }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          {step === 'register' ? config.title : config.otpTitle}
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          {step === 'register' ? config.subtitle : config.otpSubtitle}
        </p>
      </div>

      {/* Right panel */}
      <div style={{ width: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>

          {/* ── STEP 1: Register ── */}
          {step === 'register' && (
            <>
              <h2 style={{ fontWeight: 700, fontSize: 24, marginBottom: 8 }}>Register Your Account</h2>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>
                We'll send a verification code to confirm your details
              </p>
              {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13 }}>{error}</div>}

              {/* Sub-role selector (sales only) */}
              {isSales && (
                <div style={{ marginBottom: 20 }}>
                  <label style={labelStyle}>Select Your Role <span style={{ color: '#e53935' }}>*</span></label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                    {SUB_ROLES.map(r => (
                      <div
                        key={r.value}
                        onClick={() => setSubRole(r.value)}
                        style={{
                          border: `1.5px solid ${subRole === r.value ? '#1565C0' : '#ddd'}`,
                          borderRadius: 10, padding: '10px 12px', cursor: 'pointer',
                          background: subRole === r.value ? '#EEF4FF' : '#fff',
                          transition: 'all 0.15s'
                        }}
                      >
                        <div style={{ fontWeight: 600, fontSize: 13, color: subRole === r.value ? '#1565C0' : '#333' }}>
                          {r.label}
                        </div>
                        <div style={{ fontSize: 11, color: '#888', marginTop: 2 }}>{r.desc}</div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Phone Number</label>
                <input className="input-field" placeholder="Enter your number" value={phone}
                  onChange={e => setPhone(e.target.value)} type="tel" />
              </div>
              <div style={{ marginBottom: isSales ? 16 : 24 }}>
                <label style={labelStyle}>Email Address</label>
                <input className="input-field" placeholder="you@email.com" value={email}
                  onChange={e => setEmail(e.target.value)} type="email" />
              </div>

              {/* Referred by (sales only, non-head roles) */}
              {isSales && subRole && subRole !== 'sales_head' && (
                <div style={{ marginBottom: 24 }}>
                  <label style={labelStyle}>Sales Head ID <span style={{ color: '#888', fontWeight: 400 }}>(optional)</span></label>
                  <input className="input-field" placeholder="e.g. CLM-SH-0001"
                    value={referredBy} onChange={e => setReferredBy(e.target.value.toUpperCase())} />
                  <div style={{ fontSize: 11, color: '#888', marginTop: 4 }}>
                    Enter your Sales Head's unique ID if you're joining under a team
                  </div>
                </div>
              )}
              {isSales && subRole === 'sales_head' && <div style={{ marginBottom: 24 }} />}

              <button className="btn-primary" onClick={handleSendOtp} disabled={loading}>
                {loading ? 'Sending...' : 'Continue'}
              </button>
              <p style={{ textAlign: 'center', marginTop: 16, fontSize: 13, color: '#888' }}>
                Already have an account?{' '}
                <span style={{ color: '#1565C0', cursor: 'pointer', fontWeight: 600 }}
                  onClick={() => navigate(`/${portal}/login`)}>Login</span>
              </p>
            </>
          )}

          {/* ── STEP 2: OTP ── */}
          {step === 'otp' && (
            <>
              <h2 style={{ fontWeight: 700, fontSize: 24, marginBottom: 8 }}>Enter OTP</h2>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>
                We've sent a 6-digit code to your phone and email
              </p>
              {devOtp && (
                <div style={{ background: '#e8f5e9', border: '1px solid #c8e6c9', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 13, color: '#2e7d32' }}>
                  Dev OTP: <strong>{devOtp}</strong>
                </div>
              )}
              {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13 }}>{error}</div>}
              <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginBottom: 20 }}>
                {otp.map((digit, idx) => (
                  <input key={idx} id={`otp-${idx}`} type="text" inputMode="numeric" maxLength={1}
                    value={digit}
                    onChange={e => handleOtpInput(e.target.value, idx)}
                    onKeyDown={e => handleOtpKeyDown(e, idx)}
                    style={{
                      width: 50, height: 56, textAlign: 'center', fontSize: 22, fontWeight: 700,
                      border: '1.5px solid #ddd', borderRadius: 10, outline: 'none', background: '#fff'
                    }} />
                ))}
              </div>
              <p style={{ textAlign: 'center', marginBottom: 20, fontSize: 13 }}>
                <span style={{ color: '#888' }}>Didn't receive code? </span>
                <span style={{ color: '#1565C0', cursor: 'pointer', fontWeight: 600 }} onClick={handleSendOtp}>
                  Resend OTP
                </span>
              </p>
              <button className="btn-primary" onClick={handleVerifyOtp} disabled={loading}>
                {loading ? 'Verifying...' : 'Verify OTP'}
              </button>
            </>
          )}

          {/* ── STEP 3: Details ── */}
          {step === 'details' && (
            <>
              <h2 style={{ fontWeight: 700, fontSize: 24, marginBottom: 8 }}>Add Your Details</h2>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>Complete your profile to get your unique ID</p>
              {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13 }}>{error}</div>}
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Your Name</label>
                <input className="input-field" placeholder="Full name" value={name} onChange={e => setName(e.target.value)} />
              </div>
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Address</label>
                <input className="input-field" placeholder="Your address" value={address} onChange={e => setAddress(e.target.value)} />
              </div>
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Pincode</label>
                <input className="input-field" placeholder="Pincode" value={pincode} onChange={e => setPincode(e.target.value)} />
              </div>
              <button onClick={handleUseLocation} disabled={locating}
                style={{
                  width: '100%', padding: '13px', border: '1.5px solid #ccc',
                  borderRadius: 8, background: '#fff', fontSize: 14, marginBottom: 16,
                  cursor: 'pointer', fontFamily: 'Poppins', color: '#555'
                }}>
                {locating ? '📍 Locating…' : '📍 Use my current location'}
              </button>
              <button className="btn-primary" onClick={handleCompleteReg} disabled={loading}>
                {loading ? 'Creating account...' : 'Create Account'}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

const labelStyle = { display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }

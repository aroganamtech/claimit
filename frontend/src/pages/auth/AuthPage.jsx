import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
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
    title: 'Create Lasting Bonds With Every Bill',
    subtitle: 'Give your customers a reason to smile by providing points and cashback that make every purchase feel like a win.',
    otpTitle: 'Boost Your Profits with Every Transaction',
    otpSubtitle: 'Benefit from our 1% shop incentive while providing incredible value to your customers through our unique loyalty platform.',
    dashPath: '/sales/dashboard',
    extraFields: true,
  },
  shop: {
    role: 'shop',
    title: 'Scale Your Business Like Never Before',
    subtitle: 'Join Claimit to turn every transaction into a growth opportunity and reach a wider, more loyal customer base effortlessly.',
    otpTitle: 'Take Your Business to the Next Level',
    otpSubtitle: 'Empower your brand with our loyalty ecosystem, designed to increase your footfall and maximize your long-term revenue potential.',
    dashPath: '/shop/onboard',
    extraFields: false,
  }
}

export default function AuthPage({ portal }) {
  const config = PORTAL_CONFIG[portal] || PORTAL_CONFIG.advertiser
  const navigate = useNavigate()
  const { login } = useAuth()

  const [step, setStep] = useState('register') // register | otp | details
  const [phone, setPhone] = useState('')
  const [email, setEmail] = useState('')
  const [otp, setOtp] = useState(['', '', '', '', '', ''])
  const [name, setName] = useState('')
  const [address, setAddress] = useState('')
  const [pincode, setPincode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [devOtp, setDevOtp] = useState('')

  const handleSendOtp = async () => {
    if (!phone || !email) { setError('Please fill all fields'); return }
    setError('')
    setLoading(true)
    try {
      const res = await api.post('/auth/send-otp', { phone, email, role: config.role })
      if (res.data.dev_otp) setDevOtp(res.data.dev_otp)
      setStep('otp')
    } catch (e) {
      setError(e.response?.data?.detail || 'Failed to send OTP')
    } finally { setLoading(false) }
  }

  const handleVerifyOtp = async () => {
    const otpStr = otp.join('')
    if (otpStr.length < 6) { setError('Enter complete OTP'); return }
    setError('')
    setLoading(true)
    try {
      await api.post('/auth/verify-otp', { phone, email, otp: otpStr, role: config.role })
      setStep('details')
    } catch (e) {
      setError(e.response?.data?.detail || 'Invalid OTP')
    } finally { setLoading(false) }
  }

  const handleCompleteReg = async () => {
    if (!name || !address || !pincode) { setError('Please fill all fields'); return }
    setError('')
    setLoading(true)
    try {
      const res = await api.post('/auth/complete-registration', {
        phone, email, name, address, pincode, role: config.role
      })
      login(res.data)
      navigate(config.dashPath)
    } catch (e) {
      setError(e.response?.data?.detail || 'Registration failed')
    } finally { setLoading(false) }
  }

  const handleOtpInput = (val, idx) => {
    const newOtp = [...otp]
    newOtp[idx] = val.slice(-1)
    setOtp(newOtp)
    if (val && idx < 5) document.getElementById(`otp-${idx + 1}`)?.focus()
  }

  const handleOtpKeyDown = (e, idx) => {
    if (e.key === 'Backspace' && !otp[idx] && idx > 0) {
      document.getElementById(`otp-${idx - 1}`)?.focus()
    }
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', paddingTop: 64 }}>
      {/* Left side - illustration + text */}
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        {/* Image placeholder */}
        <div style={{
          width: 380, height: 280, background: '#f0f4ff',
          borderRadius: 12, border: '2px dashed #c5d5f0',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#90a4c8', fontSize: 15, marginBottom: 32
        }}>
          {/* image */}
        </div>
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          {step === 'register' ? config.title : config.otpTitle}
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          {step === 'register' ? config.subtitle : config.otpSubtitle}
        </p>
      </div>

      {/* Right side - form */}
      <div style={{
        width: 520, display: 'flex', alignItems: 'center',
        justifyContent: 'center', padding: 40
      }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          {step === 'register' && (
            <>
              <h2 style={{ fontWeight: 700, fontSize: 24, marginBottom: 8 }}>Register Your Account</h2>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>
                We'll send you a verification code to confirm your details
              </p>
              {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13 }}>{error}</div>}
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Phone Number</label>
                <input
                  className="input-field"
                  placeholder="Enter your number"
                  value={phone}
                  onChange={e => setPhone(e.target.value)}
                  type="tel"
                />
              </div>
              <div style={{ marginBottom: 24 }}>
                <label style={labelStyle}>Email address</label>
                <input
                  className="input-field"
                  placeholder="Youremail@mail.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  type="email"
                />
              </div>
              <button className="btn-primary" onClick={handleSendOtp} disabled={loading}>
                {loading ? 'Sending...' : 'Continue'}
              </button>
              <p style={{ textAlign: 'center', marginTop: 16, fontSize: 13, color: '#888' }}>
                Already have an account - <span
                  style={{ color: '#1565C0', cursor: 'pointer', fontWeight: 600 }}
                  onClick={() => navigate(`/${portal}/login`)}
                >login</span>
              </p>
              <p style={{ textAlign: 'center', marginTop: 12, fontWeight: 600, color: '#555', fontSize: 13 }}>
                Join and earn with us!
              </p>
            </>
          )}

          {step === 'otp' && (
            <>
              <h2 style={{ fontWeight: 700, fontSize: 24, marginBottom: 8 }}>Enter OTP</h2>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>
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
                  <input
                    key={idx}
                    id={`otp-${idx}`}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={digit}
                    onChange={e => handleOtpInput(e.target.value, idx)}
                    onKeyDown={e => handleOtpKeyDown(e, idx)}
                    style={{
                      width: 50, height: 56, textAlign: 'center',
                      fontSize: 22, fontWeight: 700,
                      border: '1.5px solid #ddd', borderRadius: 10,
                      outline: 'none', background: '#fff'
                    }}
                  />
                ))}
              </div>
              <p style={{ textAlign: 'center', marginBottom: 20, fontSize: 13 }}>
                <span style={{ color: '#888' }}>Didn't receive code? </span>
                <span
                  style={{ color: '#1565C0', cursor: 'pointer', fontWeight: 600 }}
                  onClick={handleSendOtp}
                >Resend OTP</span>
              </p>
              <button className="btn-primary" onClick={handleVerifyOtp} disabled={loading}>
                {loading ? 'Verifying...' : 'Verify OTP'}
              </button>
            </>
          )}

          {step === 'details' && (
            <>
              <h2 style={{ fontWeight: 700, fontSize: 24, marginBottom: 8 }}>Add Your Details</h2>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>
                Add your details for creating your account
              </p>
              {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13 }}>{error}</div>}
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Your Name</label>
                <input className="input-field" placeholder="your name" value={name} onChange={e => setName(e.target.value)} />
              </div>
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Address</label>
                <input className="input-field" placeholder="address of your shop" value={address} onChange={e => setAddress(e.target.value)} />
              </div>
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Enter your Pincode</label>
                <input className="input-field" placeholder="Pincode" value={pincode} onChange={e => setPincode(e.target.value)} />
              </div>
              <button
                style={{
                  width: '100%', padding: '13px', border: '1.5px solid #ccc',
                  borderRadius: 8, background: '#fff', fontSize: 14, marginBottom: 16,
                  cursor: 'pointer', fontFamily: 'Poppins', color: '#555'
                }}
              >
                📍 Use my current location
              </button>
              <button className="btn-primary" onClick={handleCompleteReg} disabled={loading}>
                {loading ? 'Creating account...' : 'Continue'}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

const labelStyle = {
  display: 'block',
  fontSize: 13,
  fontWeight: 600,
  color: '#444',
  marginBottom: 8
}

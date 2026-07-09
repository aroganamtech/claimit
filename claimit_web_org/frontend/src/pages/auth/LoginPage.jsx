import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import api from '../../utils/api'

const PORTAL_CONFIG = {
  advertiser: { role: 'advertiser', dashPath: '/advertiser/dashboard', label: 'Advertiser' },
  sales: { role: 'sales', dashPath: '/sales/dashboard', label: 'Sales / Affiliate' },
  shop: { role: 'shop', dashPath: '/shop/dashboard', label: 'Shop Owner' },
}

export default function LoginPage({ portal }) {
  const config = PORTAL_CONFIG[portal] || PORTAL_CONFIG.advertiser
  const navigate = useNavigate()
  const { login } = useAuth()
  const [phone, setPhone] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async () => {
    if (!phone) { setError('Enter phone number'); return }
    setError('')
    setLoading(true)
    try {
      const data = await api.auth.login({ phone, role: config.role })
      login(data)
      navigate(config.dashPath)
    } catch (e) {
      setError(e.response?.data?.detail || 'Login failed')
    } finally { setLoading(false) }
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center',
      justifyContent: 'center', background: '#f0f4ff', paddingTop: 64
    }}>
      <div className="login-card">
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            width: 56, height: 56, borderRadius: '50%',
            background: '#1565C0',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 16px', fontSize: 24, fontWeight: 700, color: '#fff', fontStyle: 'italic'
          }}>c</div>
          <h2 style={{ fontWeight: 700, fontSize: 22 }}>Login to Claimit</h2>
          <p style={{ color: '#888', fontSize: 13, marginTop: 4 }}>{config.label} Portal</p>
        </div>
        {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13, textAlign: 'center' }}>{error}</div>}
        <div style={{ marginBottom: 20 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }}>
            Phone Number
          </label>
          <input
            className="input-field"
            placeholder="Enter your registered phone number"
            value={phone}
            onChange={e => setPhone(e.target.value)}
            type="tel"
            onKeyDown={e => e.key === 'Enter' && handleLogin()}
          />
        </div>
        <button className="btn-primary" onClick={handleLogin} disabled={loading}>
          {loading ? 'Logging in...' : 'Login'}
        </button>
        <p style={{ textAlign: 'center', marginTop: 16, fontSize: 13, color: '#888' }}>
          Don't have an account?{' '}
          <span
            style={{ color: '#1565C0', cursor: 'pointer', fontWeight: 600 }}
            onClick={() => navigate(`/${portal}/auth`)}
          >Register</span>
        </p>
      </div>
    </div>
  )
}

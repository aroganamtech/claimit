import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

export default function AdminLogin() {
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleLogin = async () => {
    if (!username || !password) {
      setError('Please enter username and password')
      return
    }
    setError(''); setLoading(true)
    try {
      const data = await api.admin.login({ username, password })
      localStorage.setItem('claimit_admin_token', data.access_token)
      localStorage.setItem('claimit_admin_user', data.username)
      navigate('/admin/dashboard')
    } catch (e) {
      setError(e.response?.data?.detail || 'Login failed')
    } finally { setLoading(false) }
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #1a237e 0%, #0d47a1 100%)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <div style={{
        background: '#fff', borderRadius: 16, padding: 48,
        width: 420, boxShadow: '0 8px 32px rgba(0,0,0,0.25)',
      }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            width: 64, height: 64, borderRadius: '50%',
            background: '#1a237e', margin: '0 auto 12px',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 28, color: '#fff', fontWeight: 700,
          }}>🛡</div>
          <h2 style={{ fontWeight: 700, fontSize: 24 }}>Admin Panel</h2>
          <p style={{ color: '#888', fontSize: 13, marginTop: 4 }}>Claimit administration</p>
        </div>

        {error && (
          <div style={{ background: '#ffebee', color: '#c62828', borderRadius: 8, padding: '8px 12px', fontSize: 13, marginBottom: 12 }}>
            {error}
          </div>
        )}

        <label style={lbl}>Username</label>
        <input className="input-field" value={username} onChange={e => setUsername(e.target.value)} />
        <div style={{ height: 16 }} />
        <label style={lbl}>Password</label>
        <input className="input-field" type="password" value={password} onChange={e => setPassword(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleLogin()} />
        <div style={{ height: 24 }} />
        <button className="btn-primary" onClick={handleLogin} disabled={loading}>
          {loading ? 'Signing in...' : 'Sign In'}
        </button>
        <p style={{ textAlign: 'center', fontSize: 12, color: '#aaa', marginTop: 16 }}>
          Default: admin / admin123 (change in backend .env)
        </p>
      </div>
    </div>
  )
}

const lbl = { display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }

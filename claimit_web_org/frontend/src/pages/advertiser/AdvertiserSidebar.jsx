import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { useState } from 'react'
import api from '../../utils/api'

const NAV_ITEMS = [
  { label: 'Dashboard', icon: '⊞', path: '/advertiser/dashboard' },
  { label: 'Create Ad', icon: '≡', path: '/advertiser/create-ad' },
  { label: 'Transaction History', icon: '⊙', path: '/advertiser/transactions' },
  { label: 'Help & Support', icon: '⊙', path: '/advertiser/support' },
]

export default function AdvertiserSidebar() {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()
  const [deleting, setDeleting] = useState(false)

  const handleDeleteAccount = async () => {
    if (!confirm('Delete your account? This will permanently remove your account and all your ads. This cannot be undone.')) return
    setDeleting(true)
    try {
      await api.auth.deleteAccount()
      logout()
      navigate('/')
    } catch (e) {
      alert(e?.response?.data?.detail || 'Failed to delete account')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <aside className="sidebar">
      {/* User Profile */}
      <div style={{
        padding: '20px',
        borderBottom: '1px solid #eee',
        display: 'flex', alignItems: 'center', gap: 12
      }}>
        <div style={{
          width: 44, height: 44, borderRadius: '50%',
          background: '#ffd0d0',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 18, fontWeight: 700, color: '#c44'
        }}>
          {user?.name?.[0]?.toUpperCase() || 'U'}
        </div>
        <div>
          <div style={{ fontWeight: 600, fontSize: 14 }}>{user?.name || ''}</div>
          <div style={{ fontSize: 12, color: '#888' }}>Advertiser</div>
        </div>
      </div>

      {/* Nav */}
      <nav style={{ padding: '8px 0' }}>
        {NAV_ITEMS.map(item => (
          <button
            key={item.path}
            className={`nav-item ${location.pathname === item.path ? 'active' : ''}`}
            onClick={() => navigate(item.path)}
          >
            <span style={{ fontSize: 16 }}>{item.icon}</span>
            {item.label}
          </button>
        ))}
      </nav>

      <div style={{ marginTop: 'auto', padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <button
          onClick={() => { logout(); navigate('/') }}
          style={{
            width: '100%', padding: '10px', border: '1px solid #eee',
            borderRadius: 8, background: '#fff', color: '#e53935',
            fontSize: 13, cursor: 'pointer', fontFamily: 'Poppins'
          }}
        >
          Logout
        </button>
        <button
          onClick={handleDeleteAccount}
          disabled={deleting}
          style={{
            width: '100%', padding: '10px', border: '1px solid #ffcdd2',
            borderRadius: 8, background: '#fff3f3', color: '#b71c1c',
            fontSize: 12, cursor: 'pointer', fontFamily: 'Poppins',
            opacity: deleting ? 0.6 : 1,
          }}
        >
          {deleting ? 'Deleting...' : '🗑 Delete Account'}
        </button>
      </div>
    </aside>
  )
}

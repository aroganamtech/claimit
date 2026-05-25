import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { useState, useEffect } from 'react'
import api from '../../utils/api'

const NAV_ITEMS = [
  { label: 'Dashboard', icon: '⊞', path: '/sales/dashboard' },
  { label: 'Tutorial Zone', icon: '≡', path: '/sales/tutorials' },
  { label: 'Your Team', icon: '↗', path: '/sales/team' },
  { label: 'Earning', icon: '⊟', path: '/sales/earning' },
  { label: 'Help & Support', icon: '?', path: '/sales/support' },
  { label: 'Settings', icon: '⊙', path: '/sales/settings' },
]

export default function SalesSidebar() {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()
  const [profile, setProfile] = useState(null)

  useEffect(() => {
    api.sales.getProfile().then(setProfile).catch(() => setProfile(null))
  }, [])

  return (
    <aside className="sidebar">
      <div style={{ padding: '20px', borderBottom: '1px solid #eee', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 44, height: 44, borderRadius: '50%',
          background: '#ffd0d0',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 18, fontWeight: 700, color: '#c44'
        }}>
          {user?.name?.[0]?.toUpperCase() || 'D'}
        </div>
        <div>
          <div style={{ fontWeight: 600, fontSize: 14 }}>{user?.name || ''}</div>
          <div style={{ fontSize: 12, color: '#888' }}>User Id : {profile?.user_id || '—'}</div>
        </div>
      </div>

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

      <div style={{ marginTop: 'auto', padding: 16 }}>
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
      </div>
    </aside>
  )
}

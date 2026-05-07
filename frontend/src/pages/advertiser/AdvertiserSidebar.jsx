import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'

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
          <div style={{ fontWeight: 600, fontSize: 14 }}>{user?.name || 'Woned Digital studio'}</div>
          <div style={{ fontSize: 12, color: '#888' }}>Graphic designer</div>
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

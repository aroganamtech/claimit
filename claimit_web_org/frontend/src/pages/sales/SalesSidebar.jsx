import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { useState, useEffect } from 'react'
import api from '../../utils/api'

const SUB_ROLE_LABEL = {
  sales_head:             'Sales Head',
  sales_executive:        'Sales Executive',
  advertising_executive:  'Advertising Executive',
  freelancer:             'Freelancer',
}

const NAV_ITEMS = [
  { label: 'Dashboard',     icon: '⊞', path: '/sales/dashboard' },
  { label: 'Tutorial Zone', icon: '≡', path: '/sales/tutorials' },
  { label: 'Your Team',     icon: '👥', path: '/sales/team' },
  { label: 'Earning',       icon: '₹', path: '/sales/earning' },
  { label: 'Help & Support',icon: '?', path: '/sales/support' },
  { label: 'Settings',      icon: '⊙', path: '/sales/settings' },
]

export default function SalesSidebar() {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()
  const [profile, setProfile] = useState(null)
  const [deleting, setDeleting] = useState(false)

  const handleDeleteAccount = async () => {
    if (!confirm('Delete your account? This will permanently remove your account and all associated data. This cannot be undone.')) return
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

  useEffect(() => {
    api.sales.getProfile().then(setProfile).catch(() => {})
  }, [])

  const uniqueId  = profile?.unique_id || '—'
  const subRole   = profile?.sub_role  || ''
  const roleLabel = SUB_ROLE_LABEL[subRole] || 'Sales'

  return (
    <aside className="sidebar">
      <div style={{ padding: '20px 16px', borderBottom: '1px solid #eee' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
          <div style={{
            width: 44, height: 44, borderRadius: '50%', background: '#1565C0',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 18, fontWeight: 700, color: '#fff', flexShrink: 0
          }}>
            {user?.name?.[0]?.toUpperCase() || 'S'}
          </div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: 14, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {user?.name || ''}
            </div>
            <div style={{ fontSize: 11, color: '#1565C0', fontWeight: 600 }}>{roleLabel}</div>
          </div>
        </div>
        <div style={{
          background: 'linear-gradient(135deg, #1565C0, #1976D2)',
          borderRadius: 10, padding: '12px 14px', color: '#fff'
        }}>
          <div style={{ fontSize: 10, opacity: 0.8, marginBottom: 4, letterSpacing: 0.5 }}>YOUR UNIQUE ID</div>
          <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: 1 }}>{uniqueId}</div>
          <div style={{ fontSize: 10, opacity: 0.7, marginTop: 4 }}>Enter this ID for every sale you close</div>
        </div>
      </div>

      <nav style={{ padding: '8px 0', flex: 1 }}>
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

      <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <button
          onClick={() => { logout(); navigate('/') }}
          style={{
            width: '100%', padding: '10px', border: '1px solid #eee',
            borderRadius: 8, background: '#fff', color: '#e53935',
            fontSize: 13, cursor: 'pointer', fontFamily: 'Poppins'
          }}
        >Logout</button>
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

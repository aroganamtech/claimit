import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { useState, useEffect } from 'react'
import api from '../../utils/api'

function useDeleteAccount(logout, navigate) {
  const [deleting, setDeleting] = useState(false)
  const handleDeleteAccount = async () => {
    if (!confirm('Delete your account? This will permanently remove your account and your shop. This cannot be undone.')) return
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
  return { deleting, handleDeleteAccount }
}

const NAV_ITEMS = [
  { label: 'Dashboard', icon: '⊞', path: '/shop/dashboard' },
  { label: 'Offer management', icon: '⚙', path: '/shop/offer' },
  { label: 'Store Details Management', icon: '≡', path: '/shop/store-details' },
  { label: 'Ratings & reviews', icon: '⊟', path: '/shop/ratings' },
  { label: 'Help & Support', icon: '?', path: '/shop/support' },
  { label: 'Settings', icon: '⊙', path: '/shop/settings' },
]

export default function ShopSidebar() {
  const navigate = useNavigate()
  const location = useLocation()
  const { logout, user } = useAuth()
  const [shopName, setShopName] = useState('')
  const [shopType, setShopType] = useState('')
  const { deleting, handleDeleteAccount } = useDeleteAccount(logout, navigate)

  useEffect(() => {
    api.shop.getStoreDetails().then(d => {
      setShopName(d?.shop_name || user?.name || '')
      setShopType((d?.shop_type || '').toLowerCase())
    }).catch(() => setShopName(user?.name || ''))
  }, [user])

  // Offer management (discount %) is a REDEEM-shop feature only —
  // Reward shops give free reward points + 1% cashback, no discount.
  const navItems = NAV_ITEMS.filter(item =>
    item.path !== '/shop/offer' || shopType.startsWith('redeem'))

  return (
    <aside className="sidebar">
      <div style={{ padding: '20px', borderBottom: '1px solid #eee', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 44, height: 44, borderRadius: '50%',
          background: '#ffd0d0',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 18, fontWeight: 700, color: '#c44'
        }}>
          {shopName?.[0]?.toUpperCase() || 'S'}
        </div>
        <div style={{ fontWeight: 600, fontSize: 13, lineHeight: 1.3 }}>{shopName}</div>
      </div>

      <nav style={{ padding: '8px 0' }}>
        {navItems.map(item => (
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

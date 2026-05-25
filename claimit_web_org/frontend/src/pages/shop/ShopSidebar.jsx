import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { useState, useEffect } from 'react'
import api from '../../utils/api'

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

  useEffect(() => {
    api.shop.getStoreDetails().then(d => {
      setShopName(d?.shop_name || user?.name || '')
    }).catch(() => setShopName(user?.name || ''))
  }, [user])

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

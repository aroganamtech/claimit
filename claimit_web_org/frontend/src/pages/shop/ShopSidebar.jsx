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
  const [shops, setShops] = useState([])
  const [activeId, setActiveId] = useState(localStorage.getItem('claimit_active_shop') || '')
  const { deleting, handleDeleteAccount } = useDeleteAccount(logout, navigate)

  // Load all shops this user owns (for the switcher). If no active shop is
  // chosen yet, default to the first one and reload once so every screen
  // fetches that shop's data consistently.
  useEffect(() => {
    api.shop.listShops().then(list => {
      list = list || []
      setShops(list)
      const cur = localStorage.getItem('claimit_active_shop')
      const ids = list.map(s => s.id)
      if (list.length) {
        // No selection yet, or a stale id (e.g. left over from another
        // account) that isn't one of this user's shops → default to first.
        if (!cur || !ids.includes(cur)) {
          localStorage.setItem('claimit_active_shop', list[0].id)
          window.location.reload()
          return
        }
        setActiveId(cur)
      } else {
        // User has no shops — drop any stale selection.
        if (cur) localStorage.removeItem('claimit_active_shop')
        setActiveId('')
      }
    }).catch(() => setShops([]))
  }, [])

  const switchShop = (id) => {
    if (!id || id === activeId) return
    localStorage.setItem('claimit_active_shop', id)
    window.location.reload()   // refetch every screen for the newly selected shop
  }

  const addShop = () => {
    // Start the onboarding wizard again — registration now creates a NEW shop.
    navigate('/shop/onboard')
  }

  useEffect(() => {
    api.shop.getStoreDetails().then(d => {
      setShopName(d?.shop_name || user?.name || '')
      setShopType((d?.shop_type || '').toLowerCase())
    }).catch(() => setShopName(user?.name || ''))
  }, [user, activeId])

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

      {/* Shop switcher — lets a multi-shop owner pick which shop to manage */}
      <div style={{ padding: '12px 16px', borderBottom: '1px solid #eee' }}>
        {shops.length > 1 && (
          <select
            value={activeId}
            onChange={(e) => switchShop(e.target.value)}
            style={{
              width: '100%', padding: '9px 10px', borderRadius: 8,
              border: '1px solid #ddd', fontSize: 13, fontFamily: 'Poppins',
              background: '#fafafa', cursor: 'pointer', marginBottom: 8,
            }}
          >
            {shops.map(s => (
              <option key={s.id} value={s.id}>
                {s.shop_name || 'Unnamed shop'}{s.location ? ` — ${s.location}` : ''}
              </option>
            ))}
          </select>
        )}
        <button
          onClick={addShop}
          style={{
            width: '100%', padding: '9px', border: '1px dashed #1565C0',
            borderRadius: 8, background: '#f4f8ff', color: '#1565C0',
            fontSize: 13, fontWeight: 600, cursor: 'pointer', fontFamily: 'Poppins',
          }}
        >
          + Add another shop
        </button>
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

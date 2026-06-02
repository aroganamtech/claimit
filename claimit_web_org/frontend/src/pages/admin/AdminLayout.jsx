import { useNavigate, useLocation, Outlet } from 'react-router-dom'

const NAV = [
  { label: 'Overview',    icon: '📊', path: '/admin/dashboard' },
  { label: 'Users',       icon: '👥', path: '/admin/users' },
  { label: 'Ads',         icon: '📢', path: '/admin/ads' },
  { label: 'Shops',       icon: '🏪', path: '/admin/shops' },
  { label: 'Reviews',     icon: '⭐', path: '/admin/reviews' },
  { label: 'Tickets',     icon: '🎫', path: '/admin/tickets' },
  { label: 'Sales Team',  icon: '🏅', path: '/admin/sales-team' },
  { label: 'Bill Reviews',icon: '🧾', path: '/admin/bill-reviews' },
  { label: 'Project PDFs',icon: '📄', path: '/admin/pdfs' },
]

export default function AdminLayout() {
  const navigate = useNavigate()
  const location = useLocation()

  const logout = () => {
    localStorage.removeItem('claimit_admin_token')
    localStorage.removeItem('claimit_admin_user')
    navigate('/admin')
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#F4F6FA' }}>
      {/* Sidebar */}
      <aside style={{
        width: 240, background: '#1a237e', color: '#fff',
        display: 'flex', flexDirection: 'column',
        position: 'fixed', top: 0, left: 0, bottom: 0,
      }}>
        <div style={{ padding: '20px 22px', borderBottom: '1px solid rgba(255,255,255,0.15)' }}>
          <div style={{ fontWeight: 700, fontSize: 18, letterSpacing: 1 }}>claimit</div>
          <div style={{ fontSize: 11, opacity: 0.7, letterSpacing: 2 }}>ADMIN PANEL</div>
        </div>
        <nav style={{ padding: '8px 0', flex: 1 }}>
          {NAV.map(it => (
            <button
              key={it.path}
              onClick={() => navigate(it.path)}
              style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 22px', width: '100%', textAlign: 'left',
                border: 'none', background: location.pathname === it.path
                  ? 'rgba(255,255,255,0.18)' : 'transparent',
                color: '#fff', fontSize: 14, cursor: 'pointer',
                fontFamily: 'Poppins',
              }}
            >
              <span style={{ fontSize: 16 }}>{it.icon}</span>
              {it.label}
            </button>
          ))}
        </nav>
        <div style={{ padding: 16, borderTop: '1px solid rgba(255,255,255,0.15)' }}>
          <button onClick={logout} style={{
            width: '100%', padding: 10, background: 'rgba(255,255,255,0.12)',
            color: '#fff', border: '1px solid rgba(255,255,255,0.25)',
            borderRadius: 8, cursor: 'pointer', fontFamily: 'Poppins', fontSize: 13,
          }}>
            Logout
          </button>
        </div>
      </aside>

      <main style={{ marginLeft: 240, flex: 1, padding: 32 }}>
        <Outlet />
      </main>
    </div>
  )
}

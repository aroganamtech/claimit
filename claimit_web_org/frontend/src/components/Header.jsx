import { useState, useRef, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import img from '../../public/assets/logo_home.png'

export default function Header() {
  const { user, role, logout } = useAuth()
  const [showLoginMenu, setShowLoginMenu] = useState(false)
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [showUserMenu, setShowUserMenu] = useState(false)
  const menuRef = useRef(null)
  const navigate = useNavigate()

  useEffect(() => {
    function handleClick(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setShowLoginMenu(false)
        setShowUserMenu(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const handleLogout = () => {
    logout()
    navigate('/')
  }

  const portals = [
    { label: 'Business Registration', role: 'shop', path: '/shop/auth' },
    { label: 'Advertisements Upload', role: 'advertiser', path: '/advertiser/auth' },
    // { label: 'Business Associate', role: 'shop', path: '/shop/auth' },
    { label: 'Sales Team/Executives', role: 'sales', path: '/sales/auth' },
    {label: 'Admin' , role:'sales',path:'/admin'}
  ]

  const getDashboardPath = () => {
    if (role === 'advertiser') return '/advertiser/dashboard'
    if (role === 'sales') return '/sales/dashboard'
    if (role === 'shop') return '/shop/dashboard'
    return '/'
  }

  return (
    <header style={{
      position: 'fixed', top: 0, left: 0, right: 0, zIndex: 1000,
      background: '#1565C0', height: 64,
      display: 'flex', alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 32px',
      boxShadow: '0 2px 8px rgba(0,0,0,0.15)'
    }}>
      {/* Logo */}
      <div
        // onClick={() => navigate('/')}
        style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10 }}
      >
        <div>
          <img style={{
            width: '100%', height: 40
          }} src={img}></img>
        </div>
        {/* <div style={{
          width: 40, height: 40, borderRadius: '50%',
          background: '#F5A623',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontWeight: 700, fontSize: 18, color: '#fff', fontStyle: 'italic'
        }}>c</div> */}
        {/* <div>
          <div style={{ }}>claimit</div>
          <div style={{ color: 'rgba(255,255,255,0.7)', fontSize: 9, letterSpacing: 2, marginTop: -2 }}>REWARDS. DISCOUNTS. CASHBACKS</div>
        </div> */}
      </div>

      {/* Nav Links */}
      <nav className="header-nav" style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
        {/* {['About us', 'Why claimIT', 'Features', 'Contact us'].map(item => (
          <a key={item} href="#" style={{ color: 'rgba(255,255,255,0.9)', fontSize: 13, fontWeight: 400, textDecoration: 'none' }}>{item}</a>
        ))} */}

        {/* Login / User Button */}
        <div ref={menuRef} style={{ position: 'relative' }}>
          {user ? (
            <>
              <button
                onClick={() => setShowUserMenu(!showUserMenu)}
                style={{
                  background: 'rgba(255,255,255,0.15)',
                  border: '1.5px solid rgba(255,255,255,0.4)',
                  borderRadius: 8,
                  color: '#fff',
                  padding: '7px 16px',
                  fontSize: 13,
                  fontWeight: 600,
                  cursor: 'pointer',
                  display: 'flex', alignItems: 'center', gap: 8
                }}
              >
                <div style={{
                  width: 26, height: 26, borderRadius: '50%',
                  background: '#F5A623',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 12, fontWeight: 700
                }}>
                  {user.name?.[0]?.toUpperCase() || 'U'}
                </div>
                {user.name}
              </button>
              {showUserMenu && (
                <div style={{
                  position: 'absolute', right: 0, top: '110%',
                  background: '#fff', borderRadius: 10,
                  boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
                  minWidth: 180, zIndex: 999, overflow: 'hidden'
                }}>
                  <button
                    onClick={() => { navigate(getDashboardPath()); setShowUserMenu(false) }}
                    style={{ ...menuItemStyle }}
                  >Dashboard</button>
                  <button onClick={handleLogout} style={{ ...menuItemStyle, color: '#e53935' }}>
                    Logout
                  </button>
                </div>
              )}
            </>
          ) : (
            <>
              <button
                onClick={() => setShowLoginMenu(!showLoginMenu)}
                style={{
                  background: '#fff',
                  border: 'none',
                  borderRadius: 8,
                  color: '#1565C0',
                  padding: '8px 20px',
                  fontSize: 13,
                  fontWeight: 700,
                  cursor: 'pointer',
                  boxShadow: '0 2px 6px rgba(0,0,0,0.1)'
                }}
              >
                Login ▾
              </button>
              {showLoginMenu && (
                <div style={{
                  position: 'absolute', right: 0, top: '110%',
                  background: '#fff', borderRadius: 10,
                  boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
                  minWidth: 220, zIndex: 999, overflow: 'hidden'
                }}>
                  {portals.map((p) => (
                    <button
                      key={p.label}
                      onClick={() => { navigate(p.path); setShowLoginMenu(false) }}
                      style={{ ...menuItemStyle }}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </nav>

      {/* Hamburger — mobile only (CSS hides it on desktop) */}
      <button className="header-burger" onClick={() => setDrawerOpen(true)} aria-label="Menu">☰</button>

      {/* Mobile drawer */}
      {drawerOpen && (
        <>
          <div className="drawer-backdrop" onClick={() => setDrawerOpen(false)} />
          <aside className="mobile-drawer">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontWeight: 700, fontSize: 16, color: '#1565C0' }}>Menu</span>
              <button onClick={() => setDrawerOpen(false)}
                style={{ background: 'none', border: 'none', fontSize: 22, cursor: 'pointer', color: '#555' }}>✕</button>
            </div>
            {['About us', 'Why claimIT', 'Features', 'Contact us'].map(item => (
              <a key={item} href="#" onClick={() => setDrawerOpen(false)}
                style={{ padding: '12px 4px', color: '#333', fontSize: 14, textDecoration: 'none', borderBottom: '1px solid #f0f0f0' }}>
                {item}
              </a>
            ))}
            <div style={{ height: 16 }} />
            {user ? (
              <>
                <button style={drawerBtnStyle}
                  onClick={() => { navigate(getDashboardPath()); setDrawerOpen(false) }}>Dashboard</button>
                <button style={{ ...drawerBtnStyle, color: '#e53935', borderColor: '#ffcdd2' }}
                  onClick={() => { setDrawerOpen(false); handleLogout() }}>Logout</button>
              </>
            ) : (
              <>
                <div style={{ fontWeight: 600, fontSize: 13, color: '#888', margin: '4px 0 8px' }}>Login / Register</div>
                {portals.map(p => (
                  <button key={p.label} style={drawerBtnStyle}
                    onClick={() => { navigate(p.path); setDrawerOpen(false) }}>{p.label}</button>
                ))}
              </>
            )}
          </aside>
        </>
      )}
    </header>
  )
}

const drawerBtnStyle = {
  width: '100%',
  padding: '12px 14px',
  marginBottom: 8,
  background: '#fff',
  border: '1.5px solid #dbe4f0',
  borderRadius: 10,
  textAlign: 'left',
  fontSize: 14,
  fontWeight: 600,
  color: '#1565C0',
  cursor: 'pointer',
  fontFamily: 'Poppins, sans-serif',
}

const menuItemStyle = {
  display: 'block',
  width: '100%',
  padding: '12px 16px',
  background: 'none',
  border: 'none',
  textAlign: 'left',
  fontSize: 14,
  color: '#333',
  cursor: 'pointer',
  fontFamily: 'Poppins, sans-serif',
  fontWeight: 500,
  transition: 'background 0.15s',
}

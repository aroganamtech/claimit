import { useState, useRef, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function Header() {
  const { user, role, logout } = useAuth()
  const [showLoginMenu, setShowLoginMenu] = useState(false)
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
    { label: 'L1 - Advertiser Portal', role: 'advertiser', path: '/advertiser/auth' },
    { label: 'L2 - Sales Portal', role: 'sales', path: '/sales/auth' },
    { label: 'L3 - Shop Portal', role: 'shop', path: '/shop/auth' },
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
        onClick={() => navigate('/')}
        style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10 }}
      >
        <div style={{
          width: 40, height: 40, borderRadius: '50%',
          background: '#F5A623',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontWeight: 700, fontSize: 18, color: '#fff', fontStyle: 'italic'
        }}>c</div>
        <div>
          <div style={{ color: '#fff', fontWeight: 700, fontSize: 20, letterSpacing: 1 }}>claimit</div>
          <div style={{ color: 'rgba(255,255,255,0.7)', fontSize: 9, letterSpacing: 2, marginTop: -2 }}>REWARDS. DISCOUNTS. CASHBACKS</div>
        </div>
      </div>

      {/* Nav Links */}
      <nav style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
        {['Help Centre', 'Support', 'Terms of Service', 'Privacy Policy'].map(item => (
          <a key={item} href="#" style={{ color: 'rgba(255,255,255,0.9)', fontSize: 13, fontWeight: 400 }}>{item}</a>
        ))}

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
                  <div style={{ padding: '10px 16px 6px', fontSize: 11, color: '#888', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>
                    Select Portal
                  </div>
                  {portals.map((p) => (
                    <button
                      key={p.role}
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
    </header>
  )
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

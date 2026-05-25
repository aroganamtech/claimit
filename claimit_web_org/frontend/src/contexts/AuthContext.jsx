import { createContext, useContext, useState, useEffect } from 'react'
import api from '../utils/api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [token, setToken] = useState(localStorage.getItem('claimit_token'))
  const [role, setRole] = useState(localStorage.getItem('claimit_role'))
  const [loading, setLoading] = useState(false)

  // On reload, restore session from localStorage and re-validate against backend.
  useEffect(() => {
    const t = localStorage.getItem('claimit_token')
    const r = localStorage.getItem('claimit_role')
    const u = localStorage.getItem('claimit_user')
    if (t && r && u) {
      setToken(t)
      setRole(r)
      try { setUser(JSON.parse(u)) } catch {}
      // Quietly verify the token is still valid; if not, the 401 interceptor
      // in api.js will clear localStorage and bounce to /.
      api.auth.me().catch(() => {})
    }
  }, [])

  const login = (tokenData) => {
    const email = tokenData.email || ''
    localStorage.setItem('claimit_token', tokenData.access_token)
    localStorage.setItem('claimit_role', tokenData.role)
    // Store email separately for easy access by API calls
    localStorage.setItem('claimit_email', email)
    localStorage.setItem('claimit_user', JSON.stringify({
      id: tokenData.user_id,
      name: tokenData.name,
      role: tokenData.role,
      email,
    }))
    setToken(tokenData.access_token)
    setRole(tokenData.role)
    setUser({ id: tokenData.user_id, name: tokenData.name, role: tokenData.role, email })
  }

  const logout = () => {
    localStorage.removeItem('claimit_token')
    localStorage.removeItem('claimit_role')
    localStorage.removeItem('claimit_email')
    localStorage.removeItem('claimit_user')
    setToken(null)
    setRole(null)
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, token, role, login, logout, loading, setLoading }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)

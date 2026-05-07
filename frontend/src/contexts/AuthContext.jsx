import { createContext, useContext, useState, useEffect } from 'react'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [token, setToken] = useState(localStorage.getItem('claimit_token'))
  const [role, setRole] = useState(localStorage.getItem('claimit_role'))
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    const t = localStorage.getItem('claimit_token')
    const r = localStorage.getItem('claimit_role')
    const u = localStorage.getItem('claimit_user')
    if (t && r && u) {
      setToken(t)
      setRole(r)
      setUser(JSON.parse(u))
    }
  }, [])

  const login = (tokenData) => {
    localStorage.setItem('claimit_token', tokenData.access_token)
    localStorage.setItem('claimit_role', tokenData.role)
    localStorage.setItem('claimit_user', JSON.stringify({
      id: tokenData.user_id,
      name: tokenData.name,
      role: tokenData.role
    }))
    setToken(tokenData.access_token)
    setRole(tokenData.role)
    setUser({ id: tokenData.user_id, name: tokenData.name, role: tokenData.role })
  }

  const logout = () => {
    localStorage.removeItem('claimit_token')
    localStorage.removeItem('claimit_role')
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

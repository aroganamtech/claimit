import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('claimit_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('claimit_token')
      localStorage.removeItem('claimit_role')
      localStorage.removeItem('claimit_user')
      window.location.href = '/'
    }
    return Promise.reject(error)
  }
)

export default api

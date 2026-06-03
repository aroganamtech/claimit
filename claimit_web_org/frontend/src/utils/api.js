// ─────────────────────────────────────────────────────────────────
// One place to manage every backend call. Pages NEVER hard-code a
// URL — they call api.<area>.<action>(...). When an endpoint moves,
// you change it here and nowhere else.
//
// Layout:
//   api.auth.*         /api/auth/...
//   api.advertiser.*   /api/advertiser/...
//   api.sales.*        /api/sales/...
//   api.shop.*         /api/shop/...
//   api.support.*      /api/support/...
//   api.geo.*          /api/geo/...
//   api.admin.*        /api/admin/...
//
// Auth state in localStorage: only enough to know WHO is logged in
// (token + a small {id, name, role} record). Every actual data
// read/write goes over the wire to FastAPI → MongoDB.
// ─────────────────────────────────────────────────────────────────
import axios from 'axios'

// In production, set VITE_API_URL to your deployed Vercel backend URL.
// e.g. VITE_API_URL=https://claimit-web-backend.vercel.app/api
// Locally the Vite proxy handles /api → localhost:8000, so no change needed.
const BASE_URL = import.meta.env.VITE_API_URL || '/api'

const http = axios.create({ baseURL: BASE_URL })

// Attach JWT (user or admin) to every request
http.interceptors.request.use((config) => {
  const isAdmin =
    config.url && config.url.startsWith('/admin/') && config.url !== '/admin/login'
  const token = isAdmin
    ? localStorage.getItem('claimit_admin_token')
    : localStorage.getItem('claimit_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Clear session on 401
http.interceptors.response.use(
  (r) => r,
  (error) => {
    if (error.response?.status === 401) {
      const url = error.config?.url || ''
      if (url.startsWith('/admin/')) {
        localStorage.removeItem('claimit_admin_token')
        if (window.location.pathname.startsWith('/admin') &&
            window.location.pathname !== '/admin') {
          window.location.href = '/admin'
        }
      } else {
        localStorage.removeItem('claimit_token')
        localStorage.removeItem('claimit_role')
        localStorage.removeItem('claimit_email')
        localStorage.removeItem('claimit_user')
        if (window.location.pathname !== '/' &&
            !window.location.pathname.startsWith('/admin')) {
          window.location.href = '/'
        }
      }
    }
    return Promise.reject(error)
  }
)

// Helpers that unwrap response.data so callers can do `const x = await api.foo.bar()`
const get  = (url, params)     => http.get(url,  { params }).then(r => r.data)
const post = (url, body, opts) => http.post(url, body, opts).then(r => r.data)
const put  = (url, body)       => http.put(url, body).then(r => r.data)
const del  = (url)             => http.delete(url).then(r => r.data)

// ─── Auth ────────────────────────────────────────────────────
const auth = {
  sendOtp:  (payload) => post('/auth/send-otp', payload),
  verifyOtp:(payload) => post('/auth/verify-otp', payload),
  register: (payload) => post('/auth/complete-registration', payload),
  login:    (payload) => post('/auth/login', payload),
  me:       ()        => get('/auth/me'),
}

// ─── Advertiser ──────────────────────────────────────────────
const advertiser = {
  getDashboard:    ()             => get('/advertiser/dashboard'),
  getAds:          (status='all') => get('/advertiser/ads', { status }),
  createAd:        (formData)     => post('/advertiser/ads/create', formData),
  getTransactions: ()             => get('/advertiser/transactions'),
  getProfile:      ()             => get('/advertiser/profile'),
}

// ─── Sales ───────────────────────────────────────────────────
// Always attach the logged-in user's email so the backend can find shops
// registered through the shop portal under the same email address.
const _salesEmail = () => localStorage.getItem('claimit_email') || undefined

const sales = {
  getDashboard:    ()             => get('/sales/dashboard', { email: _salesEmail() }),
  getAllEmployees:  ()             => get('/sales/all-employees'),
  getShops:     (status='all') => get('/sales/shops', { status, email: _salesEmail() }),
  addShop:      (payload)      => post('/sales/shops/add', payload),
  getTeam:      ()             => get('/sales/team'),
  inviteMember: (payload)      => post('/sales/team/invite', null, { params: payload }),
  getEarnings:  ()             => get('/sales/earnings'),
  getProfile:   ()             => get('/sales/profile'),
}

// ─── Shop ────────────────────────────────────────────────────
const shop = {
  register:           (formData) => post('/shop/register', formData),
  getDashboard:       ()         => get('/shop/dashboard'),
  getOffer:           ()         => get('/shop/offer'),
  setOffer:           (payload)  => put('/shop/offer', payload),
  getStoreDetails:    ()         => get('/shop/store-details'),
  updateStoreDetails: (patch)    => put('/shop/store-details', patch),
  getRatings:         ()         => get('/shop/ratings'),
  addReview:          (payload)  => post('/shop/ratings', payload),
  replyReview:        (payload)  => post('/shop/ratings/reply', payload),
  getSettings:        ()         => get('/shop/settings'),
  // Gallery
  getGallery:         ()           => get('/shop/gallery'),
  updateCoverPhoto:   (payload)    => post('/shop/gallery/cover', payload),
  addGalleryPhoto:    (payload)    => post('/shop/gallery/add', payload),
  deleteGalleryPhoto: (index)      => del(`/shop/gallery/${index}`),
}

// ─── Support ─────────────────────────────────────────────────
const support = {
  getFaqs:      ()        => get('/support/faqs'),
  getMyTickets: ()        => get('/support/tickets'),
  submitTicket: (payload) => post('/support/tickets', payload),
}

// ─── Geo ─────────────────────────────────────────────────────
const geo = {
  reverse: (lat, lng) => post('/geo/reverse', { lat, lng }),
}

// ─── Admin ───────────────────────────────────────────────────
const admin = {
  login:        (payload)   => post('/admin/login', payload),
  stats:        ()          => get('/admin/stats'),
  listUsers:    (role='all') => get('/admin/users', { role }),
  deleteUser:   (id)        => del(`/admin/users/${id}`),
  listAds:      ()          => get('/admin/ads'),
  updateAd:     (id, p)     => put(`/admin/ads/${id}`, p),
  deleteAd:     (id)        => del(`/admin/ads/${id}`),
  listShops:    ()          => get('/admin/shops'),
  updateShop:   (id, p)     => put(`/admin/shops/${id}`, p),
  deleteShop:   (id)        => del(`/admin/shops/${id}`),
  listReviews:  ()          => get('/admin/reviews'),
  deleteReview: (id)        => del(`/admin/reviews/${id}`),
  listTickets:  ()          => get('/admin/tickets'),
  updateTicket: (id, p)     => put(`/admin/tickets/${id}`, p),
  // PDF endpoints return raw bytes; we fetch as a blob so the auth
  // header is attached, then build an object URL for the iframe.
  listPdfs:     ()          => get('/admin/pdfs'),
  getPdfBlob:   (key)       => http.get(`/admin/pdfs/${key}`, { responseType: 'blob' }).then(r => r.data),
  // Bill Reviews — reads claimit_db.bill_manual_reviews (same DB as Flutter app)
  listBillReviews:   (status = 'pending') => get(`/admin/bill-reviews`, { status }),
  actionBillReview:  (id, payload)        => post(`/admin/bill-reviews/${id}/action`, payload),
}

// Default export bundles everything. Pages migrated to the new style
// can `import api` and use api.advertiser.getDashboard(); pages still
// using axios style can fall back to api.get/post/put/delete.
const api = {
  get: (u, c) => http.get(u, c),
  post: (u, b, c) => http.post(u, b, c),
  put: (u, b, c) => http.put(u, b, c),
  delete: (u, c) => http.delete(u, c),
  auth, advertiser, sales, shop, support, geo, admin,
}
export { auth, advertiser, sales, shop, support, geo, admin }
export default api

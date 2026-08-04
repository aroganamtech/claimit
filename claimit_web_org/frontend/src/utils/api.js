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
  sendOtp:       (payload) => post('/auth/send-otp', payload),
  verifyOtp:     (payload) => post('/auth/verify-otp', payload),
  register:      (payload) => post('/auth/complete-registration', payload),
  login:         (payload) => post('/auth/login', payload),
  me:            ()        => get('/auth/me'),
  deleteAccount: ()        => del('/auth/account'),
}

// ─── Advertiser ──────────────────────────────────────────────
const advertiser = {
  getDashboard:    ()             => get('/advertiser/dashboard'),
  getAds:          (status='all') => get('/advertiser/ads', { status }),
  // presignUpload — returns { upload_url, key } for direct browser → S3 upload
  presignUpload:   (payload)      => post('/advertiser/presign-upload', payload),
  // createAd now accepts a plain JSON object (S3 keys, not files)
  createAd:        (payload)      => post('/advertiser/ads/create', payload),
  getTransactions: ()             => get('/advertiser/transactions'),
  getProfile:      ()             => get('/advertiser/profile'),
  // Premium slot availability — { max, used, remaining, location_scoped }
  getPremiumSlots: (adType, pincode='000000') => get('/advertiser/premium-slots', { ad_type: adType, pincode }),
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
// A single user can own MANY shops. The "active" shop the dashboard is
// currently viewing/managing is remembered in localStorage; every management
// call appends it as ?shop_id=... so the backend acts on the right shop.
// (If none is set, the backend falls back to the user's most recent shop.)
const _activeShopId = () => localStorage.getItem('claimit_active_shop') || ''
const _shopQ = () => (_activeShopId() ? `?shop_id=${_activeShopId()}` : '')

const shop = {
  register:           (formData) => post('/shop/register', formData),
  // All shops owned by the current user (for the shop switcher)
  listShops:          ()         => get('/shop/list'),
  getDashboard:       ()         => get(`/shop/dashboard${_shopQ()}`),
  getBillScans:       ()         => get(`/shop/bill-scans${_shopQ()}`),
  getOffer:           ()         => get(`/shop/offer${_shopQ()}`),
  setOffer:           (payload)  => put(`/shop/offer${_shopQ()}`, payload),
  getStoreDetails:    ()         => get(`/shop/store-details${_shopQ()}`),
  updateStoreDetails: (patch)    => put(`/shop/store-details${_shopQ()}`, patch),
  getRatings:         ()         => get(`/shop/ratings${_shopQ()}`),
  addReview:          (payload)  => post('/shop/ratings', payload),
  replyReview:        (payload)  => post('/shop/ratings/reply', payload),
  getSettings:        ()         => get(`/shop/settings${_shopQ()}`),
  // Gallery — base64 path (used by dashboard ShopPages.jsx)
  getGallery:         ()           => get(`/shop/gallery${_shopQ()}`),
  updateCoverPhoto:   (payload)    => post(`/shop/gallery/cover${_shopQ()}`, payload),
  addGalleryPhoto:    (payload)    => post(`/shop/gallery/add${_shopQ()}`, payload),
  deleteGalleryPhoto: (index)      => del(`/shop/gallery/${index}${_shopQ()}`),
  // Presigned-URL path (used by onboarding — same pattern as brand/nearby deals)
  presignImage:       ()           => post('/shop/gallery/presign', {}),
  setCoverPhotoKey:   (payload)    => post(`/shop/gallery/cover-key${_shopQ()}`, payload),
  addGalleryPhotoKey: (payload)    => post(`/shop/gallery/add-key${_shopQ()}`, payload),
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
  // Address dropdown data (India Post-backed)
  getCountries: ()               => get('/geo/countries'),
  getStates:    (country='India') => get('/geo/states', { country }),
  lookupPincode:(pincode)        => get(`/geo/pincode/${pincode}`),
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
  // Bulk shop upload (Excel). Template download returns an .xlsx blob.
  downloadShopTemplate: () =>
    http.get('/admin/shops/bulk-template', { responseType: 'blob' }).then(r => r.data),
  bulkUploadShops: (formData, replace = false) =>
    http.post('/admin/shops/bulk-upload', formData, {
      params: { replace },
      headers: { 'Content-Type': 'multipart/form-data' },
    }).then(r => r.data),
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
  // New-user bonus config
  getAppConfig:      ()       => get('/admin/app-config'),
  updateAppConfig:   (payload) => put('/admin/app-config', payload),
  // Premium ad slot caps (Nearby Deals + Brand Deals)
  getAdSettings:     ()       => get('/admin/ad-settings'),
  updateAdSettings:  (payload) => put('/admin/ad-settings', payload),
  // App Users — real Flutter-app end-customers (claimit_db.users)
  listAppUsers:      ()       => get('/admin/app-users'),
  deleteAppUser:     (id)     => del(`/admin/app-users/${id}`),
  // Feedback / Complaints — full ticket system (claimit_db.feedback)
  listFeedback:      (status='all') => get('/admin/feedback', { status }),
  replyFeedback:     (id, payload)  => post(`/admin/feedback/${id}/reply`, payload),
  deleteFeedback:    (id)           => del(`/admin/feedback/${id}`),
  listDeletedUsers:  ()             => get('/admin/deleted-users'),
  // Admin ad creation (no payment) — mirrors advertiser upload + create flow
  presignUpload:     (payload)      => post('/admin/presign-upload', payload),
  createAd:          (payload)      => post('/admin/ads/create', payload),
}

// ─── Payments (Cashfree Payment Links — advertiser ad bookings) ────
const payments = {
  createLink:  (payload) => post('/payments/create-link', payload),
  checkStatus: (linkId)  => get(`/payments/status/${linkId}`),
}

// ─── App Account Deletion (public — Claimit app end-users, not the web
// portal's own advertiser/sales/shop accounts) ──────────────────────
const appAccount = {
  sendOtp:         (identifier)                  => post('/app-account/send-otp', { identifier }),
  verifyAndDelete: (identifier, otp, confirm)     => post('/app-account/verify-and-delete', { identifier, otp, confirm }),
}

// Default export bundles everything. Pages migrated to the new style
// can `import api` and use api.advertiser.getDashboard(); pages still
// using axios style can fall back to api.get/post/put/delete.
const api = {
  get: (u, c) => http.get(u, c),
  post: (u, b, c) => http.post(u, b, c),
  put: (u, b, c) => http.put(u, b, c),
  delete: (u, c) => http.delete(u, c),
  auth, advertiser, sales, shop, support, geo, admin, payments, appAccount,
}
export { auth, advertiser, sales, shop, support, geo, admin, payments, appAccount }
export default api

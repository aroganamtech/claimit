import { BrowserRouter, Routes, Route, Navigate, useLocation, Link } from 'react-router-dom'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import Header from './components/Header'

// Hide the user-facing Header on /admin/* routes (admin panel has its own chrome).
function AppHeader() {
  const { pathname } = useLocation()
  if (pathname.startsWith('/admin')) return null
  return <Header />
}

// Auth pages
import AuthPage from './pages/auth/AuthPage'
import LoginPage from './pages/auth/LoginPage'

// Advertiser (L1)
import AdvertiserGetStarted from './pages/advertiser/AdvertiserGetStarted'
import AdvertiserDashboard from './pages/advertiser/AdvertiserDashboard'
import ChooseAdType from './pages/advertiser/ChooseAdType'
import AdDetails from './pages/advertiser/AdDetails'
import PublishAd from './pages/advertiser/PublishAd'
import PaymentPage from './pages/advertiser/PaymentPage'
import TransactionHistory from './pages/advertiser/TransactionHistory'

// Cross-portal pages
import HelpSupport from './pages/HelpSupport'
import { PrivacyPolicy, Terms, Support, RefundPolicy } from './pages/LegalPages'
import DeleteAccount from './pages/DeleteAccount'
import TestPayment from './pages/TestPayment'

// Sales (L2)
import SalesDashboard from './pages/sales/SalesDashboard'
import TutorialZone from './pages/sales/TutorialZone'
import { YourTeam, Earning, SalesSettings } from './pages/sales/SalesExtra'

// Shop (L3)
import ChooseService from './pages/shop/ChooseService'
import ShopRegister from './pages/shop/ShopRegister'
import ShopClaim from './pages/shop/ShopClaim'
import ShopPhotos from './pages/shop/ShopPhotos'
import SelectCategory from './pages/shop/SelectCategory'
import ChooseShopType from './pages/shop/ChooseShopType'
import { ReviewAndSubmit, ShopPayment } from './pages/shop/ReviewAndSubmit'
import ShopDashboard from './pages/shop/ShopDashboard'
import { OfferManagement, StoreDetailsManagement, RatingsAndReviews, ShopSettings } from './pages/shop/ShopPages'

// Admin
import AdminLogin from './pages/admin/AdminLogin'
import AdminLayout from './pages/admin/AdminLayout'
import AdminDashboard from './pages/admin/AdminDashboard'
import AdminCreateAd from './pages/admin/AdminCreateAd'
import AdminBulkShops from './pages/admin/AdminBulkShops'
import AdminBulkSelect from './pages/admin/AdminBulkSelect'
import AdminWhatsAppCampaign from './pages/admin/AdminWhatsAppCampaign'
import AdminBulkClassifieds from './pages/admin/AdminBulkClassifieds'
import AdminFeatureCategoryImages from './pages/admin/AdminFeatureCategoryImages'
import AdminTransactions from './pages/admin/AdminTransactions'
import AdminShopDetail from './pages/admin/AdminShopDetail'
import AdminCategoryImages from './pages/admin/AdminCategoryImages'
import AdminLearnClaimit from './pages/admin/AdminLearnClaimit'
import { AdminUsers, AdminAppUsers, AdminAds, AdminShops, AdminReviews, AdminTickets, AdminFeedback, AdminPDFs, AdminSalesTeam, AdminBillReviews, AdminBonusSettings, AdminAdSettings, AdminBillRates, AdminPricing, AdminDeletedUsers } from './pages/admin/AdminPages'

// Protected route
function ProtectedRoute({ children, requiredRole }) {
  const { token, role } = useAuth()
  if (!token) return <Navigate to="/" replace />
  if (requiredRole && role !== requiredRole) return <Navigate to="/" replace />
  return children
}

// Admin guard — looks at the admin token (separate from user token).
function AdminProtected({ children }) {
  const t = localStorage.getItem('claimit_admin_token')
  if (!t) return <Navigate to="/admin" replace />
  return children
}

// Landing page (same for all)
function LandingPage() {
  return (
    <div style={{ minHeight: '100vh', paddingTop: 64, background: '#fff' }}>

      {/* Hero Banner */}
      <div style={{ width: '100%', maxHeight: 480, overflow: 'hidden' }}>
        <img
          src="/assets/home_img5.png"
          alt="claimit hero"
          style={{ width: '100%', height: 480, objectFit: 'cover', display: 'block' }}
        />
      </div>

      {/* About Section */}
      <div style={{ textAlign: 'center', padding: '60px 32px 40px' }}>
        <h2 style={{ fontSize: 32, fontWeight: 700, color: '#1565C0', marginBottom: 20 }}>
          About claimit
        </h2>
        <p style={{ fontSize: 17, color: '#333', maxWidth: 760, margin: '0 auto', lineHeight: 1.7 }}>
          Empower your brand with our loyalty ecosystem, designed to increase your footfall and maximize your long-term revenue potential.
        </p>
      </div>

      {/* 4-Image Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gap: 0,
        maxWidth: 1100,
        margin: '0 auto 60px',
        padding: '0 32px'
      }}>
        {[1, 2, 3, 4].map((n) => (
          <div key={n} style={{ overflow: 'hidden', borderRadius: 8, margin: 8 }}>
            <img
              src={`/assets/home_img${n}.png`}
              alt={`claimit feature ${n}`}
              style={{ width: '100%', height: 200, objectFit: 'cover', display: 'block' }}
            />
          </div>
        ))}
      </div>

      {/* Services + Pricing — publicly visible (no login) so visitors and
          payment-gateway reviewers can see what claimit offers and what it
          costs, straight from the homepage. */}
      <div style={{ background: '#F4F7FF', padding: '56px 32px' }}>
        <div style={{ maxWidth: 1100, margin: '0 auto', textAlign: 'center' }}>
          <h2 style={{ fontSize: 28, fontWeight: 700, color: '#1565C0', marginBottom: 14 }}>
            For Local Shops
          </h2>
          <p style={{ fontSize: 16, color: '#444', maxWidth: 700, margin: '0 auto 40px', lineHeight: 1.7 }}>
            List your shop on claimit and get discovered by nearby customers on the claimit app.
            Run a Reward program (customers earn points on every bill) or a Redeem program
            (customers get an instant discount) — your choice. Registration is a one-time
            payment based on the plan you pick below.
          </p>

          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
            gap: 20, maxWidth: 820, margin: '0 auto 36px',
          }}>
            {[
              { name: 'Premium', price: '₹720', note: 'Top placement + full visibility' },
              { name: 'Standard', price: '₹365', note: 'Priority listing' },
              { name: 'Other', price: 'Your choice', note: 'Enter any amount' },
            ].map(p => (
              <div key={p.name} style={{
                background: '#fff', borderRadius: 12, padding: '24px 20px',
                border: '1px solid #e0e0e0', boxShadow: '0 2px 10px rgba(0,0,0,0.04)',
              }}>
                <div style={{ fontSize: 15, fontWeight: 700, color: '#111' }}>{p.name}</div>
                <div style={{ fontSize: 26, fontWeight: 800, color: '#1565C0', margin: '8px 0' }}>{p.price}</div>
                <div style={{ fontSize: 13, color: '#777' }}>{p.note}</div>
              </div>
            ))}
          </div>

          <Link to="/shop/auth" style={{
            display: 'inline-block', padding: '13px 32px', background: '#1565C0',
            color: '#fff', borderRadius: 10, fontWeight: 700, fontSize: 15,
            textDecoration: 'none',
          }}>
            Register your shop
          </Link>
        </div>
      </div>

    </div>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppHeader />
        <Routes>
          {/* Landing */}
          <Route path="/" element={<LandingPage />} />

          {/* Public legal & support pages — required for Play Store submission
              (Play Console → Policy → App content → Privacy Policy URL) */}
          <Route path="/privacy-policy" element={<PrivacyPolicy />} />
          <Route path="/terms" element={<Terms />} />
          <Route path="/refund-policy" element={<RefundPolicy />} />
          <Route path="/support" element={<Support />} />
          {/* Account deletion — required by Play Console → App content →
              Data safety. /user/delete is the exact URL already submitted
              there; /delete-account is a friendlier alias to the same page. */}
          <Route path="/delete-account" element={<DeleteAccount />} />
          <Route path="/user/delete" element={<DeleteAccount />} />

          {/* Razorpay test payment — temporary, delete after verifying. */}
          <Route path="/testpayment" element={<TestPayment />} />

          {/* ─── L1 Advertiser ─────────────────────────────── */}
          <Route path="/advertiser/auth" element={<AuthPage portal="advertiser" />} />
          <Route path="/advertiser/login" element={<LoginPage portal="advertiser" />} />
          <Route path="/advertiser/get-started" element={
            <ProtectedRoute requiredRole="advertiser"><AdvertiserGetStarted /></ProtectedRoute>
          } />
          <Route path="/advertiser/dashboard" element={
            <ProtectedRoute requiredRole="advertiser"><AdvertiserDashboard /></ProtectedRoute>
          } />
          <Route path="/advertiser/create-ad" element={
            <ProtectedRoute requiredRole="advertiser"><ChooseAdType /></ProtectedRoute>
          } />
          <Route path="/advertiser/create-ad/details" element={
            <ProtectedRoute requiredRole="advertiser"><AdDetails /></ProtectedRoute>
          } />
          <Route path="/advertiser/create-ad/publish" element={
            <ProtectedRoute requiredRole="advertiser"><PublishAd /></ProtectedRoute>
          } />
          <Route path="/advertiser/create-ad/payment" element={
            <ProtectedRoute requiredRole="advertiser"><PaymentPage /></ProtectedRoute>
          } />
          <Route path="/advertiser/transactions" element={
            <ProtectedRoute requiredRole="advertiser"><TransactionHistory /></ProtectedRoute>
          } />
          <Route path="/advertiser/support" element={
            <ProtectedRoute requiredRole="advertiser"><HelpSupport /></ProtectedRoute>
          } />

          {/* ─── L2 Sales ──────────────────────────────────── */}
          <Route path="/sales/auth" element={<AuthPage portal="sales" />} />
          <Route path="/sales/login" element={<LoginPage portal="sales" />} />
          <Route path="/sales/dashboard" element={
            <ProtectedRoute requiredRole="sales"><SalesDashboard /></ProtectedRoute>
          } />
          <Route path="/sales/tutorials" element={
            <ProtectedRoute requiredRole="sales"><TutorialZone /></ProtectedRoute>
          } />
          <Route path="/sales/team" element={
            <ProtectedRoute requiredRole="sales"><YourTeam /></ProtectedRoute>
          } />
          <Route path="/sales/earning" element={
            <ProtectedRoute requiredRole="sales"><Earning /></ProtectedRoute>
          } />
          <Route path="/sales/settings" element={
            <ProtectedRoute requiredRole="sales"><SalesSettings /></ProtectedRoute>
          } />
          <Route path="/sales/support" element={
            <ProtectedRoute requiredRole="sales"><HelpSupport /></ProtectedRoute>
          } />

          {/* ─── L3 Shop ───────────────────────────────────── */}
          <Route path="/shop/auth" element={<AuthPage portal="shop" />} />
          <Route path="/shop/login" element={<LoginPage portal="shop" />} />
          <Route path="/shop/onboard" element={
            <ProtectedRoute requiredRole="shop"><ChooseService /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/claim" element={
            <ProtectedRoute requiredRole="shop"><ShopClaim /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/register" element={
            <ProtectedRoute requiredRole="shop"><ShopRegister /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/photos" element={
            <ProtectedRoute requiredRole="shop"><ShopPhotos /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/category" element={
            <ProtectedRoute requiredRole="shop"><SelectCategory /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/shop-type" element={
            <ProtectedRoute requiredRole="shop"><ChooseShopType /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/review" element={
            <ProtectedRoute requiredRole="shop"><ReviewAndSubmit /></ProtectedRoute>
          } />
          <Route path="/shop/onboard/payment" element={
            <ProtectedRoute requiredRole="shop"><ShopPayment /></ProtectedRoute>
          } />
          <Route path="/shop/dashboard" element={
            <ProtectedRoute requiredRole="shop"><ShopDashboard /></ProtectedRoute>
          } />
          <Route path="/shop/offer" element={
            <ProtectedRoute requiredRole="shop"><OfferManagement /></ProtectedRoute>
          } />
          <Route path="/shop/store-details" element={
            <ProtectedRoute requiredRole="shop"><StoreDetailsManagement /></ProtectedRoute>
          } />
          <Route path="/shop/ratings" element={
            <ProtectedRoute requiredRole="shop"><RatingsAndReviews /></ProtectedRoute>
          } />
          <Route path="/shop/settings" element={
            <ProtectedRoute requiredRole="shop"><ShopSettings /></ProtectedRoute>
          } />
          <Route path="/shop/support" element={
            <ProtectedRoute requiredRole="shop"><HelpSupport /></ProtectedRoute>
          } />

          {/* ─── Admin Panel ──────────────────────────────── */}
          <Route path="/admin" element={<AdminLogin />} />
          <Route element={<AdminProtected><AdminLayout /></AdminProtected>}>
            <Route path="/admin/dashboard" element={<AdminDashboard />} />
            <Route path="/admin/users"     element={<AdminUsers />} />
            <Route path="/admin/app-users" element={<AdminAppUsers />} />
            <Route path="/admin/ads"       element={<AdminAds />} />
            <Route path="/admin/create-ad" element={<AdminCreateAd />} />
            <Route path="/admin/shops"     element={<AdminShops />} />
            <Route path="/admin/shops/:id" element={<AdminShopDetail />} />
            <Route path="/admin/transactions" element={<AdminTransactions />} />
            <Route path="/admin/bulk-shops" element={<AdminBulkShops />} />
            <Route path="/admin/bulk-select" element={<AdminBulkSelect />} />
            <Route path="/admin/whatsapp-campaign" element={<AdminWhatsAppCampaign />} />
            <Route path="/admin/bulk-classifieds" element={<AdminBulkClassifieds />} />
            <Route path="/admin/feature-category-images" element={<AdminFeatureCategoryImages />} />
            <Route path="/admin/category-images" element={<AdminCategoryImages />} />
            <Route path="/admin/learn-claimit" element={<AdminLearnClaimit />} />
            <Route path="/admin/reviews"   element={<AdminReviews />} />
            <Route path="/admin/tickets"    element={<AdminTickets />} />
            <Route path="/admin/feedback"   element={<AdminFeedback />} />
            <Route path="/admin/pdfs"       element={<AdminPDFs />} />
            <Route path="/admin/sales-team"   element={<AdminSalesTeam />} />
            <Route path="/admin/bill-reviews"   element={<AdminBillReviews />} />
            <Route path="/admin/bonus-settings" element={<AdminBonusSettings />} />
            <Route path="/admin/ad-settings"    element={<AdminAdSettings />} />
            <Route path="/admin/bill-rates"     element={<AdminBillRates />} />
            <Route path="/admin/pricing"        element={<AdminPricing />} />
            <Route path="/admin/deleted-users"  element={<AdminDeletedUsers />} />
          </Route>

          {/* Catch all */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

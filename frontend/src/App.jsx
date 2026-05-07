import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import Header from './components/Header'

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

// Sales (L2)
import SalesDashboard from './pages/sales/SalesDashboard'
import TutorialZone from './pages/sales/TutorialZone'
import { YourTeam, Earning, SalesSettings } from './pages/sales/SalesExtra'

// Shop (L3)
import ChooseService from './pages/shop/ChooseService'
import ShopRegister from './pages/shop/ShopRegister'
import ShopPhotos from './pages/shop/ShopPhotos'
import SelectCategory from './pages/shop/SelectCategory'
import ChooseShopType from './pages/shop/ChooseShopType'
import { ReviewAndSubmit, ShopPayment } from './pages/shop/ReviewAndSubmit'
import ShopDashboard from './pages/shop/ShopDashboard'
import { OfferManagement, StoreDetailsManagement, RatingsAndReviews, ShopSettings } from './pages/shop/ShopPages'

// Protected route
function ProtectedRoute({ children, requiredRole }) {
  const { token, role } = useAuth()
  if (!token) return <Navigate to="/" replace />
  if (requiredRole && role !== requiredRole) return <Navigate to="/" replace />
  return children
}

// Landing page (same for all)
function LandingPage() {
  return (
    <div style={{
      minHeight: '100vh', paddingTop: 64,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'linear-gradient(135deg, #E3F2FD 0%, #BBDEFB 100%)'
    }}>
      <div style={{ textAlign: 'center', maxWidth: 600 }}>
        <div style={{
          width: 80, height: 80, borderRadius: '50%',
          background: '#1565C0', margin: '0 auto 24px',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 36, fontWeight: 700, color: '#fff', fontStyle: 'italic'
        }}>c</div>
        <h1 style={{ fontSize: 40, fontWeight: 800, color: '#1565C0', marginBottom: 12 }}>
          Welcome to Claimit
        </h1>
        <p style={{ fontSize: 18, color: '#555', marginBottom: 8 }}>
          Rewards. Discounts. Cashbacks
        </p>
        <p style={{ fontSize: 15, color: '#888', marginBottom: 40, lineHeight: 1.7 }}>
          Join the affiliate network where every sale generates extra value for your business and a cashback bonus for you.
        </p>
        <p style={{ fontSize: 14, color: '#1565C0', fontWeight: 600 }}>
          Click "Login" in the top right to get started →
        </p>
      </div>
    </div>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Header />
        <Routes>
          {/* Landing */}
          <Route path="/" element={<LandingPage />} />

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
            <ProtectedRoute requiredRole="advertiser"><AdvertiserDashboard /></ProtectedRoute>
          } />
          <Route path="/advertiser/support" element={
            <ProtectedRoute requiredRole="advertiser"><AdvertiserDashboard /></ProtectedRoute>
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

          {/* ─── L3 Shop ───────────────────────────────────── */}
          <Route path="/shop/auth" element={<AuthPage portal="shop" />} />
          <Route path="/shop/login" element={<LoginPage portal="shop" />} />
          <Route path="/shop/onboard" element={
            <ProtectedRoute requiredRole="shop"><ChooseService /></ProtectedRoute>
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

          {/* Catch all */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

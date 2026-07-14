import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

// ─────────────────────────────────────────────────────────────────────────
// Real Cashfree Payment Links checkout for advertiser ad bookings.
//
// Flow (mirrors the mobile app's Local Finds / Local Classifieds flow):
//   1. PublishAd.jsx already uploaded creative files + stashed the full
//      create-ad payload + amount into sessionStorage['pending_ad_payload'].
//   2. "Pay Now" here creates a Cashfree hosted payment link for that
//      amount, stores the link id, then redirects the browser to Cashfree's
//      hosted checkout page (return_url points back to this same page).
//   3. When Cashfree redirects back, we detect the pending link id in
//      sessionStorage and poll GET /payments/status/{link_id} until it
//      reports PAID (or the user gives up / it expires).
//   4. Once PAID, we submit the stashed payload to POST /advertiser/ads/create
//      WITH payment_link_id attached — the backend re-verifies PAID status
//      itself before creating/charging anything — then show the real
//      success screen (using the ad the backend actually created).
// ─────────────────────────────────────────────────────────────────────────

const POLL_INTERVAL_MS = 3000
const MAX_POLL_ATTEMPTS = 40 // ~2 minutes of auto-polling

export default function PaymentPage() {
  const navigate = useNavigate()

  const readPending = () => {
    try { return JSON.parse(sessionStorage.getItem('pending_ad_payload') || 'null') } catch { return null }
  }

  const [pending] = useState(readPending)
  // phase: loading | ready | redirecting | verifying | paid | failed | missing
  const [phase, setPhase] = useState('loading')
  const [error, setError] = useState('')
  const [result, setResult] = useState(null) // { adType, publishDate, endDate, amount }

  const pollTimerRef = useRef(null)
  const pollAttemptsRef = useRef(0)

  useEffect(() => {
    const linkId = sessionStorage.getItem('pending_payment_link_id')
    if (linkId) {
      // Returning from Cashfree's hosted checkout page — verify automatically.
      setPhase('verifying')
      startPolling(linkId)
    } else if (pending) {
      setPhase('ready')
    } else {
      setPhase('missing')
    }
    return () => { if (pollTimerRef.current) clearInterval(pollTimerRef.current) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const finalizeAd = async (linkId) => {
    if (!pending) {
      setError('Payment succeeded, but we lost track of the ad details. Please contact support with this payment reference: ' + linkId)
      setPhase('failed')
      return
    }
    try {
      const payload = { ...pending.payload, payment_link_id: linkId }
      const data = await api.advertiser.createAd(payload)
      sessionStorage.removeItem('pending_ad_payload')
      sessionStorage.removeItem('pending_payment_link_id')
      setResult({
        adType: pending.adTypeLabel,
        publishDate: data.publish_date,
        endDate: data.end_date,
        amount: data.amount,
      })
      setPhase('paid')
    } catch (e) {
      setError(
        e?.response?.data?.detail || e?.message ||
        `Payment succeeded, but publishing the ad failed. Please contact support with this payment reference: ${linkId}`
      )
      setPhase('failed')
    }
  }

  const startPolling = (linkId) => {
    if (pollTimerRef.current) clearInterval(pollTimerRef.current)
    pollAttemptsRef.current = 0

    const check = async () => {
      pollAttemptsRef.current += 1
      try {
        const res = await api.payments.checkStatus(linkId)
        if (res.status === 'PAID') {
          clearInterval(pollTimerRef.current)
          finalizeAd(linkId)
        } else if (res.status === 'EXPIRED' || res.status === 'CANCELLED') {
          clearInterval(pollTimerRef.current)
          sessionStorage.removeItem('pending_payment_link_id')
          setError('Payment was not completed. Please try again.')
          setPhase('failed')
        } else if (pollAttemptsRef.current >= MAX_POLL_ATTEMPTS) {
          clearInterval(pollTimerRef.current)
          // Stop auto-polling — let the advertiser check manually below.
        }
      } catch {
        // Transient network error — keep polling, don't fail the whole flow.
      }
    }
    check()
    pollTimerRef.current = setInterval(check, POLL_INTERVAL_MS)
  }

  const handlePay = async () => {
    if (!pending) return
    setError('')
    setPhase('redirecting')
    try {
      const returnUrl = `${window.location.origin}/advertiser/create-ad/payment`
      const link = await api.payments.createLink({
        amount: pending.amount,
        purpose: `Claimit ${pending.adTypeLabel} — 7 day campaign`,
        return_url: returnUrl,
      })
      if (!link.payment_link_url) throw new Error('No payment link returned')
      sessionStorage.setItem('pending_payment_link_id', link.link_id)
      window.location.href = link.payment_link_url
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || "Couldn't start payment. Please try again.")
      setPhase('ready')
    }
  }

  const handleCheckNow = () => {
    const linkId = sessionStorage.getItem('pending_payment_link_id')
    if (!linkId) return
    setPhase('verifying')
    startPolling(linkId)
  }

  const handleRetry = () => {
    sessionStorage.removeItem('pending_payment_link_id')
    setError('')
    setPhase(pending ? 'ready' : 'missing')
  }

  // ── Success screen ────────────────────────────────────────────────────
  if (phase === 'paid' && result) {
    return (
      <div style={{ paddingTop: 64 }}>
        <AdvertiserSidebar />
        <main className="main-content" style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          minHeight: 'calc(100vh - 64px)'
        }}>
          <div style={{ textAlign: 'center', maxWidth: 540 }}>
            <div style={{
              width: 80, height: 80, borderRadius: '50%',
              background: '#E8F5E9', margin: '0 auto 16px',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 36
            }}>✅</div>
            <h2 style={{ fontWeight: 700, fontSize: 26, marginBottom: 8 }}>Payment Successful!</h2>
            <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>
              Your advertisement has been scheduled successfully
            </p>

            <div style={{
              background: '#fff', borderRadius: 12, border: '1px solid #eee',
              padding: 28, marginBottom: 28, textAlign: 'left'
            }}>
              <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Ad Information</h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                {[
                  { label: 'Ad Type', value: result.adType },
                  { label: 'Publish Date', value: result.publishDate },
                  { label: 'Amount paid', value: `₹${result.amount}` },
                  { label: 'Ad End Date', value: result.endDate },
                ].map(item => (
                  <div key={item.label} style={{
                    border: '1px solid #eee', borderRadius: 8, padding: '14px 16px'
                  }}>
                    <div style={{ fontSize: 12, color: '#888', marginBottom: 4 }}>{item.label}</div>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>{item.value}</div>
                  </div>
                ))}
              </div>
            </div>

            <div style={{ display: 'flex', gap: 16 }}>
              <button className="btn-primary" onClick={() => navigate('/advertiser/create-ad')}>
                Create Another Ad
              </button>
              <button className="btn-outline" onClick={() => navigate('/advertiser/dashboard')}>
                Go to Dashboard
              </button>
            </div>
          </div>
        </main>
      </div>
    )
  }

  // ── No pending ad to pay for (direct nav / already completed) ─────────
  if (phase === 'missing') {
    return (
      <div style={{ paddingTop: 64 }}>
        <AdvertiserSidebar />
        <main className="main-content" style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          minHeight: 'calc(100vh - 64px)'
        }}>
          <div style={{ textAlign: 'center', maxWidth: 420 }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>🧾</div>
            <h2 style={{ fontWeight: 700, fontSize: 20, marginBottom: 8 }}>No pending ad to pay for</h2>
            <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>
              Start a new ad from the beginning to continue.
            </p>
            <button className="btn-primary" onClick={() => navigate('/advertiser/create-ad')}>
              Create an Ad
            </button>
          </div>
        </main>
      </div>
    )
  }

  // ── Main card: ready / redirecting / verifying / failed ────────────────
  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content" style={{
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        minHeight: 'calc(100vh - 64px)'
      }}>
        <div style={{
          background: '#fff', borderRadius: 16, border: '1px solid #eee',
          padding: 36, width: 480, boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 4 }}>
            {phase === 'verifying' ? 'Verifying Your Payment' : 'Finish Your Payment'}
          </h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>
            {phase === 'verifying'
              ? "We're confirming your payment with Cashfree — this usually takes a few seconds."
              : `Publish your ${pending?.adTypeLabel || 'ad'} instantly via secure Cashfree checkout.`}
          </p>

          {/* Price Summary */}
          {pending && (
            <div style={{
              background: '#1565C0', borderRadius: 12, padding: '20px 24px',
              color: '#fff', marginBottom: 24
            }}>
              <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>Price Summary</div>
              <div style={{ fontSize: 32, fontWeight: 700 }}>₹{pending.amount}</div>
              <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>Price includes GST · 7-day campaign</div>
            </div>
          )}

          {error && (
            <div style={{ background: '#FFEBEE', color: '#C62828', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 13 }}>
              {error}
            </div>
          )}

          {phase === 'verifying' && (
            <div style={{
              display: 'flex', alignItems: 'center', gap: 12,
              background: '#EFF6FF', border: '1px solid #BFDBFE', borderRadius: 10,
              padding: '14px 16px', marginBottom: 16,
            }}>
              <div style={{
                width: 18, height: 18, borderRadius: '50%',
                border: '2px solid #93C5FD', borderTopColor: '#1565C0',
                animation: 'spin 0.8s linear infinite',
              }} />
              <span style={{ fontSize: 13, color: '#1e3a8a' }}>Checking payment status…</span>
              <style>{'@keyframes spin { to { transform: rotate(360deg) } }'}</style>
            </div>
          )}

          {(phase === 'ready' || phase === 'redirecting') && (
            <div style={{ background: '#f8f9fa', borderRadius: 10, padding: '14px 16px', marginBottom: 20, fontSize: 12.5, color: '#666', lineHeight: 1.6 }}>
              You'll be redirected to Cashfree's secure hosted checkout page to pay via UPI, Cards, or Netbanking.
              After paying, you'll be brought straight back here.
            </div>
          )}

          {phase === 'failed' ? (
            <button className="btn-primary" style={{ width: '100%' }} onClick={handleRetry}>
              Try Payment Again
            </button>
          ) : phase === 'verifying' ? (
            <button className="btn-outline" style={{ width: '100%' }} onClick={handleCheckNow}>
              Check Status Now
            </button>
          ) : (
            <button
              className="btn-primary"
              style={{ width: '100%', opacity: phase === 'redirecting' ? 0.6 : 1 }}
              onClick={handlePay}
              disabled={phase === 'redirecting' || !pending}
            >
              {phase === 'redirecting' ? 'Redirecting to Cashfree…' : `Pay ₹${pending?.amount ?? ''} Now`}
            </button>
          )}
        </div>
      </main>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────
// /testpayment — a throwaway page to verify the Razorpay Payment Links flow
// end to end with a tiny real charge.
//
// Flow (same as the real advertiser PaymentPage, just simplified):
//   1. Enter an amount (default ₹1.00 — Razorpay's minimum is ₹1, it rejects
//      anything smaller like ₹0.01) and click "Pay".
//   2. We ask the backend to create a Razorpay payment link, stash its id in
//      sessionStorage, then redirect to Razorpay's hosted checkout.
//   3. After paying, Razorpay redirects back here → we poll
//      GET /payments/status/{link_id} until it reports PAID.
//
// NOTE: /payments/create-link requires a logged-in user, so sign in to any
// portal (e.g. /advertiser/login) first. Delete this page + its route once
// testing is done.
// ─────────────────────────────────────────────────────────────────────────
import { useEffect, useRef, useState } from 'react'
import api from '../utils/api'

export default function TestPayment() {
  const [amount, setAmount] = useState('1.00')
  const [phase, setPhase] = useState('idle') // idle | creating | redirecting | verifying | done | failed
  const [message, setMessage] = useState('')
  const pollRef = useRef(null)

  const loggedIn = !!localStorage.getItem('claimit_token')

  // On return from Razorpay, resume polling if we have a pending link id.
  useEffect(() => {
    const linkId = sessionStorage.getItem('test_payment_link_id')
    if (linkId) {
      setPhase('verifying')
      setMessage('Confirming your payment with Razorpay…')
      startPolling(linkId)
    }
    return () => clearInterval(pollRef.current)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const startPolling = (linkId) => {
    clearInterval(pollRef.current)
    pollRef.current = setInterval(async () => {
      try {
        const res = await api.payments.checkStatus(linkId)
        if (res.status === 'PAID') {
          clearInterval(pollRef.current)
          sessionStorage.removeItem('test_payment_link_id')
          setPhase('done')
          setMessage('✅ Payment successful! Razorpay + backend + status polling all work.')
        } else if (res.status === 'EXPIRED' || res.status === 'CANCELLED') {
          clearInterval(pollRef.current)
          sessionStorage.removeItem('test_payment_link_id')
          setPhase('failed')
          setMessage('❌ Payment was not completed (' + res.status + '). Try again.')
        }
        // ACTIVE → keep polling
      } catch (e) {
        // keep polling; transient errors are fine
      }
    }, 3000)
  }

  const handlePay = async () => {
    setMessage('')
    const amt = parseFloat(amount)
    if (isNaN(amt) || amt < 1) {
      setPhase('failed')
      setMessage('Enter ₹1.00 or more — Razorpay does not allow amounts below ₹1.')
      return
    }
    setPhase('creating')
    try {
      const link = await api.payments.createLink({
        amount: amt,
        purpose: 'Claimit Razorpay test payment',
        return_url: window.location.origin + '/testpayment',
      })
      if (!link.payment_link_url) throw new Error('No payment link returned')
      sessionStorage.setItem('test_payment_link_id', link.link_id)
      setPhase('redirecting')
      window.location.href = link.payment_link_url
    } catch (e) {
      setPhase('failed')
      const detail = e?.response?.data?.detail || e?.message || 'Unknown error'
      setMessage('Could not create payment link: ' + detail)
    }
  }

  const reset = () => {
    clearInterval(pollRef.current)
    sessionStorage.removeItem('test_payment_link_id')
    setPhase('idle')
    setMessage('')
  }

  const box = {
    maxWidth: 440, margin: '80px auto', padding: 28, background: '#fff',
    border: '1px solid #e5e7eb', borderRadius: 14, fontFamily: 'system-ui, sans-serif',
    boxShadow: '0 4px 20px rgba(0,0,0,0.06)',
  }

  return (
    <div style={{ minHeight: '100vh', paddingTop: 64, background: '#f8f9fa' }}>
      <div style={box}>
        <h2 style={{ margin: '0 0 6px', color: '#1565C0', fontSize: 22 }}>Razorpay Test Payment</h2>
        <p style={{ margin: '0 0 20px', color: '#666', fontSize: 13.5, lineHeight: 1.6 }}>
          A small real charge to confirm the Razorpay integration works end to end.
          Razorpay's minimum is <b>₹1.00</b> (it rejects ₹0.01).
        </p>

        {!loggedIn && (
          <div style={{ background: '#fff4e5', border: '1px solid #ffd9a8', borderRadius: 8, padding: '10px 12px', marginBottom: 16, fontSize: 13, color: '#8a5300' }}>
            You must be logged in to create a payment. Please <a href="/advertiser/login" style={{ color: '#1565C0' }}>sign in</a> first, then come back to this page.
          </div>
        )}

        {(phase === 'idle' || phase === 'failed') && (
          <>
            <label style={{ fontSize: 13, color: '#333', fontWeight: 600 }}>Amount (₹)</label>
            <input
              type="number" min="1" step="0.01" value={amount}
              onChange={(e) => setAmount(e.target.value)}
              style={{ width: '100%', padding: '10px 12px', margin: '6px 0 16px', border: '1px solid #ccc', borderRadius: 8, fontSize: 15, boxSizing: 'border-box' }}
            />
            <button
              onClick={handlePay} disabled={!loggedIn}
              style={{ width: '100%', padding: '12px', background: loggedIn ? '#1565C0' : '#9db8d8', color: '#fff', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600, cursor: loggedIn ? 'pointer' : 'not-allowed' }}
            >
              Pay ₹{amount || ''} (Test)
            </button>
          </>
        )}

        {(phase === 'creating' || phase === 'redirecting' || phase === 'verifying') && (
          <div style={{ textAlign: 'center', padding: '10px 0' }}>
            <div style={{ width: 26, height: 26, border: '3px solid #cfe0f5', borderTopColor: '#1565C0', borderRadius: '50%', margin: '0 auto 12px', animation: 'spin 0.8s linear infinite' }} />
            <p style={{ fontSize: 13.5, color: '#555' }}>
              {phase === 'creating' && 'Creating Razorpay payment link…'}
              {phase === 'redirecting' && 'Redirecting to Razorpay…'}
              {phase === 'verifying' && 'Confirming your payment with Razorpay…'}
            </p>
            <style>{'@keyframes spin { to { transform: rotate(360deg) } }'}</style>
          </div>
        )}

        {(phase === 'done' || phase === 'failed') && message && (
          <div style={{ marginTop: 16, padding: '12px 14px', borderRadius: 8, fontSize: 14, lineHeight: 1.5,
            background: phase === 'done' ? '#e7f7ec' : '#fdeaea',
            color: phase === 'done' ? '#1b7a3d' : '#b3261e' }}>
            {message}
          </div>
        )}

        {(phase === 'done') && (
          <button onClick={reset} style={{ width: '100%', marginTop: 14, padding: '10px', background: '#eef2f7', color: '#1565C0', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}>
            Test again
          </button>
        )}
      </div>
    </div>
  )
}

import { useState } from 'react'
import api from '../utils/api'

// Public account-deletion page for Claimit APP users (the Flutter app's own
// end-customers) — required by Google Play (Play Console → App content →
// Data safety → "Account deletion" must link to a working web page, not
// just in-app instructions). Reachable at both /delete-account and
// /user/delete (the exact URL already submitted to Play Console).
//
// Flow: enter the phone/email registered on the Claimit app → OTP is
// generated → enter the OTP + confirm → account and ALL associated data
// (claims, wallet, redeem history, notifications, classifieds, etc.) are
// permanently deleted from claimit_db. See routers/app_account.py for the
// exact list of what gets wiped.

const SUPPORT_EMAIL = 'support@claimitapp.in'

const styles = {
  page: { minHeight: '100vh', paddingTop: 64, background: '#fff' },
  header: { textAlign: 'center', padding: '48px 32px 24px' },
  title: { fontSize: 32, fontWeight: 700, color: '#1565C0', marginBottom: 8 },
  meta: { fontSize: 14, color: '#6b7280' },
  container: { maxWidth: 640, margin: '0 auto', padding: '0 32px 80px' },
  card: { background: '#fafafa', border: '1px solid #eee', borderRadius: 14, padding: 28, marginTop: 8 },
  heading: { fontSize: 17, fontWeight: 700, color: '#1A1A2E', marginBottom: 10 },
  body: { fontSize: 14.5, color: '#374151', lineHeight: 1.7 },
  label: { display: 'block', fontSize: 13, fontWeight: 600, color: '#333', marginBottom: 8, marginTop: 18 },
  input: {
    width: '100%', padding: '11px 14px', border: '1.5px solid #ddd',
    borderRadius: 8, fontSize: 15, outline: 'none', boxSizing: 'border-box',
  },
  error: { background: '#FFEBEE', color: '#C62828', borderRadius: 8, padding: '10px 14px', marginTop: 16, fontSize: 13 },
  button: (danger, disabled) => ({
    width: '100%', padding: '13px', marginTop: 22, border: 'none', borderRadius: 10,
    fontWeight: 700, fontSize: 15, cursor: disabled ? 'not-allowed' : 'pointer',
    background: disabled ? '#ccc' : danger ? '#C62828' : '#1565C0',
    color: '#fff', opacity: disabled ? 0.7 : 1,
  }),
}

export default function DeleteAccount() {
  const [step, setStep] = useState('enter') // enter | otp | done
  const [identifier, setIdentifier] = useState('')
  const [otp, setOtp] = useState('')
  const [confirm, setConfirm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const handleSendOtp = async () => {
    setError('')
    const id = identifier.trim()
    if (!id) { setError('Enter the mobile number or email on your Claimit account.'); return }
    setLoading(true)
    try {
      const res = await api.appAccount.sendOtp(id)
      // No SMS/email delivery is wired up for this flow yet, so the OTP is
      // shown right here on the page instead of being sent externally.
      if (res?.dev_otp) {
        setOtp(res.dev_otp)
        setNotice(`Your OTP is ${res.dev_otp}`)
      } else {
        setNotice('An OTP has been generated for this account.')
      }
      setStep('otp')
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Something went wrong. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    setError('')
    if (!otp.trim()) { setError('Enter the OTP.'); return }
    if (!confirm) { setError('Please confirm you understand this permanently deletes your account.'); return }
    setLoading(true)
    try {
      await api.appAccount.verifyAndDelete(identifier.trim(), otp.trim(), confirm)
      setStep('done')
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Something went wrong. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.page}>
      <div style={styles.header}>
        <h1 style={styles.title}>Delete Your Claimit Account</h1>
        <p style={styles.meta}>Claimit Mobile Application</p>
      </div>

      <div style={styles.container}>
        <section>
          <h2 style={styles.heading}>What gets deleted</h2>
          <p style={styles.body}>
            Deleting your account is permanent and cannot be undone. It removes your profile,
            saved policies and insurance claims, reward wallet and cashback balance, redeem
            and bill-scan history, notifications, classifieds/local finds listings you've
            posted, shop reviews you've written, and any uploaded documents or profile photo.
            Some records may be retained where required by law, an open or disputed claim, or
            fraud-prevention obligations — see our{' '}
            <a href="/privacy-policy" style={{ color: '#1565C0' }}>Privacy Policy</a>.
          </p>
        </section>

        <div style={styles.card}>
          {step === 'enter' && (
            <>
              <h2 style={styles.heading}>Step 1 — Verify your account</h2>
              <p style={styles.body}>Enter the mobile number or email you use to log in to Claimit.</p>
              <label style={styles.label}>Mobile number or email</label>
              <input
                style={styles.input}
                placeholder="e.g. 9876543210 or you@example.com"
                value={identifier}
                onChange={e => setIdentifier(e.target.value)}
              />
              {error && <div style={styles.error}>{error}</div>}
              <button style={styles.button(false, loading)} onClick={handleSendOtp} disabled={loading}>
                {loading ? 'Sending…' : 'Send OTP'}
              </button>
            </>
          )}

          {step === 'otp' && (
            <>
              <h2 style={styles.heading}>Step 2 — Confirm deletion</h2>
              <p style={styles.body}>OTP for <strong>{identifier}</strong>:</p>
              {otp && (
                <div style={{
                  background: '#E8F5E9', border: '1.5px solid #A5D6A7', borderRadius: 10,
                  padding: '14px 18px', margin: '10px 0', textAlign: 'center',
                  fontSize: 28, fontWeight: 800, letterSpacing: 6, color: '#2e7d32',
                }}>
                  {otp}
                </div>
              )}
              <p style={{ ...styles.body, fontSize: 12.5, color: '#888' }}>
                It's pre-filled below — just review and confirm.
              </p>
              <label style={styles.label}>OTP</label>
              <input
                style={styles.input}
                placeholder="6-digit code"
                value={otp}
                onChange={e => setOtp(e.target.value)}
                maxLength={6}
              />
              <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, marginTop: 20, fontSize: 13.5, color: '#374151', cursor: 'pointer' }}>
                <input type="checkbox" checked={confirm} onChange={e => setConfirm(e.target.checked)} style={{ marginTop: 2 }} />
                I understand this will permanently delete my Claimit account and all associated
                data, and this cannot be undone.
              </label>
              {error && <div style={styles.error}>{error}</div>}
              <button style={styles.button(true, loading)} onClick={handleDelete} disabled={loading}>
                {loading ? 'Deleting…' : 'Permanently Delete My Account'}
              </button>
              <button
                style={{ ...styles.button(false, false), background: 'transparent', color: '#1565C0', marginTop: 10 }}
                onClick={() => { setStep('enter'); setOtp(''); setError(''); setNotice('') }}
              >
                ← Use a different number/email
              </button>
            </>
          )}

          {step === 'done' && (
            <>
              <h2 style={styles.heading}>✅ Account deleted</h2>
              <p style={styles.body}>
                Your Claimit account and all associated data have been permanently deleted.
                If you have any questions, contact <a href={`mailto:${SUPPORT_EMAIL}`} style={{ color: '#1565C0' }}>{SUPPORT_EMAIL}</a>.
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

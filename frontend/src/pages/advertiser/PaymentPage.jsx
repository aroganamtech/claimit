import { useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'

export default function PaymentPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const state = location.state || {
    adType: 'Nearby Deals ad',
    publishDate: '01/12/2025',
    endDate: '07/12/2025',
    amount: 1400
  }

  const [selected, setSelected] = useState(null)
  const [paid, setPaid] = useState(false)
  const [loading, setLoading] = useState(false)

  const handlePay = () => {
    if (!selected) return
    setLoading(true)
    setTimeout(() => {
      setLoading(false)
      setPaid(true)
    }, 1500)
  }

  if (paid) {
    return (
      <div style={{ paddingTop: 64 }}>
        <AdvertiserSidebar />
        <main className="main-content" style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          minHeight: 'calc(100vh - 64px)'
        }}>
          <div style={{ textAlign: 'center', maxWidth: 540 }}>
            {/* Success icon */}
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
                  { label: 'Ad Type', value: state.adType },
                  { label: 'Publish Date', value: state.publishDate },
                  { label: 'Amount paid', value: `₹${state.amount}` },
                  { label: 'Ad End Date', value: state.endDate },
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
              <button
                className="btn-primary"
                onClick={() => navigate('/advertiser/create-ad')}
              >
                Create Another Ad
              </button>
              <button
                className="btn-outline"
                onClick={() => navigate('/advertiser/dashboard')}
              >
                Go to Dashboard
              </button>
            </div>
          </div>
        </main>
      </div>
    )
  }

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
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 4 }}>Finish Your Payment</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>Publish your shop instantly.</p>

          {/* Price Summary */}
          <div style={{
            background: '#1565C0', borderRadius: 12, padding: '20px 24px',
            color: '#fff', marginBottom: 24
          }}>
            <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>Price Summary</div>
            <div style={{ fontSize: 32, fontWeight: 700 }}>₹{state.amount}</div>
            <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>Price includes 18% GST</div>
          </div>

          <h3 style={{ fontWeight: 600, fontSize: 14, marginBottom: 14 }}>Select Payment Method</h3>

          {[
            { id: 'upi', label: 'UPI', icons: '🟡 🟢 🔵 ⚡' },
            { id: 'cards', label: 'Cards', icons: '💳 💳 💳' },
            { id: 'netbanking', label: 'Netbanking', icons: '🏦 🏦 🏦' },
          ].map(method => (
            <div
              key={method.id}
              onClick={() => setSelected(method.id)}
              style={{
                border: `1.5px solid ${selected === method.id ? '#1565C0' : '#eee'}`,
                borderRadius: 10, padding: '14px 18px', marginBottom: 10,
                cursor: 'pointer', background: selected === method.id ? '#f0f4ff' : '#fff'
              }}
            >
              <div style={{ fontWeight: 600, fontSize: 14 }}>{method.label}</div>
              <div style={{ fontSize: 16, marginTop: 4 }}>{method.icons}</div>
            </div>
          ))}

          <button
            className="btn-primary"
            style={{ marginTop: 8, opacity: selected && !loading ? 1 : 0.6 }}
            onClick={handlePay}
            disabled={!selected || loading}
          >
            {loading ? 'Processing...' : 'Pay now'}
          </button>
        </div>
      </main>
    </div>
  )
}

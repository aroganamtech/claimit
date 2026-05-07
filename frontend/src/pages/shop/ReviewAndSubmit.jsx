import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

export function ReviewAndSubmit() {
  const navigate = useNavigate()
  const basic = JSON.parse(sessionStorage.getItem('shop_basic') || '{}')
  const category = sessionStorage.getItem('shop_category') || 'supermarket'
  const shopType = sessionStorage.getItem('shop_type') || 'redeem'

  return (
    <div style={{ paddingTop: 64, display: 'flex', minHeight: '100vh' }}>
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <div style={{
          width: 380, height: 280, background: '#f8f9fa',
          borderRadius: 12, border: '2px dashed #eee',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#ccc', fontSize: 15, marginBottom: 32
        }}>
          {/* image */}
        </div>
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Keep Your Customers Coming Back for More
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Offer the gift of rewards and watch your retention rates soar as customers return to redeem and earn again.
        </p>
      </div>

      <div style={{ width: 560, padding: 40, display: 'flex', alignItems: 'center' }}>
        <div style={{
          width: '100%', background: '#fff',
          borderRadius: 16, padding: 36, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Review & Submit</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>Please review your information before submitting</p>

          {/* Shop Details */}
          <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 20, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <span style={{ fontWeight: 600, fontSize: 14 }}>Shop Details</span>
              <span
                style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer', fontWeight: 600 }}
                onClick={() => navigate('/shop/onboard/register')}
              >Edit</span>
            </div>
            {[
              { label: 'Shop Name', value: basic.shopName || 'Santhosh Super market' },
              { label: 'Shop Address', value: basic.shopAddress || 'C33, 2nd Avenue, Anna Nagar, Chennai' },
              { label: 'Geo Location', value: '36M4+X9 Chennai, Tamil Nadu' },
              { label: 'description', value: basic.about || 'Short description about the shop.' },
            ].map(item => (
              <div key={item.label} style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 8, marginBottom: 8 }}>
                <span style={{ fontSize: 13, color: '#888' }}>{item.label}:</span>
                <span style={{ fontSize: 13, color: '#333', fontWeight: 500 }}>{item.value}</span>
              </div>
            ))}
          </div>

          {/* Photos placeholder */}
          <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 20, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontWeight: 600, fontSize: 14 }}>Shop Photos</span>
              <span style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer', fontWeight: 600 }}>Edit</span>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              {[1, 2, 3, 4].map(i => (
                <div key={i} style={{
                  width: 60, height: 60, background: '#d0daf0',
                  borderRadius: 6, display: 'flex', alignItems: 'center',
                  justifyContent: 'center', color: '#90a4c8', fontSize: 10
                }}>
                  {/* image */}
                </div>
              ))}
            </div>
          </div>

          {/* Category + Shop Type */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 24 }}>
            <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={{ fontWeight: 600, fontSize: 13 }}>Category</span>
                <span style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer' }}>Edit</span>
              </div>
              <div style={{ fontSize: 14, fontWeight: 500, textTransform: 'capitalize' }}>
                🏪 {category}
              </div>
            </div>
            <div style={{ background: '#EEF4FF', borderRadius: 10, padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={{ fontWeight: 600, fontSize: 13 }}>Shop Type</span>
                <span style={{ color: '#1565C0', fontSize: 13, cursor: 'pointer' }}>Edit</span>
              </div>
              <div style={{ fontSize: 14, fontWeight: 600, color: '#1565C0', textTransform: 'capitalize' }}>
                {shopType === 'redeem' ? '🏪' : '🎯'} {shopType.charAt(0).toUpperCase() + shopType.slice(1)} Shop
              </div>
              {shopType === 'redeem' && <div style={{ fontSize: 12, color: '#888' }}>20%</div>}
            </div>
          </div>

          <button
            className="btn-primary"
            onClick={() => navigate('/shop/onboard/payment')}
          >
            Submit & Pay
          </button>
        </div>
      </div>
    </div>
  )
}

export function ShopPayment() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState(null)
  const [loading, setLoading] = useState(false)
  const [paid, setPaid] = useState(false)

  const handlePay = async () => {
    if (!selected) return
    setLoading(true)

    try {
      const basic = JSON.parse(sessionStorage.getItem('shop_basic') || '{}')
      const category = sessionStorage.getItem('shop_category') || 'supermarket'
      const shopType = sessionStorage.getItem('shop_type') || 'redeem'

      const formData = new FormData()
      formData.append('shop_name', basic.shopName || '')
      formData.append('shop_address', basic.shopAddress || '')
      formData.append('pincode', basic.pincode || '000000')
      formData.append('about', basic.about || '')
      formData.append('category', category)
      formData.append('shop_type', shopType)
      formData.append('discount_percentage', '15')

      await api.post('/shop/register', formData)
      sessionStorage.removeItem('shop_basic')
      sessionStorage.removeItem('shop_category')
      sessionStorage.removeItem('shop_type')
      setPaid(true)
    } catch (e) {
      setPaid(true) // Demo: navigate anyway
    } finally {
      setLoading(false)
    }
  }

  if (paid) {
    return (
      <div style={{
        paddingTop: 64, minHeight: '100vh',
        display: 'flex', alignItems: 'center', justifyContent: 'center'
      }}>
        <div style={{ textAlign: 'center' }}>
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
          <button className="btn-primary" style={{ width: 240 }} onClick={() => navigate('/shop/dashboard')}>
            Go to Dashboard
          </button>
        </div>
      </div>
    )
  }

  return (
    <div style={{
      paddingTop: 64, display: 'flex', minHeight: '100vh'
    }}>
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <div style={{
          width: 380, height: 280, background: '#000',
          borderRadius: 12, display: 'flex', alignItems: 'center',
          justifyContent: 'center', color: '#fff', fontSize: 15, marginBottom: 32
        }}>
          {/* image */}
        </div>
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Master the Art of Customer Retention
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Join our network to provide a rewarding experience that guarantees satisfaction and keeps your registers ringing every single day.
        </p>
      </div>

      <div style={{ width: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 36, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 4 }}>Finish Your Payment</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 20 }}>Publish your shop instantly.</p>

          <div style={{ background: '#1565C0', borderRadius: 12, padding: '20px 24px', color: '#fff', marginBottom: 24 }}>
            <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>Price Summary</div>
            <div style={{ fontSize: 32, fontWeight: 700 }}>₹999</div>
            <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>Annually payment</div>
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
      </div>
    </div>
  )
}

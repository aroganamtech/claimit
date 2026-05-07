import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

export default function ShopRegister() {
  const navigate = useNavigate()
  const [form, setForm] = useState({
    shopName: '', shopAddress: '', pincode: '', about: ''
  })

  const handleChange = (k, v) => setForm(prev => ({ ...prev, [k]: v }))

  const handleContinue = () => {
    if (!form.shopName || !form.shopAddress || !form.pincode) return
    sessionStorage.setItem('shop_basic', JSON.stringify(form))
    navigate('/shop/onboard/photos')
  }

  const onboardSidebarItems = [
    'Unlock New Horizons for Your Shop',
  ]

  return (
    <div style={{ paddingTop: 64, display: 'flex', minHeight: '100vh' }}>
      {/* Left */}
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <div style={{
          width: 380, height: 280, background: '#f0f4ff',
          borderRadius: 12, border: '2px dashed #c5d5f0',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#90a4c8', fontSize: 15, marginBottom: 32
        }}>
          {/* image */}
        </div>
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Unlock New Horizons for Your Shop
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Partner with Claimit to expand your market reach and transform casual shoppers into dedicated brand advocates for your business.
        </p>
      </div>

      {/* Right */}
      <div style={{ width: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Shop Registration</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>Tell us about your business</p>

          <div style={{ marginBottom: 16 }}>
            <label style={labelStyle}>Shop Name</label>
            <input className="input-field" placeholder="your shop name"
              value={form.shopName} onChange={e => handleChange('shopName', e.target.value)} />
          </div>
          <div style={{ marginBottom: 16 }}>
            <label style={labelStyle}>Shop Address</label>
            <input className="input-field" placeholder="address of your shop"
              value={form.shopAddress} onChange={e => handleChange('shopAddress', e.target.value)} />
          </div>
          <div style={{ marginBottom: 16 }}>
            <button
              style={{
                width: '100%', padding: 13, border: '1.5px solid #ccc',
                borderRadius: 8, background: '#fff', fontSize: 14, cursor: 'pointer',
                fontFamily: 'Poppins', color: '#555'
              }}
            >
              📍 Use my current location
            </button>
          </div>
          <div style={{ marginBottom: 24 }}>
            <label style={labelStyle}>About Shop</label>
            <textarea
              className="input-field"
              placeholder="Short description About shop...."
              value={form.about}
              onChange={e => handleChange('about', e.target.value)}
              rows={3}
              style={{ resize: 'vertical' }}
            />
          </div>
          <button className="btn-primary" onClick={handleContinue}>Continue</button>
        </div>
      </div>
    </div>
  )
}

const labelStyle = { display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }

import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

export default function ChooseShopType() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState('')

  const handleContinue = () => {
    if (!selected) return
    sessionStorage.setItem('shop_type', selected)
    navigate('/shop/onboard/review')
  }

  return (
    <div style={{ paddingTop: 64, display: 'flex', minHeight: '100vh' }}>
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
          Turn One-Time Shoppers Into Lifelong Fans
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Use our seamless reward system to build deep connections with your customers and ensure they always choose your shop first.
        </p>
      </div>

      <div style={{ width: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Choose your Shop type</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>Select how customers will interact with your shop</p>

          {/* Reward Shop */}
          <div
            onClick={() => setSelected('reward')}
            style={{
              border: `1.5px solid ${selected === 'reward' ? '#1565C0' : '#eee'}`,
              borderRadius: 10, padding: '18px 20px', marginBottom: 14,
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 14,
              background: selected === 'reward' ? '#f0f4ff' : '#fff'
            }}
          >
            <div style={{
              width: 48, height: 48, borderRadius: '50%',
              background: '#fff3cd', display: 'flex', alignItems: 'center',
              justifyContent: 'center', fontSize: 24, flexShrink: 0
            }}>🎯</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, fontSize: 15 }}>Reward Shop</div>
              <div style={{ color: '#888', fontSize: 13, marginTop: 2 }}>Customers earn rewards here.</div>
            </div>
            <div style={{
              width: 20, height: 20, borderRadius: '50%',
              border: `2px solid ${selected === 'reward' ? '#1565C0' : '#bbb'}`,
              background: selected === 'reward' ? '#1565C0' : '#fff'
            }} />
          </div>

          {/* Redeem Shop */}
          <div
            onClick={() => setSelected('redeem')}
            style={{
              border: `1.5px solid ${selected === 'redeem' ? '#1565C0' : '#eee'}`,
              borderRadius: 10, padding: '18px 20px', marginBottom: 20,
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 14,
              background: selected === 'redeem' ? '#f0f4ff' : '#fff'
            }}
          >
            <div style={{
              width: 48, height: 48, borderRadius: '50%',
              background: '#e8f5e9', display: 'flex', alignItems: 'center',
              justifyContent: 'center', fontSize: 24, flexShrink: 0
            }}>🏪</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, fontSize: 15 }}>Redeem Shop</div>
              <div style={{ color: '#888', fontSize: 13, marginTop: 2 }}>Customers can redeem & rewards here.</div>
            </div>
            <div style={{
              width: 20, height: 20, borderRadius: '50%',
              border: `2px solid ${selected === 'redeem' ? '#1565C0' : '#bbb'}`,
              background: selected === 'redeem' ? '#1565C0' : '#fff'
            }} />
          </div>

          <button
            className="btn-primary"
            onClick={handleContinue}
            style={{ marginBottom: 12, opacity: selected ? 1 : 0.5 }}
            disabled={!selected}
          >
            Continue
          </button>
          <p style={{ textAlign: 'center', fontSize: 13, color: '#1565C0', cursor: 'pointer' }}>Know more?</p>
        </div>
      </div>
    </div>
  )
}

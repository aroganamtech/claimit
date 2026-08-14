import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

const DISCOUNT_OPTIONS = [5, 10, 15, 20, 25, 30]

const PLANS = [
  { id: 'premium',  name: 'Premium',  price: 720, note: 'Top placement + full visibility' },
  { id: 'standard', name: 'Standard', price: 365, note: 'Priority listing' },
  { id: 'other',    name: 'Other',    price: 0,   note: 'Enter any amount' },
]

export default function ChooseShopType() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState('')
  const [discount, setDiscount] = useState(15)   // default 15 %
  const [planId, setPlanId] = useState('premium')
  const [customAmount, setCustomAmount] = useState('')

  const planAmount = planId === 'other'
    ? Number(customAmount || 0)
    : (PLANS.find(p => p.id === planId)?.price || 0)

  const handleContinue = () => {
    if (!selected) return
    if (planId === 'other' && planAmount <= 0) return
    sessionStorage.setItem('shop_type', selected)
    sessionStorage.setItem('shop_discount', String(discount))
    sessionStorage.setItem('shop_plan', planId)
    sessionStorage.setItem('shop_amount', String(planAmount))
    navigate('/shop/onboard/review')
  }

  return (
    <div className="auth-layout">
      <div className="auth-left">
        <img
          src="/assets/images/redeem_reward.png"
          alt="Choose shop type"
          style={{ width: 450, height: 380, borderRadius: 12, marginBottom: 32 }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Turn One-Time Shoppers Into Lifelong Fans
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Use our seamless reward system to build deep connections with your customers and ensure they always choose your shop first.
        </p>
      </div>

      <div className="auth-right">
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

          {/* Discount % picker — shown only for Redeem Shop */}
          {selected === 'redeem' && (
            <div style={{
              background: '#f0f4ff', borderRadius: 10, padding: '16px 20px',
              marginBottom: 20, border: '1.5px solid #c5d0f0'
            }}>
              <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12, color: '#1565C0' }}>
                Set your discount percentage
              </div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {DISCOUNT_OPTIONS.map(pct => (
                  <button
                    key={pct}
                    onClick={() => setDiscount(pct)}
                    style={{
                      padding: '8px 16px', borderRadius: 8, fontWeight: 600,
                      fontSize: 14, cursor: 'pointer', fontFamily: 'Poppins',
                      border: discount === pct ? '2px solid #1565C0' : '1.5px solid #ccd4f0',
                      background: discount === pct ? '#1565C0' : '#fff',
                      color: discount === pct ? '#fff' : '#444',
                      transition: 'all 0.15s'
                    }}
                  >
                    {pct}%
                  </button>
                ))}
              </div>
              <div style={{ fontSize: 12, color: '#888', marginTop: 10 }}>
                Customers get <strong style={{ color: '#1565C0' }}>{discount}% off</strong> when they redeem rewards at your shop.
              </div>
            </div>
          )}

          {/* Plan picker — Premium / Standard / Other custom amount */}
          <div style={{ fontWeight: 700, fontSize: 15, margin: '4px 0 12px' }}>Choose your plan</div>
          {PLANS.map(p => (
            <div
              key={p.id}
              onClick={() => setPlanId(p.id)}
              style={{
                border: `1.5px solid ${planId === p.id ? '#1565C0' : '#eee'}`,
                borderRadius: 10, padding: '14px 18px', marginBottom: 10,
                cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 12,
                background: planId === p.id ? '#f0f4ff' : '#fff'
              }}
            >
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: 15 }}>{p.name}</div>
                <div style={{ color: '#888', fontSize: 12, marginTop: 2 }}>{p.note}</div>
              </div>
              <div style={{ fontWeight: 700, fontSize: 15, color: '#1565C0', whiteSpace: 'nowrap' }}>
                {p.id === 'other' ? 'Custom' : `₹${p.price}`}
              </div>
              <div style={{
                width: 20, height: 20, borderRadius: '50%', flexShrink: 0,
                border: `2px solid ${planId === p.id ? '#1565C0' : '#bbb'}`,
                background: planId === p.id ? '#1565C0' : '#fff'
              }} />
            </div>
          ))}
          {planId === 'other' && (
            <input
              type="number"
              min="1"
              placeholder="Enter amount (₹)"
              value={customAmount}
              onChange={e => setCustomAmount(e.target.value.replace(/[^0-9]/g, ''))}
              style={{
                width: '100%', padding: '12px 14px', border: '1.5px solid #ccd4f0',
                borderRadius: 10, fontSize: 15, boxSizing: 'border-box',
                fontFamily: 'inherit', marginBottom: 12
              }}
            />
          )}
          <div style={{ height: 8 }} />

          <button
            className="btn-primary"
            onClick={handleContinue}
            style={{ marginBottom: 12, opacity: (selected && !(planId === 'other' && planAmount <= 0)) ? 1 : 0.5 }}
            disabled={!selected || (planId === 'other' && planAmount <= 0)}
          >
            Continue
          </button>
          <p style={{ textAlign: 'center', fontSize: 13, color: '#1565C0', cursor: 'pointer' }}>Know more?</p>
        </div>
      </div>
    </div>
  )
}

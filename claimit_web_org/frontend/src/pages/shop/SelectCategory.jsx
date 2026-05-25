import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

const CATEGORIES = [
  'Supermarket', 'Grocery', 'Pharmacy', 'Bakery', 'Salon',
  'Gym', 'Electronics', 'Cafe', 'Restaurant', 'Clothing',
  'Footwear', 'Jewelry', 'Books', 'Toys', 'Hardware'
]

export default function SelectCategory() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState('')

  const handleContinue = () => {
    if (!selected) return
    sessionStorage.setItem('shop_category', selected)
    navigate('/shop/onboard/shop-type')
  }

  return (
    <div style={{ paddingTop: 64, display: 'flex', minHeight: '100vh' }}>
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <img
          src="/assets/shop-category.svg"
          alt="Select category"
          style={{ width: 380, height: 280, borderRadius: 12, marginBottom: 32 }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Elevate Your Brand Presence Today
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Stand out from the competition by joining a platform that prioritizes your business growth and customer satisfaction above all.
        </p>
      </div>

      <div style={{ width: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Select Business Category</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 24 }}>Select the category that best describes your shop</p>

          <select
            className="input-field"
            value={selected}
            onChange={e => setSelected(e.target.value)}
            style={{ marginBottom: 28 }}
          >
            <option value="">Select your business category</option>
            {CATEGORIES.map(c => (
              <option key={c} value={c.toLowerCase()}>{c}</option>
            ))}
          </select>

          <button
            className="btn-primary"
            onClick={handleContinue}
            style={{ opacity: selected ? 1 : 0.5 }}
            disabled={!selected}
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  )
}

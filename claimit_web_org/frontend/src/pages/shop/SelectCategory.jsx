import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

// Each label maps to a value (lowercase) that must exist in the backend
// _CATEGORY_MAP. Order + numbering match the app's category ids 1-20 and the
// icon assets icon1.png … icon20.png.
const CATEGORIES = [
  { label: 'Supermarkets',        value: 'supermarkets' },  // 1
  { label: 'Grocery / Provision', value: 'grocery'      },  // 2
  { label: 'Medical Stores',      value: 'medical'      },  // 3
  { label: 'Restaurants',         value: 'restaurants'  },  // 4
  { label: 'Mobile Stores',       value: 'mobile'       },  // 5
  { label: 'Electronics',         value: 'electronics'  },  // 6
  { label: 'Departmental',        value: 'departmental' },  // 7
  { label: 'Garment / Fashion',   value: 'garment'      },  // 8
  { label: 'Jewellery',           value: 'jewellery'    },  // 9
  { label: 'Footwears',           value: 'footwear'     },  // 10
  { label: 'Coffee Shops',        value: 'coffee'       },  // 11
  { label: 'Hospitals',           value: 'hospitals'    },  // 12
  { label: 'Optical Stores',      value: 'optical'      },  // 13
  { label: 'Diagnostics',         value: 'diagnostics'  },  // 14
  { label: 'Furniture Stores',    value: 'furniture'    },  // 15
  { label: 'Home Decor',          value: 'home decor'   },  // 16
  { label: 'Beauty Parlours',     value: 'beauty'       },  // 17
  { label: 'Salons',              value: 'salons'       },  // 18
  { label: 'Baby Stores',         value: 'baby'         },  // 19
  { label: 'Online Stores',       value: 'online'       },  // 20
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
    <div className="auth-layout">
      <div className="auth-left">
        <img
          src="/assets/images/shop_register.png"
          alt="Select category"
          style={{ width: 480, height: 450, borderRadius: 12, marginBottom: 32 }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Elevate Your Brand Presence Today
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Stand out from the competition by joining a platform that prioritizes your business growth and customer satisfaction above all.
        </p>
      </div>

      <div className="auth-right">
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
              <option key={c.value} value={c.value}>{c.label}</option>
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

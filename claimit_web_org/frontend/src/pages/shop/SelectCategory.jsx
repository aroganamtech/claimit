import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

// Each label maps to a value (lowercase) that must exist in the backend _CATEGORY_MAP
const CATEGORIES = [
  // Food & Grocery
  { label: 'Grocery',              value: 'grocery'            },  // 2
  { label: 'Supermarket',          value: 'supermarket'        },  // 3
  { label: 'Restaurant',           value: 'restaurant'         },  // 7
  { label: 'Cafe / Bakery',        value: 'cafe'               },  // 8
  // Health & Wellness
  { label: 'Pharmacy',             value: 'pharmacy'           },  // 4
  { label: 'Salon',                value: 'salon'              },  // 5
  { label: 'Spa',                  value: 'spa'                },  // 17
  { label: 'Gym / Fitness',        value: 'gym'                },  // 6
  { label: 'Clinics',              value: 'clinics'            },  // 21
  // Fashion & Lifestyle
  { label: 'Clothing',             value: 'clothing'           },  // 9
  { label: 'Footwear / Shoes',     value: 'footwear'           },  // 30
  { label: 'Jewellery',            value: 'jewellery'          },  // 29
  { label: 'Department Store',     value: 'department'         },  // 10
  // Electronics & Tech
  { label: 'Electronics',          value: 'electronics'        },  // 11
  { label: 'Mobile & Accessories', value: 'mobile'             },  // 26
  { label: 'Computer & Laptop',    value: 'computer'           },  // 27
  // Books, Toys & Kids
  { label: 'Books',                value: 'books'              },  // 12
  { label: 'Toys',                 value: 'toys'               },  // 13
  { label: 'Baby Products',        value: 'baby'               },  // 14
  // Home & Living
  { label: 'Home Decor',           value: 'home decor'         },  // 15
  { label: 'Furniture',            value: 'furniture'          },  // 16
  // Other
  { label: 'Pets',                 value: 'pets'               },  // 23
  { label: 'Sports',               value: 'sports'             },  // 24
  { label: 'Gifts',                value: 'gifts'              },  // 28
  { label: 'Hardware',             value: 'hardware'           },  // 1
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

import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

// Each label maps to a value (lowercase) that must exist in the backend
// _CATEGORY_MAP. Order + numbering match the app's category ids 1-20 and the
// icon assets icon1.png … icon20.png.
const CATEGORIES = [
  { label: 'Supermarkets',         value: 'supermarkets'        },  // 1
  { label: 'Fruits & Vegetables',  value: 'fruits_vegetables'   },  // 2
  { label: 'Pharmacies',           value: 'pharmacies'          },  // 3
  { label: 'Restaurants',          value: 'restaurants'         },  // 4
  { label: 'Cafes',                value: 'cafes'               },  // 5
  { label: 'Bakery & Sweets',      value: 'bakery_sweets'       },  // 6
  { label: 'Juices & Shakes',      value: 'juices_shakes'       },  // 7
  { label: 'Garments & Fashion',   value: 'garments_fashion'    },  // 8
  { label: 'Footwear',             value: 'footwear'            },  // 9
  { label: 'Mobile',               value: 'mobile'              },  // 10
  { label: 'Electronics',          value: 'electronics'         },  // 11
  { label: 'Salons',               value: 'salons'              },  // 12
  { label: 'Beauty Parlours',      value: 'beauty_parlours'     },  // 13
  { label: 'Dry Fruits & Nuts',    value: 'dry_fruits_nuts'     },  // 14
  { label: 'Fashion Accessories',  value: 'fashion_accessories' },  // 15
  { label: 'Optical',              value: 'optical'             },  // 16
  { label: 'Home Appliances',      value: 'home_appliances'     },  // 17
  { label: 'Furniture',            value: 'furniture'           },  // 18
  { label: 'Home Furnishing',      value: 'home_furnishing'     },  // 19
  { label: 'Baby Stores',          value: 'baby_stores'         },  // 20
  { label: 'Books & Stationery',   value: 'books_stationery'    },  // 21
  { label: 'Gifts & Fancy Stores', value: 'gifts_fancy'         },  // 22
  { label: 'Toys & Games',         value: 'toys_games'          },  // 23
  { label: 'Sports & Fitness',     value: 'sports_fitness'      },  // 24
  { label: 'Photography & Studios',value: 'photography_studios' },  // 25
  { label: 'Diagnostic Centres',   value: 'diagnostic_centres'  },  // 26
  { label: 'Hospitals',            value: 'hospitals'           },  // 27
  { label: 'Pet Stores',           value: 'pet_stores'          },  // 28
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

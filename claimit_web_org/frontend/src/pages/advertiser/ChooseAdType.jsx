import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'

const AD_TYPES = [
  {
    key: 'home_banner',
    title: 'Home Page banner Ad',
    desc: 'Video  /  Static Thumbnail',
    price: 840,
  },
 
  {
    key: 'brand_deals',
    title: 'Brand Deals Ad',
    desc: 'Thumbnail + Details of the Ad',
    price: 1400,
  },
  {
    key: 'nearby_deals',
    title: 'Nearby Deals Ad',
    desc: 'Thumbnail + Details of the Ad',
    price: 1400,
  },
   {
    key: 'promo_reelz',
    title: 'Promo Reelz Ad',
    desc: 'Video  /  Static Thumbnail',
    price: 1400,
  },
]

export default function ChooseAdType() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState(null)

  const handleNext = () => {
    if (!selected) return
    navigate(`/advertiser/create-ad/details?type=${selected}`)
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 32 }}>Choose Ad Type</h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, maxWidth: 900 }}>
          {AD_TYPES.map(ad => (
            <div
              key={ad.key}
              onClick={() => setSelected(ad.key)}
              style={{
                background: '#fff',
                border: `2px solid ${selected === ad.key ? '#1565C0' : '#eee'}`,
                borderRadius: 12,
                padding: 20,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: 16,
                transition: 'border 0.15s, box-shadow 0.15s',
                boxShadow: selected === ad.key ? '0 0 0 3px rgba(21,101,192,0.12)' : '0 2px 8px rgba(0,0,0,0.05)'
              }}
            >
              {/* Preview thumbnail */}
              <img
                src="/assets/ad-thumb.svg"
                alt={ad.title}
                style={{ width: 80, height: 100, borderRadius: 8, flexShrink: 0 }}
              />

              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 4 }}>{ad.title}</div>
                <div style={{ color: '#888', fontSize: 13, marginBottom: 8 }}>{ad.desc}</div>
                <div style={{ fontWeight: 700, fontSize: 18, color: '#1565C0' }}>₹{ad.price}</div>
                <div style={{ fontSize: 11, color: '#888' }}>Price includes 18% GST</div>
              </div>

              <div style={{
                width: 22, height: 22, borderRadius: '50%',
                border: `2px solid ${selected === ad.key ? '#1565C0' : '#bbb'}`,
                background: selected === ad.key ? '#1565C0' : '#fff',
                flexShrink: 0
              }} />
            </div>
          ))}
        </div>

        <div style={{ marginTop: 32, textAlign: 'right', maxWidth: 900 }}>
          <button
            className="btn-primary"
            style={{ width: 'auto', padding: '12px 40px', opacity: selected ? 1 : 0.5 }}
            onClick={handleNext}
            disabled={!selected}
          >
            Next
          </button>
        </div>
      </main>
    </div>
  )
}

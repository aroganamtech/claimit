import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

// Pricing per "Claimit Advertising Packages (Weekly)". Types with a
// `tiers` object let the advertiser pick Premium or Standard; home_banner
// is a single package (no tier split).
//
// Prices below are only the fallback shown until GET /advertiser/pricing
// resolves — that endpoint reads the same admin-configurable store the
// backend actually charges from (utils/pricing.py), so a price changed in
// the admin panel shows up here automatically.
const DEFAULT_AD_TYPES = [
  {
    key: 'home_banner',
    title: 'Home Page Hero Ad',
    desc: 'Video (15–20s) or Static Image — featured on the home page',
    tiers: { standard: 700 },
  },
  {
    key: 'brand_deals',
    title: 'Brand Deals Ad',
    desc: 'Thumbnail + Details of the Ad',
    tiers: { premium: 700, standard: 700 },
  },
  {
    key: 'nearby_deals',
    title: 'Nearby Deals Ad',
    desc: 'Thumbnail + Details of the Ad',
    tiers: { premium: 1050, standard: 700 },
  },
  {
    key: 'promo_reelz',
    title: 'Promo Reelz Ad',
    desc: 'Video  /  Static Thumbnail',
    tiers: { premium: 700, standard: 700 },
  },
]

// "?" info icon with a hover tooltip — explains the Premium vs Standard cost
// difference right where the advertiser is choosing a tier.
function InfoTooltip() {
  const [show, setShow] = useState(false)
  return (
    <span
      style={{ position: 'relative', display: 'inline-flex', marginLeft: 6, cursor: 'help' }}
      onMouseEnter={() => setShow(true)}
      onMouseLeave={() => setShow(false)}
      onClick={e => e.stopPropagation()}
    >
      <span style={{
        width: 15, height: 15, borderRadius: '50%', background: '#dbe4f0', color: '#1565C0',
        fontSize: 10, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>?</span>
      {show && (
        <div style={{
          position: 'absolute', bottom: '130%', left: '50%', transform: 'translateX(-50%)',
          background: '#222', color: '#fff', fontSize: 11.5, lineHeight: 1.5, padding: '10px 12px',
          borderRadius: 8, width: 230, zIndex: 20, boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
          textTransform: 'none', fontWeight: 400,
        }}>
          <b>Premium</b> ads always show at the TOP of the list, above every Standard ad.
          Nearby Deals Premium slots are limited per pincode; Brand Deals Premium slots
          are limited app-wide. <b>Standard</b> costs less and is ordered normally, below Premium.
        </div>
      )}
    </span>
  )
}

// Small Premium/Standard price pill, shown once a tiered ad type is selected.
// slotInfo (from GET /advertiser/premium-slots) drives the remaining-slots
// counter and disables Premium once the admin-configured cap is reached.
function TierPicker({ tiers, tier, onPick, slotInfo }) {
  const keys = Object.keys(tiers)
  if (keys.length <= 1) return null
  return (
    <div style={{ display: 'flex', gap: 8, marginTop: 10 }} onClick={e => e.stopPropagation()}>
      {keys.map(k => {
        const isPremium = k === 'premium'
        const full = isPremium && slotInfo && !slotInfo.location_scoped && slotInfo.remaining <= 0
        return (
          <div
            key={k}
            onClick={() => !full && onPick(k)}
            style={{
              flex: 1, textAlign: 'center', cursor: full ? 'not-allowed' : 'pointer',
              border: `1.5px solid ${tier === k ? '#1565C0' : '#e0e0e0'}`,
              background: full ? '#f5f5f5' : (tier === k ? '#eaf1fd' : '#fff'),
              borderRadius: 8, padding: '6px 10px', opacity: full ? 0.55 : 1,
            }}
          >
            <div style={{
              fontSize: 11, fontWeight: 700, color: tier === k ? '#1565C0' : '#666',
              textTransform: 'uppercase', display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {k}
              {isPremium && <InfoTooltip />}
            </div>
            <div style={{ fontSize: 13, fontWeight: 700, color: '#222' }}>₹{tiers[k]}</div>
            {isPremium && slotInfo && (
              <div style={{ fontSize: 10, color: full ? '#c62828' : '#2e7d32', marginTop: 2, fontWeight: 600 }}>
                {slotInfo.location_scoped
                  ? `Up to ${slotInfo.max} per pincode`
                  : full ? 'Fully booked' : `${slotInfo.remaining} of ${slotInfo.max} left`}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}

export default function ChooseAdType() {
  const navigate = useNavigate()
  const [selected, setSelected] = useState(null)
  const [tierByType, setTierByType] = useState({})
  // Premium slot availability per ad type, from GET /advertiser/premium-slots.
  // Brand Deals is a global pool so this shows real remaining count; Nearby
  // Deals is per-pincode, so until the advertiser enters a pincode (next
  // step) we only know the admin-configured cap, not the live remaining count.
  const [slotInfo, setSlotInfo] = useState({})
  const [adTypes, setAdTypes] = useState(DEFAULT_AD_TYPES)

  useEffect(() => {
    ['nearby_deals', 'brand_deals'].forEach(adType => {
      api.advertiser.getPremiumSlots(adType)
        .then(res => setSlotInfo(prev => ({ ...prev, [adType]: res })))
        .catch(() => {})
    })
  }, [])

  useEffect(() => {
    api.advertiser.getPricing()
      .then(pricing => setAdTypes(prev => prev.map(ad => ({
        ...ad,
        tiers: pricing[ad.key] || ad.tiers,
      }))))
      .catch(() => {}) // keep DEFAULT_AD_TYPES on failure
  }, [])

  const currentTier = (ad) => tierByType[ad.key] || Object.keys(ad.tiers)[0]

  const handleNext = () => {
    if (!selected) return
    const ad = adTypes.find(a => a.key === selected)
    const tier = currentTier(ad)
    // Guard against the slot filling up (or the count loading) after the
    // advertiser already clicked Premium — the backend re-checks this too,
    // but catching it here avoids a wasted trip to the details/payment steps.
    const info = slotInfo[ad.key]
    if (tier === 'premium' && info && !info.location_scoped && info.remaining <= 0) {
      alert(`All ${info.max} Premium slots for ${ad.title} are fully booked right now. Please choose Standard.`)
      return
    }
    navigate(`/advertiser/create-ad/details?type=${selected}&tier=${tier}`)
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 32 }}>Choose Ad Type</h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, maxWidth: 900 }}>
          {adTypes.map(ad => {
            const tier = currentTier(ad)
            const price = ad.tiers[tier]
            return (
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
                  <div style={{ fontWeight: 700, fontSize: 18, color: '#1565C0' }}>₹{price}<span style={{ fontSize: 12, fontWeight: 500 }}>/week</span></div>
                  <div style={{ fontSize: 11, color: '#888' }}>Price includes GST</div>

                  {selected === ad.key && (
                    <TierPicker
                      tiers={ad.tiers}
                      tier={tier}
                      onPick={(k) => setTierByType(prev => ({ ...prev, [ad.key]: k }))}
                      slotInfo={slotInfo[ad.key]}
                    />
                  )}
                </div>

                <div style={{
                  width: 22, height: 22, borderRadius: '50%',
                  border: `2px solid ${selected === ad.key ? '#1565C0' : '#bbb'}`,
                  background: selected === ad.key ? '#1565C0' : '#fff',
                  flexShrink: 0
                }} />
              </div>
            )
          })}
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

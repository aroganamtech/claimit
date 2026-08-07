import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

const AD_LABELS = {
  home_banner: 'Home Page Banner Ad',
  promo_reelz: 'Promo Reelz Ad',
  brand_deals: 'Brand Deals Ad',
  nearby_deals: 'Nearby Deals Ad',
}

// Pricing per "Claimit Advertising Packages (Weekly)" — kept in sync with
// ChooseAdType.jsx and the backend's AD_PRICES in routers/advertiser.py.
const AD_PRICES = {
  home_banner:  { standard: 700 },
  nearby_deals: { premium: 1050, standard: 700 },
  brand_deals:  { premium: 700,  standard: 700 },
  promo_reelz:  { premium: 700,  standard: 700 },
}

const TIER_LABELS = { premium: 'Premium', standard: 'Standard' }

const DEAL_CATEGORIES = [
  'Restaurant', 'Supermarket', 'Pharmacy', 'Salon', 'Gym',
  'Electronics', 'Clothing', 'Bakery', 'Café', 'Clinic',
  'Appliances', 'Camera', 'Department Store', 'Other'
]

const labelStyle = {
  display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8
}
const inputStyle = {
  width: '100%', padding: '10px 14px', border: '1.5px solid #e0e0e0',
  borderRadius: 8, fontSize: 14, fontFamily: 'Poppins, sans-serif',
  outline: 'none', background: '#fff'
}
const rowStyle = { marginBottom: 18 }

// ─── Shared upload box ────────────────────────────────────────────────────────
function UploadBox({ label, accept, file, onChange, hint }) {
  return (
    <div style={rowStyle}>
      {label && <label style={labelStyle}>{label}</label>}
      <label style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        justifyContent: 'center', border: '2px dashed #ddd', borderRadius: 10,
        padding: '28px 20px', cursor: 'pointer',
        background: file ? '#e8f5e9' : '#fafafa'
      }}>
        <input type="file" accept={accept} style={{ display: 'none' }} onChange={e => onChange(e.target.files[0])} />
        <span style={{ fontSize: 26, marginBottom: 6 }}>⬆</span>
        {file
          ? <span style={{ fontSize: 13, color: '#2e7d32', fontWeight: 600 }}>{file.name}</span>
          : <>
            <span style={{ fontSize: 13, color: '#666', fontWeight: 500 }}>Drop file here or browse</span>
            <span style={{ fontSize: 11, color: '#aaa', marginTop: 4 }}>{hint}</span>
          </>
        }
      </label>
    </div>
  )
}

// ─── Home Banner fields ───────────────────────────────────────────────────────
function HomeBannerFields({ data, onChange }) {
  return (
    <>
      <div style={rowStyle}>
        <label style={labelStyle}>Headline <span style={{ color: '#e53935' }}>*</span></label>
        <input className="input-field" placeholder="e.g. BEST DEALS NEAR YOU!" value={data.headline || ''} onChange={e => onChange('headline', e.target.value)} />
      </div>
      <div style={rowStyle}>
        <label style={labelStyle}>Sub-text <span style={{ color: '#e53935' }}>*</span></label>
        <input className="input-field" placeholder="e.g. Up to 50% off today" value={data.sub || ''} onChange={e => onChange('sub', e.target.value)} />
      </div>
      <div style={rowStyle}>
        <label style={labelStyle}>CTA Link (optional)</label>
        <input className="input-field" placeholder="https://yourwebsite.com" value={data.cta_link || ''} onChange={e => onChange('cta_link', e.target.value)} />
      </div>
    </>
  )
}

// ─── Promo Reelz fields ───────────────────────────────────────────────────────
// Shop details are NOT typed by hand — a mistyped name never matches a real
// shop, so the reel can't link to shop details in the app. Instead the owner
// enters their registered mobile number and we fetch their live (activated)
// shop from the DB and attach it. Only shops with a redeem/reward type show;
// bulk-uploaded sample shops are excluded.
function PromoReelzFields({ data, onChange }) {
  const [mobile, setMobile] = useState('')
  const [shops, setShops] = useState([])
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')

  const fetchShops = async () => {
    setMsg('')
    const digits = mobile.replace(/[^0-9]/g, '')
    if (digits.length < 10) { setMsg('Enter a valid 10-digit mobile number'); return }
    setBusy(true)
    setShops([])
    // Clear any previously picked shop when re-searching.
    onChange('shop_id', ''); onChange('shop_name', ''); onChange('shop_location', ''); onChange('shop_category', '')
    try {
      const res = await api.shop.lookupActiveByMobile(digits)
      const list = res.shops || []
      setShops(list)
      if (list.length === 0) {
        setMsg('No activated shop found for this number. Please create a shop first (register a Redeem or Reward shop), then come back to post your reel.')
      }
    } catch (e) {
      setMsg(e?.response?.data?.detail || 'Could not fetch shops. Try again.')
    } finally {
      setBusy(false)
    }
  }

  const pick = (s) => {
    onChange('shop_id', s.id)
    onChange('shop_name', s.shop_name)
    onChange('shop_location', s.location || s.address || '')
    onChange('shop_category', s.category || '')
  }

  return (
    <>
      <div style={rowStyle}>
        <label style={labelStyle}>Shop Mobile Number <span style={{ color: '#e53935' }}>*</span></label>
        <div style={{ display: 'flex', gap: 10 }}>
          <input className="input-field" placeholder="10-digit registered mobile number"
            value={mobile}
            onChange={e => setMobile(e.target.value.replace(/[^0-9]/g, '').slice(0, 10))}
            style={{ flex: 1 }} />
          <button type="button" onClick={fetchShops} disabled={busy}
            style={{
              padding: '10px 20px', border: 'none', borderRadius: 8,
              background: '#1565C0', color: '#fff', fontWeight: 700, fontSize: 14,
              cursor: busy ? 'default' : 'pointer', fontFamily: 'inherit', whiteSpace: 'nowrap',
              opacity: busy ? 0.6 : 1,
            }}>
            {busy ? 'Fetching…' : 'Fetch Shop'}
          </button>
        </div>
        <p style={{ fontSize: 12, color: '#888', marginTop: 6 }}>
          We fetch your live shop from Claimit — no manual typing, so the reel links to your real shop.
        </p>
      </div>

      {msg && (
        <div style={{
          background: '#fff8e1', border: '1px solid #ffe0a3', borderRadius: 8,
          padding: '10px 14px', color: '#8a6d00', fontSize: 13, marginBottom: 16,
        }}>{msg}</div>
      )}

      {shops.map(s => {
        const selected = data.shop_id === s.id
        return (
          <div key={s.id} onClick={() => pick(s)}
            style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: 14, marginBottom: 10,
              border: `1.5px solid ${selected ? '#1565C0' : '#e0e0e0'}`, borderRadius: 10,
              background: selected ? '#f0f4ff' : '#fff', cursor: 'pointer',
            }}>
            <input type="radio" checked={selected} readOnly />
            <div>
              <div style={{ fontWeight: 700, fontSize: 14 }}>{s.shop_name}</div>
              <div style={{ fontSize: 12, color: '#888' }}>
                {(s.location || s.address || '')}{s.shop_type ? ` · ${s.shop_type} shop` : ''}
              </div>
            </div>
          </div>
        )
      })}

      {data.shop_id && (
        <div style={{
          background: '#e8f5e9', border: '1px solid #b6e0ba', borderRadius: 8,
          padding: '10px 14px', color: '#2e7d32', fontSize: 13, marginBottom: 18,
        }}>
          Selected: <b>{data.shop_name}</b>
          {data.shop_location ? ` — ${data.shop_location}` : ''}
          {data.shop_category ? ` · ${data.shop_category}` : ''}
        </div>
      )}

      <div style={rowStyle}>
        <label style={labelStyle}>Reel Caption <span style={{ color: '#e53935' }}>*</span></label>
        <textarea className="input-field" placeholder="Write a catchy caption for your reel..." value={data.caption || ''} onChange={e => onChange('caption', e.target.value)} rows={3} style={{ resize: 'vertical' }} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 18 }}>
        <div>
          <label style={labelStyle}>Offer Text <span style={{ color: '#e53935' }}>*</span></label>
          <input className="input-field" placeholder="e.g. 40% Off on 3-Month Plan" value={data.offer || ''} onChange={e => onChange('offer', e.target.value)} />
        </div>
        <div>
          <label style={labelStyle}>Tag Line</label>
          <input className="input-field" placeholder="e.g. STAY FIT" value={data.tag || ''} onChange={e => onChange('tag', e.target.value)} />
        </div>
      </div>
    </>
  )
}

// ─── Deal fields (shared for brand_deals + nearby_deals) ──────────────────────
function DealFields({ data, onChange }) {
  return (
    <>
      <div style={rowStyle}>
        <label style={labelStyle}>Business / Brand Name <span style={{ color: '#e53935' }}>*</span></label>
        <input className="input-field" placeholder="e.g. Super Saravana Store" value={data.name || ''} onChange={e => onChange('name', e.target.value)} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 18 }}>
        <div>
          <label style={labelStyle}>Area / Location <span style={{ color: '#e53935' }}>*</span></label>
          <input className="input-field" placeholder="e.g. Anna Nagar, Chennai" value={data.location || ''} onChange={e => onChange('location', e.target.value)} />
        </div>
        <div>
          <label style={labelStyle}>Category <span style={{ color: '#e53935' }}>*</span></label>
          <select className="input-field" value={data.type || ''} onChange={e => onChange('type', e.target.value)}
            style={inputStyle}>
            <option value="">Select category</option>
            {DEAL_CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
      </div>
      <div style={rowStyle}>
        <label style={labelStyle}>Offer Text <span style={{ color: '#e53935' }}>*</span></label>
        <input className="input-field" placeholder="e.g. 25% Off on All Items" value={data.offer || ''} onChange={e => onChange('offer', e.target.value)} />
      </div>
      <div style={rowStyle}>
        <label style={labelStyle}>Deal Description <span style={{ color: '#e53935' }}>*</span></label>
        <textarea className="input-field" placeholder="Describe the deal details, terms, validity..." value={data.description || ''} onChange={e => onChange('description', e.target.value)} rows={3} style={{ resize: 'vertical' }} />
      </div>
      <div style={rowStyle}>
        <label style={labelStyle}>Full Address</label>
        <input className="input-field" placeholder="e.g. No.12, Main Road, Anna Nagar, Chennai - 600040" value={data.address || ''} onChange={e => onChange('address', e.target.value)} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 18 }}>
        <div>
          <label style={labelStyle}>Phone Number</label>
          <input className="input-field" placeholder="e.g. +91 98765 43210" value={data.phone || ''} onChange={e => onChange('phone', e.target.value)} />
        </div>
        <div>
          <label style={labelStyle}>Business Timings</label>
          <input className="input-field" placeholder="e.g. 9 AM – 9 PM Daily" value={data.timing || ''} onChange={e => onChange('timing', e.target.value)} />
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 18 }}>
        <div>
          <label style={labelStyle}>Distance from City Centre</label>
          <input className="input-field" placeholder="e.g. 4Km" value={data.distance || ''} onChange={e => onChange('distance', e.target.value)} />
        </div>
        <div>
          <label style={labelStyle}>Cashback Text</label>
          <input className="input-field" placeholder="e.g. 1% Cashback" value={data.cashback || ''} onChange={e => onChange('cashback', e.target.value)} />
        </div>
      </div>
      <div style={rowStyle}>
        <label style={labelStyle}>Tags (comma separated)</label>
        <input className="input-field" placeholder="e.g. grocery, fresh, offer" value={data.tags || ''} onChange={e => onChange('tags', e.target.value)} />
      </div>
    </>
  )
}

// ─── Phone preview per type ───────────────────────────────────────────────────
function PhonePreview({ adType, data, creativeFile, thumbnailFile }) {
  // Generate object URLs so we can show the actual uploaded image/video thumbnail
  const creativePreview  = creativeFile  ? URL.createObjectURL(creativeFile)  : null
  const thumbnailPreview = thumbnailFile ? URL.createObjectURL(thumbnailFile) : null
  const creativeIsVideo  = !!(creativeFile && creativeFile.type && creativeFile.type.startsWith('video/'))

  return (
    <div style={{ background: '#e8f0fe', borderRadius: 12, padding: 20, border: '1px solid #c5d5f0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <span style={{ fontWeight: 600, fontSize: 14 }}>Live Preview</span>
        <span style={{ fontSize: 12, color: '#888' }}>How it appears in app</span>
      </div>
      <div style={{ background: '#000', borderRadius: 36, padding: 10, boxShadow: '0 8px 32px rgba(0,0,0,0.25)', maxWidth: 280, margin: '0 auto' }}>
        <div style={{ background: '#fff', borderRadius: 28, overflow: 'hidden', minHeight: 500 }}>
          {/* App header */}
          <div style={{ background: '#1565C0', padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={{ color: '#fff', fontWeight: 700, fontSize: 13 }}>claimit</span>
            <span style={{ color: '#fff', fontSize: 11 }}>Anna Nagar ▾</span>
          </div>

          {adType === 'home_banner' && (
            creativePreview
              ? <div style={{ position: 'relative', height: 120, overflow: 'hidden' }}>
                  {creativeIsVideo
                    ? <video src={creativePreview} muted autoPlay loop playsInline style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : <img src={creativePreview} alt="banner" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  }
                  <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.38)', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', padding: '12px 14px' }}>
                    <div style={{ color: '#fff', fontWeight: 800, fontSize: 13, marginBottom: 3 }}>{data.headline || 'BANNER HEADLINE!'}</div>
                    <div style={{ color: 'rgba(255,255,255,0.85)', fontSize: 10 }}>{data.sub || 'Your sub-text appears here'}</div>
                    {data.cta_link && <div style={{ marginTop: 6, background: '#fff', color: '#1565C0', fontSize: 9, fontWeight: 700, padding: '3px 8px', borderRadius: 20, display: 'inline-block', width: 'fit-content' }}>Learn More →</div>}
                  </div>
                </div>
              : <div style={{ background: 'linear-gradient(135deg,#1565C0,#2563EB)', padding: 20, minHeight: 110, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                  <div style={{ color: '#fff', fontWeight: 800, fontSize: 14, marginBottom: 4 }}>{data.headline || 'BANNER HEADLINE!'}</div>
                  <div style={{ color: 'rgba(255,255,255,0.8)', fontSize: 11 }}>{data.sub || 'Your sub-text appears here'}</div>
                  {data.cta_link && <div style={{ marginTop: 8, background: '#fff', color: '#1565C0', fontSize: 10, fontWeight: 700, padding: '4px 10px', borderRadius: 20, display: 'inline-block', width: 'fit-content' }}>Learn More →</div>}
                </div>
          )}

          {adType === 'promo_reelz' && (
            <div style={{ padding: 12 }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: '#1565C0', marginBottom: 10 }}>▶ Promo Reelz</div>
              <div style={{ background: '#111', borderRadius: 10, height: 160, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10, position: 'relative', overflow: 'hidden' }}>
                {(thumbnailPreview || creativePreview) && (
                  <img src={thumbnailPreview || creativePreview} alt="thumb" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', borderRadius: 10 }} />
                )}
                <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.7) 0%, transparent 60%)', borderRadius: 10 }} />
                <span style={{ fontSize: 28, zIndex: 2 }}>▶</span>
                <div style={{ position: 'absolute', bottom: 8, left: 10, right: 10, zIndex: 2 }}>
                  <div style={{ color: '#fff', fontWeight: 700, fontSize: 12 }}>{data.shop_name || 'Brand Name'}</div>
                  <div style={{ color: 'rgba(255,255,255,0.7)', fontSize: 10 }}>{data.shop_location || 'Location'}</div>
                </div>
              </div>
              <div style={{ fontSize: 11, color: '#333', marginBottom: 4 }}>{data.caption || 'Your reel caption here...'}</div>
              <div style={{ fontSize: 11, color: '#1565C0', fontWeight: 600 }}>{data.offer || 'Offer text'}</div>
            </div>
          )}

          {(adType === 'nearby_deals' || adType === 'brand_deals') && (
            <div style={{ padding: '12px 12px' }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: '#1565C0', marginBottom: 10 }}>
                {adType === 'nearby_deals' ? '📍 Nearby Deals' : '⭐ Brand Deals'}
              </div>
              <div style={{ background: '#f8f9fa', borderRadius: 10, padding: 10, display: 'flex', gap: 10, alignItems: 'center', border: '1.5px solid #e8f0fe' }}>
                <div style={{ width: 60, height: 60, borderRadius: 8, background: '#e0e0e0', flexShrink: 0, overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>
                  {creativePreview
                    ? <img src={creativePreview} alt="ad" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : '🏪'
                  }
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: 12, marginBottom: 2 }}>{data.name || 'Business Name'}</div>
                  <div style={{ fontSize: 10, color: '#888', marginBottom: 3 }}>📍 {data.location || 'Area, City'}</div>
                  <div style={{ fontSize: 11, color: '#1565C0', fontWeight: 600, marginBottom: 4 }}>{data.offer || 'Your offer text'}</div>
                  <div style={{ display: 'flex', gap: 4 }}>
                    {data.distance && <span style={{ fontSize: 9, background: '#f3f4f6', padding: '2px 6px', borderRadius: 4, color: '#374151' }}>{data.distance}</span>}
                    {data.type && <span style={{ fontSize: 9, background: '#eff6ff', padding: '2px 6px', borderRadius: 4, color: '#2563EB' }}>{data.type}</span>}
                  </div>
                </div>
              </div>
              {[1, 2].map(i => (
                <div key={i} style={{ background: '#f8f9fa', borderRadius: 8, padding: 8, marginTop: 8, display: 'flex', gap: 8 }}>
                  <div style={{ width: 50, height: 44, background: '#e8e8e8', borderRadius: 6 }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ height: 7, background: '#e0e0e0', borderRadius: 4, marginBottom: 5, width: '70%' }} />
                    <div style={{ height: 5, background: '#e8e8e8', borderRadius: 4, width: '50%' }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Main component ───────────────────────────────────────────────────────────
export default function AdDetails() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const adType = searchParams.get('type') || 'nearby_deals'
  const tier = searchParams.get('tier') || Object.keys(AD_PRICES[adType] || { standard: 1 })[0] || 'standard'
  const price = (AD_PRICES[adType] || {})[tier] ?? Object.values(AD_PRICES[adType] || { 0: 700 })[0]

  // Generic fields (all types)
  const [pincode, setPincode] = useState('')
  const [creative, setCreative] = useState(null)      // image / video
  const [thumbnail, setThumbnail] = useState(null)     // promo_reelz thumbnail
  const [error, setError] = useState('')

  // Type-specific extra fields stored as a flat object
  const [extra, setExtra] = useState({})
  const updateExtra = (key, val) => setExtra(prev => ({ ...prev, [key]: val }))

  const validateAndContinue = () => {
    setError('')

    if (adType === 'home_banner') {
      if (!extra.headline || !extra.sub) { setError('Headline and sub-text are required'); return }
    } else if (adType === 'promo_reelz') {
      if (!extra.shop_id || !extra.shop_name) {
        setError('Fetch and select your shop by mobile number first'); return
      }
      if (!extra.caption || !extra.offer) {
        setError('Please fill the reel caption and offer text'); return
      }
    } else {
      // brand_deals / nearby_deals
      if (!extra.name || !extra.location || !extra.offer || !extra.description || !extra.type) {
        setError('Please fill all required fields (name, location, offer, description, category)'); return
      }
    }

    if (!pincode) { setError('Pincode is required'); return }

    const draft = {
      adType,
      tier,
      pincode,
      ...extra,
      // store creative filenames — actual files re-attached at publish
      _hasCreative: !!creative,
      _hasThumbnail: !!thumbnail,
    }
    sessionStorage.setItem('ad_draft', JSON.stringify(draft))
    // Store files in a way PublishAd can retrieve
    if (creative) sessionStorage.setItem('ad_creative_name', creative.name)
    if (thumbnail) sessionStorage.setItem('ad_thumb_name', thumbnail.name)

    navigate(`/advertiser/create-ad/publish?type=${adType}`, {
      state: { creative, thumbnail }
    })
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 28 }}>
          Add Details — {AD_LABELS[adType] || 'Ad'}
        </h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, maxWidth: 1100 }}>
          {/* ── Left: form ─────────────────────────────────────── */}
          <div>
            {error && (
              <div style={{ background: '#fff3f3', border: '1px solid #ffcdd2', borderRadius: 8, padding: '10px 14px', color: '#e53935', fontSize: 13, marginBottom: 16 }}>
                {error}
              </div>
            )}

            {/* Ad Information card */}
            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24, marginBottom: 20 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Ad Information</h3>

              {adType === 'home_banner' && <HomeBannerFields data={extra} onChange={updateExtra} />}
              {adType === 'promo_reelz' && <PromoReelzFields data={extra} onChange={updateExtra} />}
              {(adType === 'brand_deals' || adType === 'nearby_deals') && <DealFields data={extra} onChange={updateExtra} />}
            </div>

            {/* Creative upload */}
            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24, marginBottom: 20 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>
                {(adType === 'promo_reelz' || adType === 'home_banner') ? 'Video / Image Upload' : 'Creative Upload'}
              </h3>
              <UploadBox
                accept={
                  adType === 'promo_reelz'
                    ? 'video/mp4,video/quicktime'
                    : adType === 'home_banner'
                      ? 'video/mp4,video/quicktime,image/jpeg,image/png'
                      : 'image/jpeg,image/png'
                }
                file={creative}
                onChange={setCreative}
                hint={
                  adType === 'promo_reelz'
                    ? 'MP4 video (Max 100MB)'
                    : adType === 'home_banner'
                      ? 'Image (JPG/PNG, max 10MB) or Video (MP4, ~14s recommended, max 100MB)'
                      : 'JPG, PNG (Max 10MB)'
                }
                label={
                  adType === 'promo_reelz'
                    ? 'Reel Video'
                    : adType === 'home_banner'
                      ? 'Banner Image or Video'
                      : 'Ad Image / Banner'
                }
              />
              {adType === 'promo_reelz' && (
                <UploadBox
                  label="Thumbnail Image"
                  accept="image/jpeg,image/png"
                  file={thumbnail}
                  onChange={setThumbnail}
                  hint="JPG, PNG (Max 5MB) — shown before video plays"
                />
              )}
            </div>

            {/* Location */}
            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24, marginBottom: 20 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Location &amp; Targeting</h3>
              <label style={labelStyle}>Pincode <span style={{ color: '#e53935' }}>*</span></label>
              <input className="input-field" placeholder="Enter target pincode" value={pincode} onChange={e => setPincode(e.target.value)} />
              <p style={{ fontSize: 12, color: '#888', marginTop: 6 }}>Your ad will be shown to users in this area.</p>
            </div>

            {/* Price summary */}
            <div style={{ background: '#1565C0', borderRadius: 12, padding: 24, color: '#fff', marginBottom: 20 }}>
              <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>
                Price Summary {TIER_LABELS[tier] ? `· ${TIER_LABELS[tier]}` : ''}
              </div>
              <div style={{ fontSize: 28, fontWeight: 700 }}>₹{price}</div>
              <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>Price includes GST · 7-day campaign</div>
            </div>

            <button className="btn-primary" onClick={validateAndContinue}>Continue →</button>
          </div>

          {/* ── Right: live preview ────────────────────────────── */}
          <div>
            <PhonePreview adType={adType} data={extra} creativeFile={creative} thumbnailFile={thumbnail} />
          </div>
        </div>
      </main>
    </div>
  )
}

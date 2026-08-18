import { useState } from 'react'
import { useNavigate, useSearchParams, useLocation } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

const AD_LABELS = {
  home_banner: 'Home Page Banner Ad',
  promo_reelz: 'Promo Reelz Ad',
  brand_deals: 'Brand Deals Ad',
  nearby_deals: 'Nearby Deals Ad',
}

// Pricing per "Claimit Advertising Packages (Weekly)" — kept in sync with
// ChooseAdType.jsx, AdDetails.jsx and the backend's AD_PRICES in
// routers/advertiser.py. Needed here because payment now happens BEFORE
// the ad is created, so we have to know the amount client-side to open the
// Cashfree checkout.
const AD_PRICES = {
  home_banner:  { standard: 700 },
  nearby_deals: { premium: 1050, standard: 700 },
  brand_deals:  { premium: 700,  standard: 700 },
  promo_reelz:  { premium: 700,  standard: 700 },
}

export default function PublishAd() {
  const navigate = useNavigate()
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const adType = searchParams.get('type') || 'nearby_deals'
  const [publishOption, setPublishOption] = useState('today')
  const [scheduleDate, setScheduleDate] = useState('')
  const [loading, setLoading] = useState(false)

  // Files were passed via router state from AdDetails
  const creative = location.state?.creative || null
  const thumbnail = location.state?.thumbnail || null
  const [uploadProgress, setUploadProgress] = useState('')

  // ── Direct-to-S3 upload helper ────────────────────────────────────────────
  // Gets a presigned PUT URL from backend, then PUTs file directly to S3.
  // This bypasses Vercel's 4.5 MB limit — works for videos up to 100 MB.
  const uploadToS3 = async (file, folder) => {
    if (!file) return null

    // Step 1: get presigned upload URL from backend
    const presignRes = await api.advertiser.presignUpload({
      filename: file.name,
      content_type: file.type,
      folder,
    })

    // Step 2: PUT file directly to S3 (no auth header — presigned URL is self-contained)
    const putRes = await fetch(presignRes.upload_url, {
      method: 'PUT',
      headers: { 'Content-Type': file.type },
      body: file,
    })
    if (!putRes.ok) throw new Error(`S3 upload failed: ${putRes.status}`)

    return presignRes.key  // S3 key to store in MongoDB
  }

  const handlePublish = async () => {
    const draft = JSON.parse(sessionStorage.getItem('ad_draft') || '{}')
    setLoading(true)
    try {
      // ── Upload files directly to S3 ───────────────────────────
      // promo_reelz is always video; home_banner can be either — detect by
      // the actual uploaded file's content type so home_banner videos route
      // to the video S3 folder/bucket correctly.
      const isVideo = adType === 'promo_reelz' || !!(creative && creative.type && creative.type.startsWith('video/'))
      let creativeKey = null
      let thumbnailKey = null

      if (creative) {
        setUploadProgress(isVideo ? 'Uploading video…' : 'Uploading image…')
        creativeKey = await uploadToS3(creative, isVideo ? 'ads-video' : 'ads')
      }
      if (thumbnail) {
        setUploadProgress('Uploading…')
        thumbnailKey = await uploadToS3(thumbnail, 'ads-video/thumbnails')
      }

      // ── Build the create-ad payload, but don't submit it yet ──────────
      // Payment now happens BEFORE the ad is created (real Cashfree
      // checkout, not a fake success screen). We stash everything needed
      // to finish the job — including the already-uploaded S3 keys — and
      // hand off to the Payment page, which submits this payload with a
      // verified payment_link_id attached once Cashfree confirms PAID.
      setUploadProgress('Preparing payment…')
      const skip = new Set(['adType', 'pincode', '_hasCreative', '_hasThumbnail'])
      const payload = {
        ad_type: draft.adType || adType,
        pincode: draft.pincode || '000000',
        publish_today: publishOption === 'today',
        scheduled_date: publishOption === 'schedule' ? scheduleDate : undefined,
        creative_key: creativeKey,
        thumbnail_key: thumbnailKey,
      }
      Object.entries(draft).forEach(([k, v]) => {
        if (!skip.has(k) && v !== undefined && v !== null) payload[k] = v
      })

      const tier = draft.tier || 'standard'
      const amount = (AD_PRICES[adType] || {})[tier] ?? Object.values(AD_PRICES[adType] || { standard: 700 })[0]

      sessionStorage.setItem('pending_ad_payload', JSON.stringify({
        payload,
        amount,
        adTypeLabel: AD_LABELS[adType],
      }))
      sessionStorage.removeItem('ad_draft')
      sessionStorage.removeItem('ad_creative_name')
      sessionStorage.removeItem('ad_thumb_name')

      navigate('/advertiser/create-ad/payment')
    } catch (e) {
      console.error(e)
      alert(e?.response?.data?.detail || e?.message || 'Failed to publish ad. Please try again.')
    } finally {
      setLoading(false)
      setUploadProgress('')
    }
  }

  // ── Build a summary of what the user filled in ────────────────
  const draft = (() => { try { return JSON.parse(sessionStorage.getItem('ad_draft') || '{}') } catch { return {} } })()

  const summaryFields = []
  if (draft.headline) summaryFields.push(['Headline', draft.headline])
  if (draft.name) summaryFields.push(['Business', draft.name])
  if (draft.shop_name) summaryFields.push(['Brand', draft.shop_name])
  if (draft.offer) summaryFields.push(['Offer', draft.offer])
  if (draft.location || draft.shop_location) summaryFields.push(['Location', draft.location || draft.shop_location])
  if (draft.type || draft.shop_category) summaryFields.push(['Category', draft.type || draft.shop_category])
  if (draft.pincode) summaryFields.push(['Pincode', draft.pincode])

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 28 }}>Publish the Ad</h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, maxWidth: 1100 }}>
          {/* Left */}
          <div>
            {/* Duration */}
            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24, marginBottom: 20 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Duration of Ad</h3>
              <div style={{ display: 'flex', alignItems: 'center', gap: 16, background: '#f8f9fa', borderRadius: 10, padding: '16px 20px' }}>
                <div style={{ background: '#1565C0', color: '#fff', borderRadius: 10, padding: '12px 16px', fontWeight: 700, fontSize: 16, minWidth: 70, textAlign: 'center' }}>
                  7 Days
                </div>
                <p style={{ color: '#666', fontSize: 13 }}>
                  All advertisements run for a fixed duration of 7 days and will be shown to customers in the app.
                </p>
              </div>
            </div>

            {/* Schedule */}
            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24, marginBottom: 24 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 6 }}>Schedule Publish</h3>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 20 }}>
                Choose when your ad should go live. You can schedule up to 10 days in advance.
              </p>

              {/* Today */}
              <div onClick={() => setPublishOption('today')} style={{ border: `1.5px solid ${publishOption === 'today' ? '#1565C0' : '#e0e0e0'}`, borderRadius: 10, padding: '16px 20px', marginBottom: 12, cursor: 'pointer' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 20, height: 20, borderRadius: '50%', border: `2px solid ${publishOption === 'today' ? '#1565C0' : '#bbb'}`, background: publishOption === 'today' ? '#1565C0' : '#fff', flexShrink: 0 }} />
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>Publish Today</div>
                    <div style={{ color: '#888', fontSize: 13 }}>Your ad will go live immediately and run for 7 days.</div>
                  </div>
                </div>
              </div>

              {/* Schedule */}
              <div onClick={() => setPublishOption('schedule')} style={{ border: `1.5px solid ${publishOption === 'schedule' ? '#1565C0' : '#e0e0e0'}`, borderRadius: 10, padding: '16px 20px', cursor: 'pointer' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 20, height: 20, borderRadius: '50%', border: `2px solid ${publishOption === 'schedule' ? '#1565C0' : '#bbb'}`, background: publishOption === 'schedule' ? '#1565C0' : '#fff', flexShrink: 0 }} />
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>Schedule Ad</div>
                    <div style={{ color: '#888', fontSize: 13 }}>Pick a future date (up to 10 days from today).</div>
                  </div>
                </div>
              </div>

              {publishOption === 'schedule' && (
                <div style={{ marginTop: 16 }}>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }}>Select Publish Date</label>
                  <input type="date" className="input-field" value={scheduleDate} onChange={e => setScheduleDate(e.target.value)} />
                  <p style={{ fontSize: 12, color: '#888', marginTop: 6 }}>You can schedule up to 10 days from today.</p>
                </div>
              )}
            </div>

            <button className="btn-primary" onClick={handlePublish} disabled={loading}>
              {loading ? (uploadProgress || 'Publishing…') : 'Publish Now'}
            </button>
          </div>

          {/* Right — summary */}
          <div>
            <div style={{ background: '#e8f0fe', borderRadius: 12, padding: 24 }}>
              <div style={{ fontWeight: 700, fontSize: 16, marginBottom: 4 }}>Ad Summary</div>
              <div style={{ fontSize: 13, color: '#1565C0', fontWeight: 600, marginBottom: 16 }}>{AD_LABELS[adType]}</div>

              {summaryFields.length > 0 && (
                <div style={{ background: '#fff', borderRadius: 10, padding: 16, marginBottom: 16 }}>
                  {summaryFields.map(([k, v]) => (
                    <div key={k} style={{ display: 'flex', gap: 8, marginBottom: 8, fontSize: 13 }}>
                      <span style={{ color: '#888', minWidth: 80 }}>{k}:</span>
                      <span style={{ fontWeight: 600, color: '#222', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{v}</span>
                    </div>
                  ))}
                </div>
              )}

              {(creative || sessionStorage.getItem('ad_creative_name')) && (
                <div style={{ background: '#e8f5e9', borderRadius: 8, padding: '10px 14px', fontSize: 13, color: '#2e7d32', marginBottom: 12 }}>
                  ✓ Creative file attached
                </div>
              )}
              {(thumbnail || sessionStorage.getItem('ad_thumb_name')) && (
                <div style={{ background: '#e8f5e9', borderRadius: 8, padding: '10px 14px', fontSize: 13, color: '#2e7d32', marginBottom: 12 }}>
                  ✓ Thumbnail attached
                </div>
              )}

              {/* Phone mockup */}
              <div style={{ background: '#000', borderRadius: 32, padding: 8, boxShadow: '0 8px 32px rgba(0,0,0,0.25)', maxWidth: 240, margin: '16px auto 0' }}>
                <div style={{ background: '#fff', borderRadius: 26, overflow: 'hidden', minHeight: 380 }}>
                  <div style={{ background: '#1565C0', padding: '10px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ color: '#fff', fontWeight: 700, fontSize: 12 }}>claimit</span>
                    <span style={{ color: '#fff', fontSize: 10 }}>Anna Nagar ▾</span>
                  </div>
                  <div style={{ padding: 10 }}>
                    <div style={{ fontSize: 10, fontWeight: 600, color: '#1565C0', marginBottom: 8 }}>
                      {adType === 'nearby_deals' ? '📍 Nearby Deals' : adType === 'brand_deals' ? '⭐ Brand Deals' : adType === 'promo_reelz' ? '▶ Promo Reelz' : '🏠 Home Banner'}
                    </div>
                    <div style={{ background: '#f8f9fa', borderRadius: 8, padding: 10, display: 'flex', gap: 8 }}>
                      <div style={{ width: 44, height: 44, background: '#e0e0e0', borderRadius: 6, flexShrink: 0 }} />
                      <div>
                        <div style={{ fontWeight: 700, fontSize: 10, marginBottom: 2 }}>
                          {draft.name || draft.shop_name || draft.headline || 'Your Ad'}
                        </div>
                        <div style={{ fontSize: 9, color: '#1565C0' }}>
                          {draft.offer || draft.caption || draft.sub || ''}
                        </div>
                        <div style={{ fontSize: 8, color: '#888', marginTop: 2 }}>{draft.location || draft.shop_location || ''}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

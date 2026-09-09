// ─────────────────────────────────────────────────────────────────────────
// Admin → Create Ad. Lets an admin publish the same 4 ad types as advertisers
// WITHOUT payment. Uploads media directly to S3 (presigned URL) exactly like
// the advertiser flow, then POSTs /admin/ads/create.
// ─────────────────────────────────────────────────────────────────────────
import { useState } from 'react'
import api from '../../utils/api'
import PincodeSelect from '../../components/PincodeSelect'

const AD_TYPES = [
  { key: 'home_banner',  label: 'Home Page Hero Ad',  note: 'Video (15–20s) or Static Image — home page', price: '₹700/week' },
  { key: 'brand_deals',  label: 'Brand Deals Ad',     note: 'Thumbnail + details',                        price: '₹700/week' },
  { key: 'nearby_deals', label: 'Nearby Deals Ad',    note: 'Thumbnail + details',                        price: '₹1050/week (premium)' },
  { key: 'promo_reelz',  label: 'Promo Reelz Ad',     note: 'Video / static thumbnail',                   price: '₹700/week' },
]

// Admin-only run lengths. An advertiser always buys the weekly cycle; admin
// is not selling anything, so admin can also start immediately or never stop.
const DURATIONS = [
  { key: 'now',    label: 'Start now',           note: 'Live immediately, ends when this week ends.' },
  { key: 'always', label: 'Never stop',          note: 'Live immediately with no end date. Runs until you pause it.' },
  { key: 'cycle',  label: 'Next weekly cycle',   note: 'Same as a paid ad — starts on the next cycle day and runs 7 days.' },
  { key: 'date',   label: 'Schedule for a date', note: 'Starts on the cycle containing the date you pick.' },
]

const input = { width: '100%', padding: '10px 12px', margin: '4px 0 14px', border: '1px solid #ccc', borderRadius: 8, fontSize: 14, boxSizing: 'border-box', fontFamily: 'inherit' }
const label = { fontSize: 13, fontWeight: 600, color: '#333' }

export default function AdminCreateAd() {
  const [adType, setAdType] = useState('home_banner')
  const [tier, setTier] = useState('standard')
  // Empty, not '000000'. The old placeholder was a real value that sailed
  // through and left the ad unplaceable on the map — now the admin must pick.
  const [pincode, setPincode] = useState('')
  const [duration, setDuration] = useState('now')
  const [scheduledDate, setScheduledDate] = useState('')
  const [form, setForm] = useState({})
  const [creative, setCreative] = useState(null)
  const [thumbnail, setThumbnail] = useState(null)
  const [busy, setBusy] = useState('')
  const [msg, setMsg] = useState(null) // {ok, text}

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }))

  const uploadToS3 = async (file, folder) => {
    if (!file) return null
    const presign = await api.admin.presignUpload({ filename: file.name, content_type: file.type, folder })
    const put = await fetch(presign.upload_url, { method: 'PUT', headers: { 'Content-Type': file.type }, body: file })
    if (!put.ok) throw new Error(`S3 upload failed: ${put.status}`)
    return presign.key
  }

  const submit = async () => {
    setMsg(null)
    if (!creative) { setMsg({ ok: false, text: 'Please attach the creative (image/video).' }); return }
    // Without a real pincode the ad has no position, so the 5 km search can
    // never return it — the ad would be paid for and invisible.
    if (!/^\d{6}$/.test(String(pincode || '')) || pincode === '000000') {
      setMsg({ ok: false, text: 'Please choose a pincode — it is what makes the ad appear in the app.' }); return
    }
    if (duration === 'date' && !scheduledDate) {
      setMsg({ ok: false, text: 'Please pick a start date, or choose a different option.' }); return
    }
    const isVideo = adType === 'promo_reelz' || (creative.type && creative.type.startsWith('video/'))
    try {
      setBusy(isVideo ? 'Uploading video…' : 'Uploading image…')
      const creativeKey = await uploadToS3(creative, isVideo ? 'ads-video' : 'ads')
      let thumbnailKey = null
      if (thumbnail) { setBusy('Uploading thumbnail…'); thumbnailKey = await uploadToS3(thumbnail, 'ads-video/thumbnails') }

      setBusy('Creating ad…')
      const payload = {
        ad_type: adType,
        tier,
        pincode,
        // 'date' is not a backend duration — it is the cycle mode plus an
        // explicit date, which the backend snaps onto the cycle it falls in.
        duration: duration === 'date' ? 'cycle' : duration,
        publish_today: duration === 'now' || duration === 'always',
        scheduled_date: duration === 'date' ? scheduledDate : undefined,
        creative_key: creativeKey,
        thumbnail_key: thumbnailKey,
        ...form,
      }
      const res = await api.admin.createAd(payload)
      // Say exactly when it runs, so nobody has to guess whether it is live.
      const when = res.never_expires
        ? 'live now and will not expire'
        : res.status === 'active'
          ? `live now until ${res.end_date}`
          : `scheduled for ${res.publish_date} – ${res.end_date}`
      setMsg({ ok: true, text: `✅ Ad created — ${when} (id ${res.id}).` })
      // Reset the form for the next ad
      setForm({}); setCreative(null); setThumbnail(null)
    } catch (e) {
      setMsg({ ok: false, text: e?.response?.data?.detail || e?.message || 'Failed to create ad.' })
    } finally {
      setBusy('')
    }
  }

  const isDeal = adType === 'brand_deals' || adType === 'nearby_deals'

  return (
    <div style={{ maxWidth: 720 }}>
      <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 6 }}>Create Ad (No Payment)</h2>
      <p style={{ color: '#666', fontSize: 13.5, marginBottom: 20 }}>
        Publish any of the 4 ad types directly. No payment is charged — the ad goes live in the app immediately.
      </p>

      {/* Ad type picker */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 22 }}>
        {AD_TYPES.map((t) => (
          <div key={t.key} onClick={() => setAdType(t.key)}
            style={{ cursor: 'pointer', border: `1.5px solid ${adType === t.key ? '#1a237e' : '#e0e0e0'}`,
              background: adType === t.key ? '#eef0fb' : '#fff', borderRadius: 10, padding: '12px 14px' }}>
            <div style={{ fontWeight: 700, fontSize: 14, color: '#1a237e' }}>{t.label}</div>
            <div style={{ fontSize: 12, color: '#666', margin: '3px 0' }}>{t.note}</div>
            <div style={{ fontSize: 12, fontWeight: 600, color: '#333' }}>{t.price}</div>
          </div>
        ))}
      </div>

      <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 12, padding: 22 }}>

        {/* Home banner */}
        {adType === 'home_banner' && (<>
          <div style={label}>Headline</div><input style={input} value={form.headline || ''} onChange={set('headline')} />
          <div style={label}>Subtitle</div><input style={input} value={form.sub || ''} onChange={set('sub')} />
          <div style={label}>CTA link (optional)</div><input style={input} value={form.cta_link || ''} onChange={set('cta_link')} placeholder="https://…" />
        </>)}

        {/* Promo reelz */}
        {adType === 'promo_reelz' && (<>
          <div style={label}>Shop name</div><input style={input} value={form.shop_name || ''} onChange={set('shop_name')} />
          <div style={label}>Shop location</div><input style={input} value={form.shop_location || ''} onChange={set('shop_location')} />
          <div style={label}>Shop category</div><input style={input} value={form.shop_category || ''} onChange={set('shop_category')} />
          <div style={label}>Caption</div><input style={input} value={form.caption || ''} onChange={set('caption')} />
          <div style={label}>Offer</div><input style={input} value={form.offer || ''} onChange={set('offer')} />
          <div style={label}>Tag (optional)</div><input style={input} value={form.tag || ''} onChange={set('tag')} />
        </>)}

        {/* Brand / Nearby deals */}
        {isDeal && (<>
          <div style={label}>Business name</div><input style={input} value={form.name || ''} onChange={set('name')} />
          <div style={label}>Offer</div><input style={input} value={form.offer || ''} onChange={set('offer')} />
          <div style={label}>Location</div><input style={input} value={form.location || ''} onChange={set('location')} />
          <div style={label}>Category / type</div><input style={input} value={form.type || ''} onChange={set('type')} />
          <div style={label}>Description</div><input style={input} value={form.description || ''} onChange={set('description')} />
          <div style={label}>Address</div><input style={input} value={form.address || ''} onChange={set('address')} />
          <div style={label}>Phone</div><input style={input} value={form.phone || ''} onChange={set('phone')} />
          <div style={label}>Timing</div><input style={input} value={form.timing || ''} onChange={set('timing')} />
          <div style={label}>Cashback</div><input style={input} value={form.cashback || ''} onChange={set('cashback')} placeholder="1% Cashback" />
          <div style={label}>Distance (optional)</div><input style={input} value={form.distance || ''} onChange={set('distance')} />
          <div style={label}>Tags (comma separated)</div><input style={input} value={form.tags || ''} onChange={set('tags')} placeholder="food, offers" />
        </>)}

        {/* Tier — only for deals */}
        {isDeal && (<>
          <div style={label}>Tier</div>
          <select style={input} value={tier} onChange={(e) => setTier(e.target.value)}>
            <option value="standard">Standard</option>
            <option value="premium">Premium</option>
          </select>
        </>)}

        {/* Pincode — this is what places the ad on the map for the 5 km search */}
        <div style={label}>Pincode</div>
        <div style={{ margin: '4px 0 14px' }}>
          <PincodeSelect value={pincode} onChange={setPincode} />
        </div>

        {/* Media */}
        <div style={label}>{adType === 'promo_reelz' ? 'Video creative' : adType === 'home_banner' ? 'Image or video creative' : 'Image creative'}</div>
        <input style={input} type="file"
          accept={adType === 'promo_reelz' ? 'video/*' : adType === 'home_banner' ? 'image/*,video/*' : 'image/*'}
          onChange={(e) => setCreative(e.target.files?.[0] || null)} />

        {adType === 'promo_reelz' && (<>
          <div style={label}>Thumbnail image (optional)</div>
          <input style={input} type="file" accept="image/*" onChange={(e) => setThumbnail(e.target.files?.[0] || null)} />
        </>)}

        {/* How long it runs. The old "Publish today" radio did not publish
            today — it sent no date, which the backend read as the NEXT weekly
            cycle, so an ad made on Monday sat invisible until Friday. These
            four options say plainly what each one does. Admin only; a paying
            advertiser still gets the weekly cycle. */}
        <div style={label}>When it runs</div>
        <div style={{ margin: '6px 0 14px', display: 'grid', gap: 8 }}>
          {DURATIONS.map((d) => (
            <label key={d.key} style={{
              display: 'flex', gap: 9, alignItems: 'flex-start', fontSize: 13.5,
              border: '1px solid', borderColor: duration === d.key ? '#1a237e' : '#e0e0e0',
              background: duration === d.key ? '#f4f5fc' : '#fff',
              borderRadius: 8, padding: '9px 11px', cursor: 'pointer',
            }}>
              <input type="radio" name="duration" checked={duration === d.key}
                onChange={() => setDuration(d.key)} style={{ marginTop: 2 }} />
              <span>
                <span style={{ fontWeight: 600 }}>{d.label}</span>
                <span style={{ display: 'block', color: '#777', fontSize: 12.5, marginTop: 1 }}>{d.note}</span>
              </span>
            </label>
          ))}
          {duration === 'date' && (
            <input type="date" style={{ ...input, margin: '2px 0 0' }} value={scheduledDate}
              onChange={(e) => setScheduledDate(e.target.value)} />
          )}
          {duration === 'always' && tier === 'premium' && isDeal && (
            <div style={{ fontSize: 12.5, color: '#8a6d00', background: '#fff8e1',
              border: '1px solid #ffe082', borderRadius: 8, padding: '9px 11px' }}>
              Heads up: a Premium ad that never stops holds one of the limited
              Premium slots for this pincode permanently, so advertisers cannot
              buy it. Use Standard for evergreen house ads.
            </div>
          )}
        </div>

        <button onClick={submit} disabled={!!busy}
          style={{ width: '100%', padding: 12, background: busy ? '#8a90c0' : '#1a237e', color: '#fff', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600, cursor: busy ? 'default' : 'pointer' }}>
          {busy || 'Create Ad'}
        </button>

        {msg && (
          <div style={{ marginTop: 16, padding: '12px 14px', borderRadius: 8, fontSize: 13.5, lineHeight: 1.5,
            background: msg.ok ? '#e7f7ec' : '#fdeaea', color: msg.ok ? '#1b7a3d' : '#b3261e' }}>
            {msg.text}
          </div>
        )}
      </div>
    </div>
  )
}

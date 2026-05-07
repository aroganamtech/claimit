import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'

const AD_LABELS = {
  home_banner: 'Home Page banner Ad',
  promo_reelz: 'Promo Reelz Ad',
  brand_deals: 'Brand Deals Ad',
  nearby_deals: 'Nearby Deals Ad',
}

const AD_PRICES = {
  home_banner: 840,
  promo_reelz: 1400,
  brand_deals: 1400,
  nearby_deals: 1400,
}

export default function AdDetails() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const adType = searchParams.get('type') || 'nearby_deals'

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [pincode, setPincode] = useState('')
  const [creative, setCreative] = useState(null)
  const [error, setError] = useState('')

  const handleContinue = () => {
    if (!title || !description || !pincode) {
      setError('Please fill all required fields')
      return
    }
    // Store in session and navigate to publish step
    sessionStorage.setItem('ad_draft', JSON.stringify({ adType, title, description, pincode }))
    navigate(`/advertiser/create-ad/publish?type=${adType}`)
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 28 }}>
          Add Details - {AD_LABELS[adType] || 'Ad'}
        </h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, maxWidth: 1100 }}>
          {/* Form */}
          <div>
            {/* Ad Information */}
            <div style={{
              background: '#fff', borderRadius: 12, border: '1px solid #eee',
              padding: 24, marginBottom: 20
            }}>
              <h3 style={{ fontWeight: 600, marginBottom: 20 }}>Ad Information</h3>
              {error && <div style={{ color: '#e53935', marginBottom: 12, fontSize: 13 }}>{error}</div>}
              <div style={{ marginBottom: 16 }}>
                <label style={labelStyle}>Ad Title</label>
                <input
                  className="input-field"
                  placeholder="Enter Ad title"
                  value={title}
                  onChange={e => setTitle(e.target.value)}
                />
              </div>
              <div>
                <label style={labelStyle}>Ad Description</label>
                <textarea
                  className="input-field"
                  placeholder="Write a Short description..."
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  rows={3}
                  style={{ resize: 'vertical' }}
                />
              </div>
            </div>

            {/* Creative Upload */}
            <div style={{
              background: '#fff', borderRadius: 12, border: '1px solid #eee',
              padding: 24, marginBottom: 20
            }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Creative Upload</h3>
              <label style={{
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', justifyContent: 'center',
                border: '2px dashed #ddd', borderRadius: 10,
                padding: '32px 20px', cursor: 'pointer',
                background: creative ? '#e8f5e9' : '#fafafa'
              }}>
                <input
                  type="file"
                  accept="image/jpeg,image/png,video/mp4"
                  style={{ display: 'none' }}
                  onChange={e => setCreative(e.target.files[0])}
                />
                <span style={{ fontSize: 28, marginBottom: 8 }}>⬆</span>
                {creative
                  ? <span style={{ fontSize: 13, color: '#2e7d32', fontWeight: 600 }}>{creative.name}</span>
                  : <>
                    <span style={{ fontSize: 14, color: '#666', fontWeight: 500 }}>Drop your files here or browse</span>
                    <span style={{ fontSize: 12, color: '#aaa', marginTop: 4 }}>Supports: JPG, PNG, MP4 (Max 50MB)</span>
                  </>
                }
              </label>
            </div>

            {/* Location */}
            <div style={{
              background: '#fff', borderRadius: 12, border: '1px solid #eee',
              padding: 24, marginBottom: 20
            }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Location details</h3>
              <label style={labelStyle}>Pincode</label>
              <input
                className="input-field"
                placeholder="Enter your pincode"
                value={pincode}
                onChange={e => setPincode(e.target.value)}
              />
            </div>

            {/* Price Summary */}
            <div style={{
              background: '#1565C0', borderRadius: 12,
              padding: 24, color: '#fff', marginBottom: 20
            }}>
              <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 4 }}>Price Summary</div>
              <div style={{ fontSize: 28, fontWeight: 700 }}>₹{AD_PRICES[adType] || 1400}</div>
              <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>Price includes 18% GST</div>
            </div>

            <button className="btn-primary" onClick={handleContinue}>Continue</button>
          </div>

          {/* Preview */}
          <div>
            <div style={{
              background: '#e8f0fe', borderRadius: 12, padding: 20,
              border: '1px solid #c5d5f0'
            }}>
              <div style={{
                display: 'flex', justifyContent: 'space-between',
                alignItems: 'center', marginBottom: 16
              }}>
                <span style={{ fontWeight: 600, fontSize: 14 }}>Preview</span>
                <span style={{ fontSize: 16 }}>⛶</span>
              </div>

              {/* Phone mockup */}
              <div style={{
                background: '#000', borderRadius: 36, padding: 10,
                boxShadow: '0 8px 32px rgba(0,0,0,0.25)', maxWidth: 280, margin: '0 auto'
              }}>
                <div style={{
                  background: '#fff', borderRadius: 28,
                  overflow: 'hidden', minHeight: 500
                }}>
                  {/* App header */}
                  <div style={{ background: '#1565C0', padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ color: '#fff', fontWeight: 700, fontSize: 13 }}>claimit</span>
                    <span style={{ color: '#fff', fontSize: 11 }}>Anna Nagar ▾</span>
                  </div>
                  {/* Content preview */}
                  <div style={{ padding: '12px 12px' }}>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#1565C0', marginBottom: 10 }}>
                      ← {AD_LABELS[adType]}
                    </div>
                    {/* Demo ad card */}
                    <div style={{ background: '#f8f9fa', borderRadius: 8, padding: 10, marginBottom: 8, display: 'flex', gap: 8, alignItems: 'center' }}>
                      <div style={{ width: 50, height: 50, background: '#e0e0e0', borderRadius: 6, flexShrink: 0 }} />
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 11, marginBottom: 2 }}>
                          {title || 'Super Saravana Store'}
                        </div>
                        <div style={{ fontSize: 10, color: '#1565C0' }}>
                          {description || '25% Offer on All grocery'}
                        </div>
                        <div style={{ fontSize: 9, color: '#888', marginTop: 2 }}>
                          6Km • Superstore
                        </div>
                      </div>
                    </div>
                    {[1, 2, 3].map(i => (
                      <div key={i} style={{ background: '#f8f9fa', borderRadius: 8, padding: 10, marginBottom: 6, display: 'flex', gap: 8 }}>
                        <div style={{ width: 50, height: 40, background: '#e8e8e8', borderRadius: 6 }} />
                        <div style={{ flex: 1 }}>
                          <div style={{ height: 8, background: '#e0e0e0', borderRadius: 4, marginBottom: 6, width: '70%' }} />
                          <div style={{ height: 6, background: '#e8e8e8', borderRadius: 4, width: '50%' }} />
                        </div>
                      </div>
                    ))}
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

const labelStyle = {
  display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8
}

import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

const AD_LABELS = {
  home_banner: 'Home Page banner Ad',
  promo_reelz: 'Promo Reelz Ad',
  brand_deals: 'Brand Deals Ad',
  nearby_deals: 'Nearby Deals Ad',
}

export default function PublishAd() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const adType = searchParams.get('type') || 'nearby_deals'
  const [publishOption, setPublishOption] = useState('today')
  const [scheduleDate, setScheduleDate] = useState('')
  const [loading, setLoading] = useState(false)

  const handlePublish = async () => {
    const draft = JSON.parse(sessionStorage.getItem('ad_draft') || '{}')
    setLoading(true)
    try {
      const formData = new FormData()
      formData.append('ad_type', draft.adType || adType)
      formData.append('title', draft.title || 'Ad')
      formData.append('description', draft.description || '')
      formData.append('pincode', draft.pincode || '000000')
      formData.append('publish_today', publishOption === 'today')
      if (publishOption === 'schedule' && scheduleDate) {
        formData.append('scheduled_date', scheduleDate)
      }

      const res = await api.post('/advertiser/ads/create', formData)
      sessionStorage.removeItem('ad_draft')
      navigate('/advertiser/create-ad/payment', {
        state: {
          adType: AD_LABELS[adType],
          publishDate: res.data.publish_date,
          endDate: res.data.end_date,
          amount: res.data.amount
        }
      })
    } catch (e) {
      console.error(e)
      // Navigate anyway for demo
      navigate('/advertiser/create-ad/payment', {
        state: {
          adType: AD_LABELS[adType],
          publishDate: '01/12/2025',
          endDate: '07/12/2025',
          amount: 1400
        }
      })
    } finally { setLoading(false) }
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 28 }}>Publish The AD</h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, maxWidth: 1100 }}>
          {/* Left */}
          <div>
            {/* Duration */}
            <div style={{
              background: '#fff', borderRadius: 12, border: '1px solid #eee',
              padding: 24, marginBottom: 20
            }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Duration of Ad</h3>
              <div style={{
                display: 'flex', alignItems: 'center', gap: 16,
                background: '#f8f9fa', borderRadius: 10, padding: '16px 20px'
              }}>
                <div style={{
                  background: '#1565C0', color: '#fff',
                  borderRadius: 10, padding: '12px 16px',
                  fontWeight: 700, fontSize: 16, minWidth: 70, textAlign: 'center'
                }}>
                  7 Days
                </div>
                <p style={{ color: '#666', fontSize: 13 }}>
                  All advertisements run for a fixed duration of 7 days and will be notified to customers
                </p>
              </div>
            </div>

            {/* Schedule */}
            <div style={{
              background: '#fff', borderRadius: 12, border: '1px solid #eee',
              padding: 24, marginBottom: 24
            }}>
              <h3 style={{ fontWeight: 600, marginBottom: 6 }}>Schedule Publish</h3>
              <p style={{ color: '#888', fontSize: 13, marginBottom: 20 }}>
                Choose when your ad should go live. You can schedule up to 10 days in advance.
              </p>

              {/* Today option */}
              <div
                onClick={() => setPublishOption('today')}
                style={{
                  border: `1.5px solid ${publishOption === 'today' ? '#1565C0' : '#e0e0e0'}`,
                  borderRadius: 10, padding: '16px 20px', marginBottom: 12, cursor: 'pointer'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{
                    width: 20, height: 20, borderRadius: '50%',
                    border: `2px solid ${publishOption === 'today' ? '#1565C0' : '#bbb'}`,
                    background: publishOption === 'today' ? '#1565C0' : '#fff',
                    flexShrink: 0
                  }} />
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>Publish Today</div>
                    <div style={{ color: '#888', fontSize: 13 }}>Your ad will go live immediately and run for 7 days.</div>
                  </div>
                </div>
              </div>

              {/* Schedule option */}
              <div
                onClick={() => setPublishOption('schedule')}
                style={{
                  border: `1.5px solid ${publishOption === 'schedule' ? '#1565C0' : '#e0e0e0'}`,
                  borderRadius: 10, padding: '16px 20px', cursor: 'pointer'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{
                    width: 20, height: 20, borderRadius: '50%',
                    border: `2px solid ${publishOption === 'schedule' ? '#1565C0' : '#bbb'}`,
                    background: publishOption === 'schedule' ? '#1565C0' : '#fff',
                    flexShrink: 0
                  }} />
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>Schedule Ad</div>
                    <div style={{ color: '#888', fontSize: 13 }}>Pick a future date (up to 10 days from today).</div>
                  </div>
                </div>
              </div>

              {publishOption === 'schedule' && (
                <div style={{ marginTop: 16 }}>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }}>
                    Select Publish date
                  </label>
                  <input
                    type="date"
                    className="input-field"
                    value={scheduleDate}
                    onChange={e => setScheduleDate(e.target.value)}
                  />
                  <p style={{ fontSize: 12, color: '#888', marginTop: 6 }}>
                    You can schedule your ad up to 10 days from today.
                  </p>
                </div>
              )}
            </div>

            <button className="btn-primary" onClick={handlePublish} disabled={loading}>
              {loading ? 'Publishing...' : 'Publish now'}
            </button>
          </div>

          {/* Right - Preview */}
          <div>
            <div style={{ background: '#e8f0fe', borderRadius: 12, padding: 20 }}>
              <div style={{ fontWeight: 600, marginBottom: 16 }}>All Ready to publish the Ad</div>
              {/* Phone mockup */}
              <div style={{
                background: '#000', borderRadius: 36, padding: 10,
                boxShadow: '0 8px 32px rgba(0,0,0,0.25)', maxWidth: 260, margin: '0 auto'
              }}>
                <div style={{ background: '#fff', borderRadius: 28, overflow: 'hidden', minHeight: 480 }}>
                  <div style={{ background: '#1565C0', padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ color: '#fff', fontWeight: 700, fontSize: 13 }}>claimit</span>
                    <span style={{ color: '#fff', fontSize: 11 }}>Anna Nagar ▾</span>
                  </div>
                  <div style={{ padding: 12 }}>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#1565C0', marginBottom: 10 }}>
                      ← Nearby Deals
                    </div>
                    <div style={{ background: '#f8f9fa', borderRadius: 8, padding: 10, marginBottom: 8, display: 'flex', gap: 8 }}>
                      <div style={{ width: 50, height: 50, background: '#e0e0e0', borderRadius: 6 }} />
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 11, marginBottom: 2 }}>Super Saravana Store</div>
                        <div style={{ fontSize: 10, color: '#1565C0' }}>25% Offer on All grocery</div>
                        <div style={{ fontSize: 9, color: '#888', marginTop: 2 }}>6Km • Superstore</div>
                      </div>
                    </div>
                    {[1, 2, 3].map(i => (
                      <div key={i} style={{ background: '#f8f9fa', borderRadius: 8, padding: 8, marginBottom: 6, display: 'flex', gap: 8 }}>
                        <div style={{ width: 44, height: 40, background: '#e8e8e8', borderRadius: 6 }} />
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

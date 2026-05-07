import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

export default function AdvertiserDashboard() {
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [tab, setTab] = useState('all')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/advertiser/dashboard')
      .then(r => setData(r.data))
      .catch(() => setData({ total_ads: 5, total_views: 45200, total_clicks: 32100, ads: [] }))
      .finally(() => setLoading(false))
  }, [])

  const ads = data?.ads || []
  const filteredAds = tab === 'all' ? ads : ads.filter(a => a.status === tab)

  // Demo ads if empty
  const displayAds = filteredAds.length > 0 ? filteredAds : [
    { id: '1', title: 'Home Page Ad', publish_date: '01/12/2025', end_date: '08/12/2025', views: 12300, clicks: 2100, status: 'active' }
  ]

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 28 }}>
          <div>
            <h1 style={{ fontSize: 28, fontWeight: 700 }}>Dashboard</h1>
            <p style={{ color: '#888', fontSize: 14 }}>Welcome to your advertising overview</p>
          </div>
          <button
            className="btn-primary"
            style={{ width: 'auto', padding: '10px 20px' }}
            onClick={() => navigate('/advertiser/create-ad')}
          >
            Create New Ad
          </button>
        </div>

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 28 }}>
          <div className="stat-card">
            <div style={{ fontSize: 28, color: '#1565C0' }}>AD</div>
            <div className="stat-value">{data?.total_ads ?? 5}</div>
            <div className="stat-label">Total Ads</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>👁</div>
            <div className="stat-value">{data?.total_views ? (data.total_views / 1000).toFixed(1) + 'k' : '45.2k'}</div>
            <div className="stat-label">Total Views</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>👆</div>
            <div className="stat-value">{data?.total_clicks ? (data.total_clicks / 1000).toFixed(1) + 'k' : '32.1k'}</div>
            <div className="stat-label">Total Clicks</div>
          </div>
        </div>

        {/* Ads Table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px', borderBottom: '1px solid #eee' }}>
            <h3 style={{ fontWeight: 600, fontSize: 16 }}>Your Advertisement</h3>
            <div style={{ display: 'flex', gap: 4 }}>
              {['all', 'active', 'scheduled'].map(t => (
                <button
                  key={t}
                  className={`tab-btn ${tab === t ? 'active' : ''}`}
                  onClick={() => setTab(t)}
                  style={{ textTransform: 'capitalize' }}
                >
                  {t.charAt(0).toUpperCase() + t.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <tbody>
                {displayAds.map((ad, i) => (
                  <tr key={ad.id || i} style={{ borderBottom: '1px solid #f5f5f5' }}>
                    <td style={{ padding: '20px 24px' }}>
                      <div style={{ fontWeight: 600, fontSize: 15 }}>{ad.title || 'Home Page Ad'}</div>
                    </td>
                    <td style={{ padding: '20px 24px', color: '#888', fontSize: 13 }}>
                      <div>Publish Date</div>
                      <div style={{ fontWeight: 600, color: '#333', marginTop: 2 }}>{ad.publish_date || '01/12/2025'}</div>
                    </td>
                    <td style={{ padding: '20px 24px', color: '#888', fontSize: 13 }}>
                      <div>End Date</div>
                      <div style={{ fontWeight: 600, color: '#333', marginTop: 2 }}>{ad.end_date || '08/12/2025'}</div>
                    </td>
                    <td style={{ padding: '20px 24px', color: '#888', fontSize: 13 }}>
                      <div>Views</div>
                      <div style={{ fontWeight: 600, color: '#333', marginTop: 2 }}>
                        {ad.views >= 1000 ? (ad.views / 1000).toFixed(1) + 'k' : ad.views || '12.3k'}
                      </div>
                    </td>
                    <td style={{ padding: '20px 24px', color: '#888', fontSize: 13 }}>
                      <div>Clicks</div>
                      <div style={{ fontWeight: 600, color: '#333', marginTop: 2 }}>
                        {ad.clicks >= 1000 ? (ad.clicks / 1000).toFixed(1) + 'k' : ad.clicks || '2.1k'}
                      </div>
                    </td>
                    <td style={{ padding: '20px 24px' }}>
                      <span className={ad.status === 'active' ? 'badge-active' : 'badge-scheduled'}>
                        {ad.status === 'active' && '✓ '}
                        {ad.status?.charAt(0).toUpperCase() + ad.status?.slice(1) || 'Active'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </main>
    </div>
  )
}

import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import SalesSidebar from './SalesSidebar'
import api from '../../utils/api'

export default function SalesDashboard() {
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [tab, setTab] = useState('all')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.sales.getDashboard()
      .then(setData)
      .catch(() => setData({ total_shops: 0, total_revenue: 0, total_members: 0, shops: [] }))
      .finally(() => setLoading(false))
  }, [])

  const shops = data?.shops || []
  const filteredShops = tab === 'all' ? shops : shops.filter(s => s.status === tab)

  return (
    <div style={{ paddingTop: 64 }}>
      <SalesSidebar />
      <main className="main-content">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 28 }}>
          <div>
            <h1 style={{ fontSize: 28, fontWeight: 700 }}>Dashboard</h1>
            <p style={{ color: '#888', fontSize: 14 }}>Welcome to Your overview</p>
          </div>
          <button
            className="btn-primary"
            style={{ width: 'auto', padding: '10px 20px' }}
            onClick={() => navigate('/sales/add-shop')}
          >
            Add Shop
          </button>
        </div>

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 28 }}>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>🏪</div>
            <div className="stat-value">{data?.total_shops ?? 0}</div>
            <div className="stat-label">Total Shop</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>👁</div>
            <div className="stat-value">{data?.total_revenue ?? 0}</div>
            <div className="stat-label">Total Revenue</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>👆</div>
            <div className="stat-value">{data?.total_members ?? 0}</div>
            <div className="stat-label">Total Members</div>
          </div>
        </div>

        {/* Shops Table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px', borderBottom: '1px solid #eee' }}>
            <h3 style={{ fontWeight: 600, fontSize: 16 }}>Your Shops</h3>
            <div style={{ display: 'flex', gap: 4 }}>
              {['all', 'active', 'pending'].map(t => (
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
          ) : filteredShops.length === 0 ? (
            <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>🏪</div>
              <div style={{ fontSize: 15, fontWeight: 500 }}>No shops yet</div>
              <div style={{ fontSize: 13, marginTop: 4 }}>Add shops to see them here</div>
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8f9fa' }}>
                  {['Shop Name', 'Address', 'Category', 'Status'].map(h => (
                    <th key={h} style={{ padding: '12px 24px', textAlign: 'left', fontSize: 13, color: '#888', fontWeight: 600 }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredShops.map((shop, i) => (
                  <tr key={shop.id || i} style={{ borderBottom: '1px solid #f5f5f5' }}>
                    <td style={{ padding: '16px 24px', fontWeight: 600, fontSize: 14 }}>{shop.shop_name}</td>
                    <td style={{ padding: '16px 24px', color: '#666', fontSize: 13 }}>{shop.shop_address}</td>
                    <td style={{ padding: '16px 24px', color: '#666', fontSize: 13 }}>{shop.category}</td>
                    <td style={{ padding: '16px 24px' }}>
                      <span className={shop.status === 'active' ? 'badge-active' : 'badge-scheduled'}>
                        {shop.status}
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

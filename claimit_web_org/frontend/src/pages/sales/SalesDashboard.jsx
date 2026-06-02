import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import SalesSidebar from './SalesSidebar'
import api from '../../utils/api'

const SUB_ROLE_LABEL = {
  sales_head:             'Sales Head',
  sales_executive:        'Sales Executive',
  advertising_executive:  'Advertising Executive',
  freelancer:             'Freelancer',
}

export default function SalesDashboard() {
  const navigate  = useNavigate()
  const [data, setData]     = useState(null)
  const [tab, setTab]       = useState('all')
  const [loading, setLoading] = useState(true)
  const [newId, setNewId]   = useState('')

  useEffect(() => {
    api.sales.getDashboard()
      .then(setData)
      .catch(() => setData({ total_shops: 0, total_revenue: 0, total_members: 0, shops: [], unique_id: '', sub_role: '' }))
      .finally(() => setLoading(false))

    // Show welcome banner if just registered
    const id = sessionStorage.getItem('new_unique_id')
    if (id) { setNewId(id); sessionStorage.removeItem('new_unique_id') }
  }, [])

  const shops = data?.shops || []
  const filtered = tab === 'all' ? shops : shops.filter(s => s.status === tab)
  const uniqueId = data?.unique_id || ''
  const subRole  = data?.sub_role  || ''

  return (
    <div style={{ paddingTop: 64 }}>
      <SalesSidebar />
      <main className="main-content">

        {/* Welcome banner for new registrations */}
        {newId && (
          <div style={{
            background: 'linear-gradient(135deg, #1565C0, #0D47A1)',
            borderRadius: 14, padding: '24px 28px', color: '#fff', marginBottom: 24,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between'
          }}>
            <div>
              <div style={{ fontSize: 13, opacity: 0.8, marginBottom: 6 }}>🎉 Welcome! Your unique employee ID has been generated</div>
              <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: 2 }}>{newId}</div>
              <div style={{ fontSize: 12, opacity: 0.75, marginTop: 6 }}>
                Use this ID every time you onboard a shop or close an advertising sale
              </div>
            </div>
            <button onClick={() => setNewId('')} style={{ background: 'rgba(255,255,255,0.2)', border: 'none', color: '#fff', borderRadius: 8, padding: '8px 16px', cursor: 'pointer', fontFamily: 'Poppins' }}>
              Got it ✓
            </button>
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 24 }}>
          <div>
            <h1 style={{ fontSize: 26, fontWeight: 700 }}>Dashboard</h1>
            {subRole && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                <span style={{ background: '#EEF4FF', color: '#1565C0', fontSize: 12, fontWeight: 600, padding: '3px 10px', borderRadius: 20 }}>
                  {SUB_ROLE_LABEL[subRole] || subRole}
                </span>
                {uniqueId && (
                  <span style={{ background: '#f5f5f5', color: '#555', fontSize: 12, fontWeight: 600, padding: '3px 10px', borderRadius: 20, fontFamily: 'monospace' }}>
                    ID: {uniqueId}
                  </span>
                )}
              </div>
            )}
          </div>
          <button
            className="btn-primary"
            style={{ width: 'auto', padding: '10px 20px' }}
            onClick={() => navigate('/sales/add-shop')}
          >+ Add Shop</button>
        </div>

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
          {[
            { icon: '🏪', value: data?.total_shops ?? 0,   label: 'Shops Onboarded' },
            { icon: '💰', value: `₹${data?.total_revenue ?? 0}`, label: 'Total Revenue' },
            { icon: '👥', value: data?.total_members ?? 0, label: subRole === 'sales_head' ? 'Team Members' : 'Team Members' },
          ].map(s => (
            <div key={s.label} className="stat-card">
              <div style={{ fontSize: 24 }}>{s.icon}</div>
              <div className="stat-value">{s.value}</div>
              <div className="stat-label">{s.label}</div>
            </div>
          ))}
        </div>

        {/* Shops table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px', borderBottom: '1px solid #eee' }}>
            <h3 style={{ fontWeight: 600, fontSize: 16 }}>Your Onboarded Shops</h3>
            <div style={{ display: 'flex', gap: 4 }}>
              {['all', 'active', 'pending'].map(t => (
                <button key={t} className={`tab-btn ${tab === t ? 'active' : ''}`}
                  onClick={() => setTab(t)} style={{ textTransform: 'capitalize' }}>
                  {t.charAt(0).toUpperCase() + t.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
          ) : filtered.length === 0 ? (
            <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>🏪</div>
              <div style={{ fontSize: 15, fontWeight: 500 }}>No shops yet</div>
              <div style={{ fontSize: 13, marginTop: 4 }}>Add shops to see them here</div>
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8f9fa' }}>
                  {['Shop Name', 'Address', 'Category', 'Status', 'Credited To'].map(h => (
                    <th key={h} style={{ padding: '12px 20px', textAlign: 'left', fontSize: 13, color: '#888', fontWeight: 600 }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.map((shop, i) => (
                  <tr key={shop.id || i} style={{ borderBottom: '1px solid #f5f5f5' }}>
                    <td style={{ padding: '14px 20px', fontWeight: 600, fontSize: 14 }}>{shop.shop_name}</td>
                    <td style={{ padding: '14px 20px', color: '#666', fontSize: 13 }}>{shop.shop_address}</td>
                    <td style={{ padding: '14px 20px', color: '#666', fontSize: 13 }}>{shop.category}</td>
                    <td style={{ padding: '14px 20px' }}>
                      <span className={shop.status === 'active' ? 'badge-active' : 'badge-scheduled'}>
                        {shop.status}
                      </span>
                    </td>
                    <td style={{ padding: '14px 20px' }}>
                      {shop.sales_unique_id ? (
                        <span style={{ background: '#EEF4FF', color: '#1565C0', fontSize: 11, fontWeight: 600, padding: '3px 8px', borderRadius: 6, fontFamily: 'monospace' }}>
                          {shop.sales_unique_id}
                        </span>
                      ) : <span style={{ color: '#ccc', fontSize: 12 }}>—</span>}
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

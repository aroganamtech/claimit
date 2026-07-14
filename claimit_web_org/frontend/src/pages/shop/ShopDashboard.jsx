import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import ShopSidebar from './ShopSidebar'
import api from '../../utils/api'

export default function ShopDashboard() {
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [tab, setTab] = useState('rewards')
  const [loading, setLoading] = useState(true)

  const [scans, setScans] = useState({ total_scans: 0, scans: [] })

  useEffect(() => {
    api.shop.getDashboard()
      .then(d => {
        setData(d)
        // Default tab based on shop type: redeem shops start on redeems tab
        if ((d?.shop?.shop_type || '').toLowerCase() === 'redeem') {
          setTab('redeems')
        }
      })
      .catch(() => setData({ total_reward_given: 0, total_redeem_used: 0, rewards: [], redeems: [] }))
      .finally(() => setLoading(false))
    // Bill scans recorded by the Claimit app at this shop (read-only)
    api.shop.getBillScans()
      .then(setScans)
      .catch(() => setScans({ total_scans: 0, scans: [] }))
  }, [])

  const shopType = (data?.shop?.shop_type || '').toLowerCase()
  const isReward = shopType === 'reward'
  const isRedeem = shopType === 'redeem'

  const tableData =
    tab === 'rewards' ? (data?.rewards || [])
    : tab === 'redeems' ? (data?.redeems || [])
    : (scans.scans || [])

  return (
    <div style={{ paddingTop: 64 }}>
      <ShopSidebar />
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

        {/* Stats — reward shops hide redeem stat; redeem shops hide reward stat */}
        <div style={{ display: 'grid', gridTemplateColumns: `repeat(${isReward || isRedeem ? 3 : 4}, 1fr)`, gap: 16, maxWidth: 1100, marginBottom: 28 }}>
          {!isRedeem && (
            <div className="stat-card">
              <div style={{ fontSize: 24 }}>🎯</div>
              <div className="stat-value">{data?.total_reward_given ?? 0}</div>
              <div className="stat-label">Total Reward Given</div>
            </div>
          )}
          {!isReward && (
            <div className="stat-card">
              <div style={{ fontSize: 24 }}>🏪</div>
              <div className="stat-value">{data?.total_redeem_used ?? 0}</div>
              <div className="stat-label">Total Redeem Used</div>
            </div>
          )}
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>❤️</div>
            <div className="stat-value">
              {(data?.total_favorites ?? 0) >= 1000
                ? ((data.total_favorites) / 1000).toFixed(1) + 'k'
                : (data?.total_favorites ?? 0)}
            </div>
            <div className="stat-label">Total Favorites</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>🧾</div>
            <div className="stat-value">{scans.total_scans ?? 0}</div>
            <div className="stat-label">Bills Scanned</div>
          </div>
        </div>

        {/* Transactions Table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ padding: '16px 24px', borderBottom: '1px solid #eee', display: 'flex', gap: 4 }}>
            {!isRedeem && (
              <button
                className={`tab-btn ${tab === 'rewards' ? 'active' : ''}`}
                onClick={() => setTab('rewards')}
              >Rewards</button>
            )}
            {!isReward && (
              <button
                className={`tab-btn ${tab === 'redeems' ? 'active' : ''}`}
                onClick={() => setTab('redeems')}
              >Redeem</button>
            )}
            <button
              className={`tab-btn ${tab === 'scans' ? 'active' : ''}`}
              onClick={() => setTab('scans')}
            >Bill Scans</button>
          </div>

          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
          ) : tableData.length === 0 ? (
            <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>
                {tab === 'rewards' ? '🎯' : tab === 'redeems' ? '🏪' : '🧾'}
              </div>
              <div style={{ fontSize: 15, fontWeight: 500 }}>
                No {tab === 'scans' ? 'bill scans' : tab} yet
              </div>
              <div style={{ fontSize: 13, marginTop: 4 }}>
                {tab === 'rewards'
                  ? 'Customer rewards will appear here once they shop'
                  : tab === 'redeems'
                  ? 'Customer redemptions will appear here once they redeem points'
                  : 'Bills scanned at your shop through the Claimit app will appear here'}
              </div>
            </div>
          ) : tab === 'scans' ? (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8f9fa' }}>
                  <th style={thStyle}>Bill No</th>
                  <th style={thStyle}>Bill Date</th>
                  <th style={thStyle}>Time</th>
                  <th style={thStyle}>Type</th>
                  <th style={thStyle}>Amount (₹)</th>
                  <th style={thStyle}>Cashback (₹)</th>
                  <th style={thStyle}>Points</th>
                </tr>
              </thead>
              <tbody>
                {tableData.map((row, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #f5f5f5', textAlign: 'center' }}>
                    <td style={tdStyle}>{row.bill_number || '—'}</td>
                    <td style={tdStyle}>{row.bill_date || (row.scanned_at || '').slice(0, 10)}</td>
                    <td style={tdStyle}>{row.bill_time || '—'}</td>
                    <td style={tdStyle}>
                      <span style={{
                        padding: '2px 10px', borderRadius: 12, fontSize: 12, fontWeight: 600,
                        background: row.scan_type === 'redeem' ? '#FFF3E0' : '#E8F5E9',
                        color: row.scan_type === 'redeem' ? '#E65100' : '#2E7D32',
                      }}>
                        {row.scan_type === 'redeem' ? 'Redeem' : 'Reward'}
                      </span>
                    </td>
                    <td style={tdStyle}>{row.total_amount}</td>
                    <td style={tdStyle}>{row.earned_cashback}</td>
                    <td style={tdStyle}>{row.earned_points}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8f9fa' }}>
                  <th style={thStyle}>Customer</th>
                  <th style={thStyle}>
                    {tab === 'rewards' ? '🎯 Reward Points' : '🏪 Redeemed'}
                  </th>
                  <th style={thStyle}>Bill Amount</th>
                  <th style={thStyle}>Date</th>
                </tr>
              </thead>
              <tbody>
                {tableData.map((row, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #f5f5f5', textAlign: 'center' }}>
                    <td style={tdStyle}>{row.customer}</td>
                    <td style={tdStyle}>{tab === 'rewards' ? row.reward_points : row.redeemed}</td>
                    <td style={tdStyle}>{row.bill_amount}</td>
                    <td style={tdStyle}>{row.date}</td>
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

const thStyle = { padding: '12px 24px', textAlign: 'center', fontSize: 13, color: '#888', fontWeight: 600 }
const tdStyle = { padding: '16px 24px', fontSize: 14 }

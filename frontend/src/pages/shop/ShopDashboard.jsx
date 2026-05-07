import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import ShopSidebar from './ShopSidebar'
import api from '../../utils/api'

export default function ShopDashboard() {
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [tab, setTab] = useState('rewards')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/shop/dashboard')
      .then(r => setData(r.data))
      .catch(() => setData({
        total_reward_given: 42, total_redeem_used: 35,
        rewards: [
          { customer: 'Arun', reward_points: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Aruna', reward_points: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Sabari', reward_points: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Sam', reward_points: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'dhanush', reward_points: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Arvind', reward_points: 500, bill_amount: 580, date: '18/12/2025' },
        ],
        redeems: [
          { customer: 'Arun', redeemed: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Aruna', redeemed: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Sabari', redeemed: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Sam', redeemed: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'dhanush', redeemed: 500, bill_amount: 580, date: '18/12/2025' },
          { customer: 'Arvind', redeemed: 500, bill_amount: 580, date: '18/12/2025' },
        ]
      }))
      .finally(() => setLoading(false))
  }, [])

  const tableData = tab === 'rewards' ? (data?.rewards || []) : (data?.redeems || [])

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

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, maxWidth: 600, marginBottom: 28 }}>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>🎯</div>
            <div className="stat-value">{data?.total_reward_given ?? 42}</div>
            <div className="stat-label">Total Reward Given</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>🏪</div>
            <div className="stat-value">{data?.total_redeem_used ?? 35}</div>
            <div className="stat-label">Total Redeem Used</div>
          </div>
        </div>

        {/* Transactions Table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ padding: '16px 24px', borderBottom: '1px solid #eee', display: 'flex', gap: 4 }}>
            <button
              className={`tab-btn ${tab === 'rewards' ? 'active' : ''}`}
              onClick={() => setTab('rewards')}
            >Rewards</button>
            <button
              className={`tab-btn ${tab === 'redeems' ? 'active' : ''}`}
              onClick={() => setTab('redeems')}
            >Redeem</button>
          </div>

          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
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

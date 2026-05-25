import { useState, useEffect } from 'react'
import SalesSidebar from './SalesSidebar'
import api from '../../utils/api'

export function YourTeam() {
  const [members, setMembers] = useState([])

  useEffect(() => {
    api.sales.getTeam().then(setMembers).catch(() => setMembers([]))
  }, [])

  return (
    <div style={{ paddingTop: 64 }}>
      <SalesSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Your Team</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>Members you've referred to Claimit</p>

        {members.length === 0 ? (
          <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 60, textAlign: 'center', color: '#bbb' }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>👥</div>
            <div style={{ fontSize: 15, fontWeight: 500 }}>No team members yet</div>
            <div style={{ fontSize: 13, marginTop: 4 }}>Invite people to join Claimit under your referral</div>
          </div>
        ) : (
          <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8f9fa' }}>
                  {['Name', 'Email', 'Phone', 'Joined'].map(h => (
                    <th key={h} style={{ padding: '12px 24px', textAlign: 'left', fontSize: 13, color: '#888', fontWeight: 600 }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {members.map((m, i) => (
                  <tr key={m.id || i} style={{ borderBottom: '1px solid #f5f5f5' }}>
                    <td style={{ padding: '16px 24px', fontWeight: 600 }}>{m.name}</td>
                    <td style={{ padding: '16px 24px', color: '#666', fontSize: 13 }}>{m.email}</td>
                    <td style={{ padding: '16px 24px', color: '#666', fontSize: 13 }}>{m.phone}</td>
                    <td style={{ padding: '16px 24px', color: '#666', fontSize: 13 }}>{m.created_at?.slice(0, 10)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  )
}

export function Earning() {
  const [data, setData] = useState(null)

  useEffect(() => {
    api.sales.getEarnings()
      .then(setData)
      .catch(() => setData({ total_earned: 0, pending: 0, paid: 0 }))
  }, [])

  return (
    <div style={{ paddingTop: 64 }}>
      <SalesSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 28 }}>Earning</h1>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 28 }}>
          {[
            { label: 'Total Earned', value: `₹${data?.total_earned || 0}` },
            { label: 'Pending', value: `₹${data?.pending || 0}` },
            { label: 'Paid', value: `₹${data?.paid || 0}` },
          ].map(stat => (
            <div key={stat.label} className="stat-card">
              <div className="stat-value">{stat.value}</div>
              <div className="stat-label">{stat.label}</div>
            </div>
          ))}
        </div>

        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 40, textAlign: 'center', color: '#bbb' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>💰</div>
          <div style={{ fontSize: 15, fontWeight: 500 }}>No transactions yet</div>
          <div style={{ fontSize: 13, marginTop: 4 }}>Add shops to start earning commissions</div>
        </div>
      </main>
    </div>
  )
}

export function SalesSettings() {
  return (
    <div style={{ paddingTop: 64 }}>
      <SalesSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 28 }}>Settings</h1>
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 28, maxWidth: 500 }}>
          <p style={{ color: '#888', fontSize: 14 }}>Account settings and preferences</p>
        </div>
      </main>
    </div>
  )
}

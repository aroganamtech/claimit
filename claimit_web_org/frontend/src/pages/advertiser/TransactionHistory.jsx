import { useEffect, useState } from 'react'
import AdvertiserSidebar from './AdvertiserSidebar'
import api from '../../utils/api'

export default function TransactionHistory() {
  const [txns, setTxns] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.advertiser.getTransactions()
      .then(d => setTxns(d || []))
      .catch(() => setTxns([]))
      .finally(() => setLoading(false))
  }, [])

  const total = txns.reduce((s, t) => s + (t.amount || 0), 0)

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Transaction History</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>
          A record of every ad purchase on your account.
        </p>

        {/* Summary */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16, maxWidth: 600, marginBottom: 28 }}>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>🧾</div>
            <div className="stat-value">{txns.length}</div>
            <div className="stat-label">Total Transactions</div>
          </div>
          <div className="stat-card">
            <div style={{ fontSize: 24 }}>💰</div>
            <div className="stat-value">₹{total}</div>
            <div className="stat-label">Total Spent</div>
          </div>
        </div>

        {/* Table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', overflow: 'hidden' }}>
          <div style={{ padding: '16px 24px', borderBottom: '1px solid #eee', fontWeight: 600 }}>
            All Transactions
          </div>
          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading...</div>
          ) : txns.length === 0 ? (
            <div style={{ padding: 60, textAlign: 'center', color: '#bbb' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>🧾</div>
              <div style={{ fontSize: 15, fontWeight: 500 }}>No transactions yet</div>
              <div style={{ fontSize: 13, marginTop: 4 }}>Your ad purchases will appear here</div>
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8f9fa' }}>
                  <th style={th}>Date</th>
                  <th style={th}>Title</th>
                  <th style={th}>Type</th>
                  <th style={{ ...th, textAlign: 'right' }}>Amount</th>
                </tr>
              </thead>
              <tbody>
                {txns.map(t => (
                  <tr key={t.id} style={{ borderBottom: '1px solid #f5f5f5' }}>
                    <td style={td}>{t.date}</td>
                    <td style={td}>{t.title}</td>
                    <td style={td}>Ad Purchase</td>
                    <td style={{ ...td, textAlign: 'right', fontWeight: 600 }}>₹{t.amount}</td>
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

const th = { padding: '12px 24px', textAlign: 'left', fontSize: 13, color: '#888', fontWeight: 600 }
const td = { padding: '14px 24px', fontSize: 14 }

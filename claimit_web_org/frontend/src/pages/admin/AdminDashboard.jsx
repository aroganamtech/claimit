import { useEffect, useState } from 'react'
import api from '../../utils/api'

export default function AdminDashboard() {
  const [stats, setStats] = useState(null)

  useEffect(() => {
    api.admin.stats().then(setStats).catch(() => setStats(null))
  }, [])

  const tile = (label, value, icon, color = '#1a237e') => (
    <div style={{
      background: '#fff', borderRadius: 12, padding: 24,
      border: '1px solid #e0e0e0', display: 'flex', gap: 16, alignItems: 'center',
    }}>
      <div style={{
        width: 48, height: 48, borderRadius: '50%', background: color,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 22, color: '#fff',
      }}>{icon}</div>
      <div>
        <div style={{ fontSize: 28, fontWeight: 700 }}>{value ?? 0}</div>
        <div style={{ fontSize: 13, color: '#666' }}>{label}</div>
      </div>
    </div>
  )

  return (
    <div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>Overview</h1>
      <p style={{ color: '#666', fontSize: 13, marginBottom: 24 }}>
        Live numbers across the whole platform.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        {tile('Total Users',  stats?.users?.total,        '👥')}
        {tile('Advertisers',  stats?.users?.advertiser,   '📣', '#1565C0')}
        {tile('Sales Agents', stats?.users?.sales,        '💼', '#7B1FA2')}
        {tile('Shop Owners',  stats?.users?.shop,         '🏪', '#388E3C')}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        {tile('Total Ads',     stats?.ads_total,    '📢', '#F57C00')}
        {tile('Active Ads',    stats?.ads_active,   '✅', '#43A047')}
        {tile('Total Shops',   stats?.shops_total,  '🏬', '#5E35B1')}
        {tile('Total Reviews', stats?.reviews_total,'⭐', '#FB8C00')}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16, maxWidth: 600 }}>
        {tile('Open Tickets',   stats?.tickets_open,  '🎫', '#E53935')}
        {tile('Total Tickets',  stats?.tickets_total, '📨', '#546E7A')}
      </div>
    </div>
  )
}

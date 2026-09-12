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

      {/* App customers first — this is what people mean by "users". It used
          to be missing entirely: the old "Total Users" tile counted website
          accounts only, so app signups never appeared and the number looked
          stuck. */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 10 }}>
        {tile('App Users',        stats?.app_users,       '📱', '#1a237e')}
        {tile('Joined (24h)',     stats?.app_users_today, '🆕', '#43A047')}
        {tile('Shops Listed',     stats?.shops_total,     '🏬', '#5E35B1')}
        {tile('Shops Claimed',    stats?.shops_claimed,   '✅', '#00897B')}
      </div>
      <p style={{ fontSize: 12, color: '#888', margin: '0 0 22px' }}>
        App Users = people who installed Claimit and registered. Website
        accounts (advertisers, sales, shop owners) are counted separately below.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 10 }}>
        {tile('Website Accounts', stats?.users?.total,      '👥')}
        {tile('Advertisers',      stats?.users?.advertiser, '📣', '#1565C0')}
        {tile('Sales Agents',     stats?.users?.sales,      '💼', '#7B1FA2')}
        {tile('Shop Owners',      stats?.users?.shop,       '🏪', '#388E3C')}
      </div>
      <p style={{ fontSize: 12, color: '#888', margin: '0 0 22px' }}>
        Website Accounts = people who registered on the web portal. This grows
        only from web signups, never from app downloads.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
        {tile('Total Ads',     stats?.ads_total,    '📢', '#F57C00')}
        {tile('Active Ads',    stats?.ads_active,   '✅', '#43A047')}
        {tile('Total Reviews', stats?.reviews_total,'⭐', '#FB8C00')}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16, maxWidth: 600 }}>
        {tile('Open Tickets',   stats?.tickets_open,  '🎫', '#E53935')}
        {tile('Total Tickets',  stats?.tickets_total, '📨', '#546E7A')}
      </div>
    </div>
  )
}

import { useNavigate } from 'react-router-dom'
import AdvertiserSidebar from './AdvertiserSidebar'

export default function AdvertiserGetStarted() {
  const navigate = useNavigate()

  return (
    <div style={{ paddingTop: 64 }}>
      <AdvertiserSidebar />
      <main className="main-content" style={{
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        minHeight: 'calc(100vh - 64px)'
      }}>
        <h2 style={{ fontSize: 24, fontWeight: 600, color: '#1565C0', marginBottom: 40 }}>
          Get Started Join and Grow with us!
        </h2>

        <div
          onClick={() => navigate('/advertiser/create-ad')}
          style={{
            width: 300, padding: '40px 20px',
            background: '#fff', border: '1.5px solid #eee',
            borderRadius: 12, textAlign: 'center',
            cursor: 'pointer', marginBottom: 40,
            boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
            transition: 'box-shadow 0.2s'
          }}
        >
          <div style={{
            width: 64, height: 64, borderRadius: '50%',
            background: '#3b82f6', margin: '0 auto 16px',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontWeight: 700, fontSize: 18
          }}>AD</div>
          <div style={{ fontWeight: 600, fontSize: 15 }}>Post Advertising</div>
        </div>

        <button
          className="btn-primary"
          style={{ width: 300 }}
          onClick={() => navigate('/advertiser/create-ad')}
        >
          Get Started
        </button>
      </main>
    </div>
  )
}

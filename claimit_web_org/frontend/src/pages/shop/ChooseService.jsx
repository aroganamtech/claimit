import { useNavigate } from 'react-router-dom'

export default function ChooseService() {
  const navigate = useNavigate()

  return (
    <div style={{
      paddingTop: 64, minHeight: '100vh',
      display: 'flex'
    }}>
      {/* Minimal sidebar for onboarding */}
      <aside className="onboard-sidebar" style={{
        width: 280, minHeight: '100vh',
        background: '#fff', borderRight: '1px solid #eee',
        display: 'flex', flexDirection: 'column',
        paddingTop: 20
      }}>
        {[
          { label: '+ Add your Shop or business', bold: true },
          { label: 'Dashboard', icon: '⊞' },
          { label: 'Analytics', icon: '↗' },
          { label: 'Offer management', icon: '⚙' },
          { label: 'Store Details Management', icon: '≡' },
          { label: 'Ratings & reviews', icon: '⊟' },
          { label: 'Settings', icon: '⊙' },
        ].map((item, i) => (
          <div key={i} style={{
            padding: '14px 20px', fontSize: 14,
            fontWeight: item.bold ? 600 : 500,
            color: item.bold ? '#1565C0' : '#555',
            display: 'flex', alignItems: 'center', gap: 10,
            borderBottom: item.bold ? '1px solid #eee' : 'none'
          }}>
            {item.icon && <span>{item.icon}</span>}
            {item.label}
          </div>
        ))}
      </aside>

      <main style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', padding: 40
      }}>
        <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 48 }}>Choose The Services</h2>

        <div
          onClick={() => navigate('/shop/onboard/claim')}
          style={{
            width: 320, padding: '40px 24px',
            background: '#fff', border: '1.5px solid #eee',
            borderRadius: 12, textAlign: 'center',
            cursor: 'pointer', marginBottom: 40,
            boxShadow: '0 2px 12px rgba(0,0,0,0.06)'
          }}
        >
          <div style={{ fontSize: 40, marginBottom: 12 }}>🏪</div>
          <div style={{ fontWeight: 600, fontSize: 15 }}>Add Shop Or business</div>
        </div>

        <button
          className="btn-primary"
          style={{ width: 320 }}
          onClick={() => navigate('/shop/onboard/claim')}
        >
          Get Started
        </button>
      </main>
    </div>
  )
}

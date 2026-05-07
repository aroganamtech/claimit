import SalesSidebar from './SalesSidebar'

export default function TutorialZone() {
  return (
    <div style={{ paddingTop: 64 }}>
      <SalesSidebar />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 28 }}>Tutorials Zone</h1>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
          {[1, 2, 3, 4].map(i => (
            <div
              key={i}
              style={{
                background: '#e8e8e8', borderRadius: 12,
                height: 240, display: 'flex', alignItems: 'center',
                justifyContent: 'center', color: '#999', fontSize: 16,
                cursor: 'pointer', transition: 'background 0.2s',
                border: '1px solid #ddd'
              }}
            >
              {/* image - Video placeholder */}
              <span>Video</span>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}

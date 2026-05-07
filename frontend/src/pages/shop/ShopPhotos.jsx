import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

export default function ShopPhotos() {
  const navigate = useNavigate()
  const [coverPhoto, setCoverPhoto] = useState(null)
  const [shopPhotos, setShopPhotos] = useState(null)

  return (
    <div style={{ paddingTop: 64, display: 'flex', minHeight: '100vh' }}>
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <div style={{
          width: 380, height: 280, background: '#f8f9fa',
          borderRadius: 12, border: '2px dashed #e0e0e0',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#ccc', fontSize: 15, marginBottom: 32
        }}>
          {/* image */}
        </div>
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Drive Your Business Towards Success
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Accelerate your sales growth by offering rewards that keep customers coming back to your store time and time again.
        </p>
      </div>

      <div style={{ width: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Upload Photos of Your Shop</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>Add multiple photos to showcase your business</p>

          {/* Cover Photo */}
          <div style={{ marginBottom: 20 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 10 }}>
              Upload Cover Photo
            </label>
            <label style={{
              display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center',
              border: '2px dashed #ddd', borderRadius: 10,
              padding: '24px 20px', cursor: 'pointer',
              background: coverPhoto ? '#e8f5e9' : '#fafafa'
            }}>
              <input type="file" accept="image/*" style={{ display: 'none' }}
                onChange={e => setCoverPhoto(e.target.files[0])} />
              <span style={{ fontSize: 24, marginBottom: 6 }}>⬆</span>
              <span style={{ fontSize: 13, color: coverPhoto ? '#2e7d32' : '#888' }}>
                {coverPhoto ? coverPhoto.name : 'Click to upload cover photo'}
              </span>
            </label>
          </div>

          {/* Shop Photos */}
          <div style={{ marginBottom: 28 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 10 }}>
              Upload Shop Photos (Optional)
            </label>
            <label style={{
              display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center',
              border: '2px dashed #ddd', borderRadius: 10,
              padding: '24px 20px', cursor: 'pointer',
              background: shopPhotos ? '#e8f5e9' : '#fafafa'
            }}>
              <input type="file" accept="image/*" multiple style={{ display: 'none' }}
                onChange={e => setShopPhotos(e.target.files)} />
              <span style={{ fontSize: 24, marginBottom: 6 }}>⬆</span>
              <span style={{ fontSize: 13, color: shopPhotos ? '#2e7d32' : '#888' }}>
                {shopPhotos ? `${shopPhotos.length} file(s) selected` : 'Click to upload cover photo'}
              </span>
            </label>
          </div>

          <button className="btn-primary" onClick={() => navigate('/shop/onboard/category')}>Continue</button>
        </div>
      </div>
    </div>
  )
}

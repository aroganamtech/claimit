import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

// Convert a File object to a base64 data-URL string
function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
}

export default function ShopPhotos() {
  const navigate = useNavigate()
  const [coverPhoto, setCoverPhoto] = useState(null)
  const [shopPhotos, setShopPhotos] = useState([])
  const [loading, setLoading] = useState(false)

  const handleCoverChange = (e) => {
    const file = e.target.files[0]
    if (file) setCoverPhoto(file)
  }

  const handleShopPhotosChange = (e) => {
    const files = Array.from(e.target.files)
    setShopPhotos(files)
  }

  const handleContinue = async () => {
    setLoading(true)
    try {
      // Convert cover photo to base64
      if (coverPhoto) {
        const b64 = await fileToBase64(coverPhoto)
        sessionStorage.setItem('shop_cover_b64', b64)
      } else {
        sessionStorage.removeItem('shop_cover_b64')
      }

      // Convert each shop photo to base64
      if (shopPhotos.length > 0) {
        const b64Array = await Promise.all(shopPhotos.map(fileToBase64))
        sessionStorage.setItem('shop_photos_b64', JSON.stringify(b64Array))
      } else {
        sessionStorage.removeItem('shop_photos_b64')
      }

      navigate('/shop/onboard/category')
    } catch (err) {
      console.error('Failed to process images', err)
      // Continue even if image processing fails
      navigate('/shop/onboard/category')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ paddingTop: 64, display: 'flex', minHeight: '100vh' }}>
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', alignItems: 'center',
        padding: '60px 40px', background: '#fff'
      }}>
        <img
          src="/assets/shop-photos.svg"
          alt="Upload shop photos"
          style={{ width: 380, height: 280, borderRadius: 12, marginBottom: 32 }}
        />
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
                onChange={handleCoverChange} />
              {coverPhoto ? (
                <img
                  src={URL.createObjectURL(coverPhoto)}
                  alt="cover preview"
                  style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8, marginBottom: 6 }}
                />
              ) : (
                <span style={{ fontSize: 24, marginBottom: 6 }}>⬆</span>
              )}
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
              background: shopPhotos.length > 0 ? '#e8f5e9' : '#fafafa'
            }}>
              <input type="file" accept="image/*" multiple style={{ display: 'none' }}
                onChange={handleShopPhotosChange} />
              <span style={{ fontSize: 24, marginBottom: 6 }}>⬆</span>
              <span style={{ fontSize: 13, color: shopPhotos.length > 0 ? '#2e7d32' : '#888' }}>
                {shopPhotos.length > 0 ? `${shopPhotos.length} file(s) selected` : 'Click to upload shop photos'}
              </span>
            </label>
            {shopPhotos.length > 0 && (
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>
                {shopPhotos.map((f, i) => (
                  <img
                    key={i}
                    src={URL.createObjectURL(f)}
                    alt={`shop photo ${i + 1}`}
                    style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 6, border: '1px solid #ddd' }}
                  />
                ))}
              </div>
            )}
          </div>

          <button
            className="btn-primary"
            onClick={handleContinue}
            disabled={loading}
            style={{ opacity: loading ? 0.7 : 1 }}
          >
            {loading ? 'Processing...' : 'Continue'}
          </button>
        </div>
      </div>
    </div>
  )
}

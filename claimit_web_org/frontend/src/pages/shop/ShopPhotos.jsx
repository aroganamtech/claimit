import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

// Upload a File directly to S3 via presigned URL — same pattern as brand/nearby deals.
// Returns { key, url } — key is stored in MongoDB, url is used for preview in review page.
async function uploadShopImageToS3(file) {
  const presignRes = await api.shop.presignImage()
  const putRes = await fetch(presignRes.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/jpeg' },
    body: file,
  })
  if (!putRes.ok) throw new Error(`S3 upload failed: ${putRes.status}`)
  return { key: presignRes.key, url: presignRes.public_url }
}

// ─── Single photo upload slot ──────────────────────────────────
function PhotoSlot({ label, preview, inputId, onChange, onRemove }) {
  return (
    <div style={{ flex: '1 1 0', minWidth: 0 }}>
      <p style={{ fontSize: 12, fontWeight: 600, color: '#555', marginBottom: 8, textAlign: 'center' }}>
        {label}
      </p>
      <label
        htmlFor={inputId}
        style={{
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          border: `2px dashed ${preview ? '#1565C0' : '#ddd'}`,
          borderRadius: 10, padding: '14px 8px', cursor: 'pointer',
          background: preview ? '#EEF4FF' : '#fafafa',
          minHeight: 120, position: 'relative',
        }}
      >
        <input
          id={inputId}
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={onChange}
        />
        {preview ? (
          <>
            <img
              src={preview}
              alt={label}
              style={{ width: 72, height: 72, objectFit: 'cover', borderRadius: 7, marginBottom: 6 }}
            />
            <span style={{ fontSize: 11, color: '#1565C0', fontWeight: 600 }}>Click to change</span>
          </>
        ) : (
          <>
            <span style={{ fontSize: 26, marginBottom: 6 }}>⬆</span>
            <span style={{ fontSize: 11, color: '#888', textAlign: 'center' }}>Upload photo</span>
          </>
        )}
      </label>
      {preview && (
        <button
          onClick={onRemove}
          style={{
            display: 'block', width: '100%', marginTop: 6,
            background: 'none', border: '1px solid #e0e0e0', borderRadius: 6,
            fontSize: 11, color: '#e53935', cursor: 'pointer',
            fontFamily: 'Poppins', padding: '4px 0',
          }}
        >
          Remove
        </button>
      )}
    </div>
  )
}

export default function ShopPhotos() {
  const navigate = useNavigate()
  const [coverFile, setCoverFile] = useState(null)
  const [coverPreview, setCoverPreview] = useState(null)
  // Three individual gallery slots
  const [galleryFiles, setGalleryFiles] = useState([null, null, null])
  const [galleryPreviews, setGalleryPreviews] = useState([null, null, null])
  const [loading, setLoading] = useState(false)

  const handleCoverChange = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setCoverFile(file)
    setCoverPreview(URL.createObjectURL(file))
    e.target.value = ''
  }

  const handleGalleryChange = (index) => (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    const newFiles = [...galleryFiles]
    const newPreviews = [...galleryPreviews]
    newFiles[index] = file
    newPreviews[index] = URL.createObjectURL(file)
    setGalleryFiles(newFiles)
    setGalleryPreviews(newPreviews)
    e.target.value = ''
  }

  const handleRemoveCover = () => {
    setCoverFile(null)
    setCoverPreview(null)
  }

  const handleRemoveGallery = (index) => {
    const newFiles = [...galleryFiles]
    const newPreviews = [...galleryPreviews]
    newFiles[index] = null
    newPreviews[index] = null
    setGalleryFiles(newFiles)
    setGalleryPreviews(newPreviews)
  }

  const handleContinue = async () => {
    setLoading(true)
    // Upload each photo directly to S3 via presigned URL — same as brand/nearby deals.
    // Each photo is isolated so one failure never blocks the rest.
    const failed = []
    try {
      // Cover photo → upload directly to S3, store key + url in sessionStorage
      if (coverFile) {
        try {
          const { key, url } = await uploadShopImageToS3(coverFile)
          sessionStorage.setItem('shop_cover_key', key)
          sessionStorage.setItem('shop_cover_url', url)
        } catch (err) {
          console.error('Failed to upload cover photo', err)
          failed.push('Cover photo')
          sessionStorage.removeItem('shop_cover_key')
          sessionStorage.removeItem('shop_cover_url')
        }
      } else {
        sessionStorage.removeItem('shop_cover_key')
        sessionStorage.removeItem('shop_cover_url')
      }

      // Up to 3 gallery photos → upload directly to S3, store keys + urls in sessionStorage
      const filled = galleryFiles.filter(Boolean)
      if (filled.length > 0) {
        const results = await Promise.all(
          filled.map((file, i) =>
            uploadShopImageToS3(file)
              .then((res) => ({ ok: true, ...res }))
              .catch((err) => {
                console.error('Failed to upload gallery photo', i, err)
                failed.push(`Photo ${i + 1}`)
                return { ok: false }
              })
          )
        )
        const keys = results.filter((r) => r.ok).map((r) => r.key)
        const urls = results.filter((r) => r.ok).map((r) => r.url)
        if (keys.length > 0) {
          sessionStorage.setItem('shop_photos_keys', JSON.stringify(keys))
          sessionStorage.setItem('shop_photos_urls', JSON.stringify(urls))
        } else {
          sessionStorage.removeItem('shop_photos_keys')
          sessionStorage.removeItem('shop_photos_urls')
        }
      } else {
        sessionStorage.removeItem('shop_photos_keys')
        sessionStorage.removeItem('shop_photos_urls')
      }

      if (failed.length > 0) {
        alert(
          `Could not upload: ${failed.join(', ')}. Please try a JPG or PNG file. ` +
          `You can add photos later from your shop dashboard.`
        )
      }

      navigate('/shop/onboard/category')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-layout">
      {/* Left panel */}
      <div className="auth-left">
        <img
          src="/assets/images/register.png"
          alt="Upload shop photos"
          style={{ width: 380, height: 380, borderRadius: 12, marginBottom: 32 }}
        />
        <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
          Drive Your Business Towards Success
        </h2>
        <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
          Accelerate your sales growth by offering rewards that keep customers coming back to your store time and time again.
        </p>
      </div>

      {/* Right panel */}
      <div className="auth-right">
        <div style={{
          width: '100%', maxWidth: 440, background: '#fff',
          borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
        }}>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Upload Photos of Your Shop</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>
            Add a cover photo and up to 3 shop photos
          </p>

          {/* Cover Photo */}
          <div style={{ marginBottom: 24 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 10 }}>
              Cover Photo <span style={{ color: '#e53935' }}>*</span>
            </p>
            <label
              htmlFor="cover-photo-input"
              style={{
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', justifyContent: 'center',
                border: `2px dashed ${coverPreview ? '#1565C0' : '#ddd'}`,
                borderRadius: 10, padding: '20px', cursor: 'pointer',
                background: coverPreview ? '#EEF4FF' : '#fafafa',
              }}
            >
              <input
                id="cover-photo-input"
                type="file"
                accept="image/*"
                style={{ display: 'none' }}
                onChange={handleCoverChange}
              />
              {coverPreview ? (
                <>
                  <img
                    src={coverPreview}
                    alt="cover preview"
                    style={{ width: 90, height: 90, objectFit: 'cover', borderRadius: 8, marginBottom: 8 }}
                  />
                  <span style={{ fontSize: 12, color: '#1565C0', fontWeight: 600 }}>Click to change cover photo</span>
                </>
              ) : (
                <>
                  <span style={{ fontSize: 26, marginBottom: 6 }}>⬆</span>
                  <span style={{ fontSize: 13, color: '#888' }}>Click to upload cover photo</span>
                </>
              )}
            </label>
            {coverPreview && (
              <button
                onClick={handleRemoveCover}
                style={{
                  display: 'block', width: '100%', marginTop: 8,
                  background: 'none', border: '1px solid #e0e0e0', borderRadius: 7,
                  fontSize: 12, color: '#e53935', cursor: 'pointer',
                  fontFamily: 'Poppins', padding: '5px 0',
                }}
              >
                Remove cover photo
              </button>
            )}
          </div>

          {/* 3 Gallery Photo Slots */}
          <div style={{ marginBottom: 28 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 10 }}>
              Shop Photos (up to 3)
            </p>
            <div style={{ display: 'flex', gap: 10 }}>
              {[0, 1, 2].map((i) => (
                <PhotoSlot
                  key={i}
                  label={`Photo ${i + 1}`}
                  preview={galleryPreviews[i]}
                  inputId={`gallery-photo-${i}`}
                  onChange={handleGalleryChange(i)}
                  onRemove={() => handleRemoveGallery(i)}
                />
              ))}
            </div>
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

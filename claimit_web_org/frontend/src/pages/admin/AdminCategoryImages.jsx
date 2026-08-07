// ─────────────────────────────────────────────────────────────────────────
// Admin → Category Images. For each of the 20 shop categories, upload up to 15
// images. Shops that have no photo of their own show a random image from their
// category's pool (see backend app_shops.py). Owners can replace it later.
// ─────────────────────────────────────────────────────────────────────────
import { useEffect, useState } from 'react'
import api from '../../utils/api'

const MAX = 15

const card = {
  background: '#fff', borderRadius: 12, padding: 18, marginBottom: 16,
  boxShadow: '0 1px 4px rgba(0,0,0,0.06)',
}

export default function AdminCategoryImages() {
  const [cats, setCats] = useState([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(null)      // category_id currently uploading
  const [error, setError] = useState('')

  const load = async () => {
    setLoading(true)
    try {
      const res = await api.admin.listCategoryImages()
      setCats(res.categories || [])
    } catch (e) {
      setError('Could not load categories. ' + (e?.message || ''))
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => { load() }, [])

  const uploadToS3 = async (file) => {
    const presign = await api.admin.presignUpload({
      filename: file.name, content_type: file.type, folder: 'category-images',
    })
    const put = await fetch(presign.upload_url, {
      method: 'PUT', headers: { 'Content-Type': file.type }, body: file,
    })
    if (!put.ok) throw new Error(`S3 upload failed: ${put.status}`)
    return presign.key
  }

  const addImages = async (cat, fileList) => {
    setError('')
    const files = Array.from(fileList || [])
    if (!files.length) return
    const room = MAX - cat.keys.length
    if (room <= 0) { setError(`${cat.name} already has ${MAX} images.`); return }
    setBusy(cat.category_id)
    try {
      const uploaded = []
      for (const f of files.slice(0, room)) {
        uploaded.push(await uploadToS3(f))
      }
      const keys = [...cat.keys, ...uploaded]
      const res = await api.admin.setCategoryImages(cat.category_id, keys)
      setCats((prev) => prev.map((c) =>
        c.category_id === cat.category_id
          ? { ...c, keys, urls: res.urls || c.urls }
          : c))
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Upload failed.')
    } finally {
      setBusy(null)
    }
  }

  const removeImage = async (cat, idx) => {
    setError('')
    const keys = cat.keys.filter((_, i) => i !== idx)
    setBusy(cat.category_id)
    try {
      const res = await api.admin.setCategoryImages(cat.category_id, keys)
      setCats((prev) => prev.map((c) =>
        c.category_id === cat.category_id
          ? { ...c, keys, urls: res.urls || [] }
          : c))
    } catch (e) {
      setError(e?.message || 'Could not remove image.')
    } finally {
      setBusy(null)
    }
  }

  return (
    <div style={{ maxWidth: 900 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Category Images</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Upload up to {MAX} images per category. Shops without their own photo show a
        random image from their category here.
      </p>

      {error && (
        <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>
      )}

      {loading ? (
        <p style={{ color: '#666' }}>Loading…</p>
      ) : (
        cats.map((cat) => (
          <div key={cat.category_id} style={card}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h3 style={{ margin: 0 }}>
                <span style={{ color: '#1a237e' }}>{cat.category_id}.</span> {cat.name}
              </h3>
              <span style={{ fontSize: 13, color: cat.keys.length >= MAX ? '#c62828' : '#888' }}>
                {cat.keys.length}/{MAX}
              </span>
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
              {cat.urls.map((url, i) => (
                <div key={i} style={{ position: 'relative' }}>
                  <img src={url} alt="" style={{
                    width: 84, height: 84, objectFit: 'cover',
                    borderRadius: 8, border: '1px solid #eee',
                  }} />
                  <button
                    onClick={() => removeImage(cat, i)}
                    title="Remove"
                    style={{
                      position: 'absolute', top: -8, right: -8, width: 22, height: 22,
                      borderRadius: '50%', border: 'none', background: '#e53935',
                      color: '#fff', cursor: 'pointer', fontSize: 13, lineHeight: '22px',
                    }}
                  >×</button>
                </div>
              ))}

              {cat.keys.length < MAX && (
                <label style={{
                  width: 84, height: 84, borderRadius: 8, border: '1.5px dashed #90caf9',
                  background: '#f3f8ff', color: '#1565c0', display: 'flex',
                  flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                  cursor: busy === cat.category_id ? 'default' : 'pointer', fontSize: 12,
                }}>
                  {busy === cat.category_id ? 'Uploading…' : (<><span style={{ fontSize: 22 }}>＋</span>Add</>)}
                  <input
                    type="file" accept="image/*" multiple
                    disabled={busy === cat.category_id}
                    style={{ display: 'none' }}
                    onChange={(e) => { addImages(cat, e.target.files); e.target.value = '' }}
                  />
                </label>
              )}
            </div>
          </div>
        ))
      )}
    </div>
  )
}

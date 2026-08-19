// ─────────────────────────────────────────────────────────────────────────
// Admin → Category Images for Claimit Select / Local Finds / Classifieds.
//
// Same idea as the shops "Category Images" page, but each of these three is a
// separate product with its own category set, so the scope picker below
// decides which product's pools you are editing. Pools are stored per
// (scope, category) and never overlap.
//
// A bulk-uploaded row that doesn't name its own photo gets a random image from
// its category's pool here, so a listing never appears with a blank image.
// ─────────────────────────────────────────────────────────────────────────
import { useEffect, useState } from 'react'
import api from '../../utils/api'

const MAX = 15

const card = {
  background: '#fff', borderRadius: 12, padding: 18, marginBottom: 16,
  boxShadow: '0 1px 4px rgba(0,0,0,0.06)',
}
const btn = {
  padding: '10px 18px', borderRadius: 8, border: 'none', cursor: 'pointer',
  fontFamily: 'inherit', fontSize: 14, fontWeight: 600,
}

const SCOPES = [
  { id: 'select',     label: 'Claimit Select', blurb: 'Doctors, lawyers, interior designers…' },
  { id: 'local_find', label: 'Local Finds',    blurb: 'Business directory listings' },
  { id: 'classified', label: 'Classifieds',    blurb: 'Item and service posts' },
]

export default function AdminFeatureCategoryImages() {
  const [scope, setScope] = useState('select')
  const [cats, setCats] = useState([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(null)      // category_id currently uploading
  const [error, setError] = useState('')

  const current = SCOPES.find((s) => s.id === scope) || SCOPES[0]

  const load = async (s) => {
    setLoading(true)
    setError('')
    try {
      const res = await api.admin.listFeatureCategoryImages(s)
      setCats(res.categories || [])
    } catch (e) {
      setError('Could not load categories. ' + (e?.message || ''))
      setCats([])
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => { load(scope) }, [scope])

  const uploadToS3 = async (file) => {
    const ct = file.type || 'image/jpeg'
    const presign = await api.admin.presignUpload({
      filename: file.name, content_type: ct, folder: 'category-images',
    })
    const put = await fetch(presign.upload_url, {
      method: 'PUT', headers: { 'Content-Type': ct }, body: file,
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
      const res = await api.admin.setFeatureCategoryImages(scope, cat.category_id, keys)
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
      const res = await api.admin.setFeatureCategoryImages(scope, cat.category_id, keys)
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
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Category Images — Select / Local Finds / Classifieds
      </h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Upload up to {MAX} images per category. A bulk-uploaded listing that has
        no photo of its own shows a random image from its category here.
      </p>

      <div style={card}>
        <h3 style={{ margin: '0 0 10px' }}>Which product?</h3>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          {SCOPES.map((s) => {
            const on = scope === s.id
            return (
              <button
                key={s.id}
                onClick={() => setScope(s.id)}
                disabled={!!busy}
                style={{
                  ...btn,
                  flex: '1 1 200px',
                  textAlign: 'left',
                  padding: '12px 14px',
                  background: on ? '#EFF6FF' : '#fff',
                  border: `1.5px solid ${on ? '#1a237e' : '#e0e0e0'}`,
                  color: '#1e293b',
                }}
              >
                <span style={{ fontSize: 14.5, fontWeight: 700, color: on ? '#1a237e' : '#1e293b' }}>
                  {on ? '● ' : '○ '}{s.label}
                </span>
                <span style={{ display: 'block', fontSize: 12, color: '#666', marginTop: 3, fontWeight: 400 }}>
                  {s.blurb}
                </span>
              </button>
            )
          })}
        </div>
        <p style={{ color: '#b26a00', fontSize: 12.5, margin: '12px 0 0' }}>
          Editing pools for <b>{current.label}</b>. Each product keeps its own
          images — these never affect shop category images.
        </p>
      </div>

      {error && (
        <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>
      )}

      {loading ? (
        <p style={{ color: '#666' }}>Loading…</p>
      ) : (
        cats.map((cat) => (
          <div key={cat.category_id} style={card}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h3 style={{ margin: 0 }}>{cat.name}</h3>
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

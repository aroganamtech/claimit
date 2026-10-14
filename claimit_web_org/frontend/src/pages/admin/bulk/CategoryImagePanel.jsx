// ─────────────────────────────────────────────────────────────────────────
// Category image pool for ONE feature.
//
// Lifted out of AdminFeatureCategoryImages so each feature's own bulk page
// can carry its own pool, instead of every pool living on one shared screen
// that nobody could find. That page still exists and still works; this is
// the same grid with the scope fixed by a prop rather than a picker.
//
// What the pool is for: when a bulk-upload row does not name a photo, the
// importer picks one at random from its category's pool. Fill a pool and a
// thousand rows arrive with sensible pictures instead of grey placeholders.
// ─────────────────────────────────────────────────────────────────────────
import { useEffect, useState } from 'react'
import api from '../../../utils/api'

const MAX = 15

const card = {
  background: '#fff', borderRadius: 12, padding: 24, marginBottom: 20,
  boxShadow: '0 1px 4px rgba(0,0,0,0.06)',
}
const btn = {
  padding: '8px 14px', borderRadius: 8, border: 'none', cursor: 'pointer',
  fontFamily: 'inherit', fontSize: 13, fontWeight: 600,
}

export default function CategoryImagePanel({ scope, label, step }) {
  const [cats, setCats] = useState([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(null)       // category_id currently uploading
  const [error, setError] = useState('')
  const [open, setOpen] = useState(false)

  const load = async () => {
    setLoading(true); setError('')
    try {
      const res = await api.admin.listFeatureCategoryImages(scope)
      setCats(res.categories || [])
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Could not load categories.')
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => { load() }, [scope])   // eslint-disable-line react-hooks/exhaustive-deps

  const addImages = async (cat, files) => {
    if (!files || !files.length) return
    setError(''); setBusy(cat.category_id)
    try {
      const keys = [...(cat.keys || [])]
      for (const f of files) {
        if (keys.length >= MAX) break
        const ct = f.type || 'image/jpeg'
        const presign = await api.admin.presignUpload({
          filename: f.name, content_type: ct,
          folder: `${scope}/category-images/${cat.category_id}`,
        })
        const put = await fetch(presign.upload_url, {
          method: 'PUT', headers: { 'Content-Type': ct }, body: f,
        })
        if (!put.ok) throw new Error(`${f.name}: upload failed (${put.status})`)
        keys.push(presign.key)
      }
      const res = await api.admin.setFeatureCategoryImages(scope, cat.category_id, keys)
      setCats((prev) => prev.map((c) =>
        c.category_id === cat.category_id ? { ...c, keys, urls: res.urls || [] } : c))
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Upload failed.')
    } finally {
      setBusy(null)
    }
  }

  const removeImage = async (cat, idx) => {
    setError(''); setBusy(cat.category_id)
    try {
      const keys = (cat.keys || []).filter((_, i) => i !== idx)
      const res = await api.admin.setFeatureCategoryImages(scope, cat.category_id, keys)
      setCats((prev) => prev.map((c) =>
        c.category_id === cat.category_id ? { ...c, keys, urls: res.urls || [] } : c))
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Could not remove the image.')
    } finally {
      setBusy(null)
    }
  }

  const filled = cats.filter((c) => (c.keys || []).length > 0).length

  return (
    <div style={card}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <div>
          <h3 style={{ margin: '0 0 6px' }}>
            {step}. Category images <span style={{ fontWeight: 400, color: '#666', fontSize: 13 }}>(optional)</span>
          </h3>
          <p style={{ color: '#666', fontSize: 13, margin: 0 }}>
            A pool of stock photos per {label} category. Any upload row that does
            not name its own photo gets one of these at random.
            {!loading && (
              <> <b>{filled} of {cats.length}</b> categories have images.</>
            )}
          </p>
        </div>
        <button style={{ ...btn, background: open ? '#eef2ff' : '#1a237e',
                         color: open ? '#1a237e' : '#fff', whiteSpace: 'nowrap' }}
                onClick={() => setOpen((v) => !v)}>
          {open ? 'Hide' : 'Manage images'}
        </button>
      </div>

      {error && (
        <div style={{ background: '#fdecea', color: '#b71c1c', borderRadius: 8,
                      padding: '10px 12px', fontSize: 13, marginTop: 14 }}>{error}</div>
      )}

      {open && (
        <div style={{ marginTop: 18 }}>
          {loading ? (
            <p style={{ color: '#666', fontSize: 14 }}>Loading categories…</p>
          ) : cats.length === 0 ? (
            <p style={{ color: '#b26a00', fontSize: 14 }}>
              No categories configured for {label}.
            </p>
          ) : (
            <div style={{ display: 'grid', gap: 14,
                          gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))' }}>
              {cats.map((cat) => {
                const keys = cat.keys || []
                const urls = cat.urls || []
                const isBusy = busy === cat.category_id
                return (
                  <div key={cat.category_id}
                       style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 12 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between',
                                  alignItems: 'baseline', marginBottom: 8 }}>
                      <b style={{ fontSize: 14 }}>{cat.name || cat.category_id}</b>
                      <span style={{ fontSize: 12, color: keys.length ? '#2e7d32' : '#b26a00' }}>
                        {keys.length}/{MAX}
                      </span>
                    </div>

                    {urls.length > 0 && (
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 10 }}>
                        {urls.map((u, i) => (
                          <div key={i} style={{ position: 'relative' }}>
                            <img src={u} alt="" width={54} height={54}
                                 style={{ objectFit: 'cover', borderRadius: 6,
                                          border: '1px solid #e5e7eb' }} />
                            <button
                              onClick={() => removeImage(cat, i)}
                              disabled={isBusy}
                              title="Remove"
                              style={{ position: 'absolute', top: -6, right: -6, width: 18,
                                       height: 18, lineHeight: '16px', borderRadius: 9,
                                       border: 'none', background: '#b71c1c', color: '#fff',
                                       fontSize: 12, cursor: 'pointer', padding: 0 }}>×</button>
                          </div>
                        ))}
                      </div>
                    )}

                    <input
                      type="file" accept="image/*" multiple
                      disabled={isBusy || keys.length >= MAX}
                      onChange={(e) => { addImages(cat, e.target.files); e.target.value = '' }}
                      style={{ fontSize: 12, width: '100%' }}
                    />
                    {isBusy && (
                      <p style={{ color: '#1a237e', fontSize: 12, margin: '6px 0 0' }}>Uploading…</p>
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

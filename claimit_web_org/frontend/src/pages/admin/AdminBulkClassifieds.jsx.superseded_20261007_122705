// ─────────────────────────────────────────────────────────────────────────
// Admin → Bulk Upload Local Finds / Classifieds.
//
// These are two SEPARATE products that share one database collection, told
// apart by the listing_type field. The picker below decides which product you
// are working with: it selects the template, and it is stamped on every row
// that gets inserted. Pick the wrong one and the rows land in the wrong app,
// so the choice is deliberately explicit and shown throughout.
//
// "Replace" deletes ONLY rows this tool created, and only for the selected
// product — a user's own listing is never removed, and the other product is
// never touched.
// ─────────────────────────────────────────────────────────────────────────
import { useState } from 'react'
import api from '../../utils/api'

const card = {
  background: '#fff', borderRadius: 12, padding: 24, marginBottom: 20,
  boxShadow: '0 1px 4px rgba(0,0,0,0.06)',
}
const btn = {
  padding: '10px 18px', borderRadius: 8, border: 'none', cursor: 'pointer',
  fontFamily: 'inherit', fontSize: 14, fontWeight: 600,
}

const PRODUCTS = [
  {
    id: 'local_find',
    label: 'Local Finds',
    blurb: 'Business directory listings — shops and services people browse by zone.',
    titleCol: 'business_name',
    file: 'claimit_local_finds_template.xlsx',
  },
  {
    id: 'classified',
    label: 'Classifieds',
    blurb: 'Item and service posts — things people buy, sell or offer.',
    titleCol: 'title',
    file: 'claimit_classifieds_template.xlsx',
  },
]

export default function AdminBulkClassifieds() {
  const [type, setType] = useState('local_find')
  const [file, setFile] = useState(null)
  // Photos are uploaded BEFORE the sheet and referenced by filename in its
  // `image` column — pasting pictures into Excel is unreliable.
  const [images, setImages] = useState({})     // { filename: s3Key }
  const [imgBusy, setImgBusy] = useState('')
  const [replace, setReplace] = useState(false)
  const [busy, setBusy] = useState('')
  const [result, setResult] = useState(null)
  const [error, setError] = useState('')

  const product = PRODUCTS.find((p) => p.id === type) || PRODUCTS[0]

  const switchType = (id) => {
    // Clear the chosen file: a Local Finds sheet has different columns from a
    // Classifieds one, so carrying it across products would only cause errors.
    setType(id)
    setFile(null)
    setImages({})
    setResult(null)
    setError('')
  }

  const downloadTemplate = async () => {
    setError('')
    try {
      setBusy('Preparing template…')
      const blob = await api.admin.downloadClassifiedsTemplate(type)
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = product.file
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
    } catch (e) {
      setError('Could not download the template. ' + (e?.message || ''))
    } finally {
      setBusy('')
    }
  }

  const uploadImages = async (files) => {
    if (!files || !files.length) return
    setError('')
    const map = { ...images }
    try {
      for (let i = 0; i < files.length; i++) {
        const f = files[i]
        setImgBusy(`Uploading photo ${i + 1} of ${files.length}…`)
        const ct = f.type || 'image/jpeg'
        // Photos go into a folder named after the product being uploaded —
        // "local_find/images" or "classified/images" — so the two products'
        // images stay separate in S3 instead of sharing one prefix.
        const presign = await api.admin.presignUpload({
          filename: f.name, content_type: ct, folder: `${type}/images`,
        })
        const put = await fetch(presign.upload_url, {
          method: 'PUT', headers: { 'Content-Type': ct }, body: f,
        })
        if (!put.ok) throw new Error(`${f.name}: upload failed (${put.status})`)
        map[f.name] = presign.key
      }
      setImages(map)
    } catch (e) {
      setError(e?.message || 'Photo upload failed.')
    } finally {
      setImgBusy('')
    }
  }

  const upload = async () => {
    setError(''); setResult(null)
    if (!file) { setError('Choose a .xlsx file first.'); return }
    if (replace && !window.confirm(
      `Delete previously bulk-uploaded ${product.label} rows before inserting?\n\n` +
      "Listings people created themselves are NOT affected, and the other " +
      'product is not touched.'
    )) return
    try {
      setBusy('Uploading file…')
      const ct = file.type ||
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      const presign = await api.admin.presignUpload({
        filename: file.name, content_type: ct, folder: 'bulk-uploads',
      })
      const put = await fetch(presign.upload_url, {
        method: 'PUT', headers: { 'Content-Type': ct }, body: file,
      })
      if (!put.ok) throw new Error(`Upload to storage failed: ${put.status}`)

      setBusy('Inserting…')
      const res = await api.admin.bulkUploadClassifieds(
        { key: presign.key, images }, type, replace,
      )
      setResult(res)
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Upload failed.')
    } finally {
      setBusy('')
    }
  }

  return (
    <div style={{ maxWidth: 820 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Bulk Upload — Local Finds / Classifieds
      </h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Add many listings at once. Upload the photos first, then reference each
        one by file name in the sheet's image column.
      </p>

      <div style={card}>
        <h3 style={{ margin: '0 0 10px' }}>1. Which product?</h3>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {PRODUCTS.map((p) => {
            const on = type === p.id
            return (
              <button
                key={p.id}
                onClick={() => switchType(p.id)}
                style={{
                  ...btn,
                  flex: '1 1 260px',
                  textAlign: 'left',
                  padding: '14px 16px',
                  background: on ? '#EFF6FF' : '#fff',
                  border: `1.5px solid ${on ? '#1a237e' : '#e0e0e0'}`,
                  color: '#1e293b',
                }}
              >
                <span style={{ fontSize: 15, fontWeight: 700, color: on ? '#1a237e' : '#1e293b' }}>
                  {on ? '● ' : '○ '}{p.label}
                </span>
                <span style={{ display: 'block', fontSize: 12.5, color: '#666', marginTop: 4, fontWeight: 400 }}>
                  {p.blurb}
                </span>
              </button>
            )
          })}
        </div>
        <p style={{ color: '#b26a00', fontSize: 12.5, margin: '12px 0 0' }}>
          These two share one database collection and are kept apart by this
          setting — the rows you upload are tagged as <b>{product.label}</b>.
        </p>
      </div>

      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>2. Download the {product.label} template</h3>
        <p style={{ color: '#666', fontSize: 13, margin: '0 0 14px' }}>
          One listing per row. <b>{product.titleCol}</b>, <b>category</b> and <b>phone</b> are
          required. The category dropdown only contains {product.label} categories.
        </p>
        <button style={{ ...btn, background: '#1a237e', color: '#fff' }}
                onClick={downloadTemplate} disabled={!!busy}>
          ⬇ Download {product.label} template
        </button>
      </div>


      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>3. Upload photos <span style={{ fontWeight: 400, color: '#666', fontSize: 13 }}>(optional)</span></h3>
        <p style={{ color: '#666', fontSize: 13, margin: '0 0 12px' }}>
          Select all the photos first. Then, in the sheet's <b>image</b> column,
          type the matching file name (e.g. <code>ananya.jpg</code>). Matching
          ignores capitals and the extension is optional.
        </p>
        <input
          type="file"
          accept="image/*"
          multiple
          onChange={(e) => uploadImages(e.target.files)}
          style={{ display: 'block', margin: '0 0 12px', fontSize: 14 }}
        />
        {imgBusy && <p style={{ color: '#1a237e', fontSize: 13, margin: 0 }}>{imgBusy}</p>}
        {Object.keys(images).length > 0 && (
          <div style={{ background: '#F1F8E9', border: '1px solid #C5E1A5',
                        borderRadius: 8, padding: '10px 12px', fontSize: 13 }}>
            <b>{Object.keys(images).length} photo(s) ready.</b> Use these exact
            names in the image column:
            <div style={{ marginTop: 6, color: '#33691E', wordBreak: 'break-all' }}>
              {Object.keys(images).join(' · ')}
            </div>
          </div>
        )}
      </div>
      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>4. Upload the filled file</h3>
        <input
          type="file"
          accept=".xlsx,.xlsm"
          onChange={(e) => { setFile(e.target.files?.[0] || null); setResult(null) }}
          style={{ display: 'block', margin: '10px 0 16px', fontSize: 14 }}
        />

        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, marginBottom: 16 }}>
          <input type="checkbox" checked={replace} onChange={(e) => setReplace(e.target.checked)} />
          <span>
            Remove previous {product.label} bulk uploads first
            <span style={{ color: '#b26a00', marginLeft: 6, fontSize: 12 }}>
              (user-created listings and the other product are never touched)
            </span>
          </span>
        </label>

        <button style={{ ...btn, background: '#2e7d32', color: '#fff' }}
                onClick={upload} disabled={!!busy || !file}>
          {busy ? busy : `⬆ Upload & insert as ${product.label}`}
        </button>
        <p style={{ color: '#666', fontSize: 12.5, margin: '12px 0 0' }}>
          Re-uploading a corrected sheet is safe — a row with the same phone and
          title updates that listing instead of creating a duplicate.
        </p>
      </div>

      {error && (
        <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>
      )}

      {result && (
        <div style={card}>
          <h3 style={{ margin: '0 0 10px' }}>Result</h3>
          <p style={{ margin: '4px 0', fontSize: 15 }}>
            ✅ Added <b>{result.inserted}</b>, updated <b>{result.updated}</b>{' '}
            {product.label} listing(s)
            {result.replaced ? ' (previous bulk uploads were cleared first)' : ''}.
          </p>
          {result.skipped_empty && (
            <p style={{ color: '#b26a00', fontSize: 14 }}>
              No filled rows were found — did you fill in the {product.titleCol} column?
            </p>
          )}
          {result.errors?.length > 0 && (
            <>
              <p style={{ color: '#b71c1c', fontWeight: 600, marginTop: 12 }}>
                {result.errors.length} row(s) had problems:
              </p>
              <ul style={{ margin: 0, paddingLeft: 20, fontSize: 13, color: '#b71c1c' }}>
                {result.errors.map((er, i) => (
                  <li key={i}>Row {er.row} ({er.name || '—'}): {er.error}</li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────
// Admin → Bulk Upload Claimit Select. Download the template, fill one
// PROFESSIONAL per row, upload the photos separately, then upload the sheet.
//
// Writes only to claimit_db.select_professionals — Claimit Select has its own
// collection, so this can never touch Local Finds or Classifieds data.
//
// "Replace" here deletes ONLY rows this tool created (source="bulk"); a
// professional who registered and paid in the app is never removed.
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

export default function AdminBulkSelect() {
  const [file, setFile] = useState(null)
  // Photos are uploaded BEFORE the sheet and referenced by filename in its
  // `image` column — pasting pictures into Excel is unreliable.
  const [images, setImages] = useState({})     // { filename: s3Key }
  const [imgBusy, setImgBusy] = useState('')
  const [replace, setReplace] = useState(false)
  const [busy, setBusy] = useState('')
  const [result, setResult] = useState(null)
  const [error, setError] = useState('')

  const downloadTemplate = async () => {
    setError('')
    try {
      setBusy('Preparing template…')
      const blob = await api.admin.downloadSelectTemplate()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'claimit_select_template.xlsx'
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
        // Each product keeps its photos in its own S3 folder, so Select,
        // Local Finds and Classifieds images never sit mixed in one bucket
        // prefix.
        const presign = await api.admin.presignUpload({
          filename: f.name, content_type: ct, folder: 'select/images',
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
      'Delete previously bulk-uploaded professionals before inserting?\n\n' +
      'Professionals who registered themselves in the app are NOT affected.'
    )) return
    try {
      // The .xlsx goes straight to S3; only its key reaches the API.
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
      const res = await api.admin.bulkUploadSelect({ key: presign.key, images }, replace)
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
        Bulk Upload — Claimit Select
      </h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Add many professionals at once (doctors, lawyers, interior designers…).
        Upload the photos first, then reference each one by file name in the
        sheet's image column.
      </p>

      <div style={{ ...card, background: '#EFF6FF', border: '1px solid #BFDBFE' }}>
        <b style={{ fontSize: 14 }}>This writes only to Claimit Select.</b>
        <p style={{ color: '#1e3a8a', fontSize: 13, margin: '6px 0 0' }}>
          Claimit Select has its own database collection, so nothing here can
          affect Local Finds or Classifieds listings.
        </p>
      </div>

      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>1. Download the template</h3>
        <p style={{ color: '#666', fontSize: 13, margin: '0 0 14px' }}>
          One professional per row. <b>name</b>, <b>category</b> and <b>phone</b> are
          required. Category and plan have dropdowns. See the Instructions sheet.
        </p>
        <button style={{ ...btn, background: '#1a237e', color: '#fff' }}
                onClick={downloadTemplate} disabled={!!busy}>
          ⬇ Download Excel template
        </button>
      </div>


      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>2. Upload photos <span style={{ fontWeight: 400, color: '#666', fontSize: 13 }}>(optional)</span></h3>
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
        <h3 style={{ margin: '0 0 8px' }}>3. Upload the filled file</h3>
        <input
          type="file"
          accept=".xlsx,.xlsm"
          onChange={(e) => { setFile(e.target.files?.[0] || null); setResult(null) }}
          style={{ display: 'block', margin: '10px 0 16px', fontSize: 14 }}
        />

        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, marginBottom: 16 }}>
          <input type="checkbox" checked={replace} onChange={(e) => setReplace(e.target.checked)} />
          <span>
            Remove previous bulk uploads first
            <span style={{ color: '#b26a00', marginLeft: 6, fontSize: 12 }}>
              (self-registered professionals are never deleted)
            </span>
          </span>
        </label>

        <button style={{ ...btn, background: '#2e7d32', color: '#fff' }}
                onClick={upload} disabled={!!busy || !file}>
          {busy ? busy : '⬆ Upload & insert'}
        </button>
        <p style={{ color: '#666', fontSize: 12.5, margin: '12px 0 0' }}>
          Re-uploading a corrected sheet is safe — a row with the same phone
          number updates that professional instead of creating a duplicate.
        </p>
      </div>

      {error && (
        <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>
      )}

      {result && (
        <div style={card}>
          <h3 style={{ margin: '0 0 10px' }}>Result</h3>
          <p style={{ margin: '4px 0', fontSize: 15 }}>
            ✅ Added <b>{result.inserted}</b>, updated <b>{result.updated}</b> professional(s)
            {result.replaced ? ' (previous bulk uploads were cleared first)' : ''}.
          </p>
          {result.skipped_empty && (
            <p style={{ color: '#b26a00', fontSize: 14 }}>
              No filled rows were found — did you fill in the name column?
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

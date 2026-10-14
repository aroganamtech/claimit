// ─────────────────────────────────────────────────────────────────────────
// One bulk-upload page, shared by all four features.
//
// Every feature needs the same four things in the same order — category
// images, download the sheet, upload photos, upload the sheet — and they
// used to be spread across three screens with two of them sharing a page
// behind a product picker. Nobody could find anything, and Privilege had no
// category-image screen at all.
//
// This component is the page. Each feature supplies a small config object
// (see the four files next to this one) and nothing else. A fix made here
// is a fix made everywhere, which is the whole point.
// ─────────────────────────────────────────────────────────────────────────
import { useState } from 'react'
import api from '../../../utils/api'
import CategoryImagePanel from './CategoryImagePanel'

const card = {
  background: '#fff', borderRadius: 12, padding: 24, marginBottom: 20,
  boxShadow: '0 1px 4px rgba(0,0,0,0.06)',
}
const btn = {
  padding: '10px 18px', borderRadius: 8, border: 'none', cursor: 'pointer',
  fontFamily: 'inherit', fontSize: 14, fontWeight: 600,
}

/**
 * @param {object}   cfg
 * @param {string}   cfg.scope          category-image scope: select | local_find | classified | privilege
 * @param {string}   cfg.label          "Claimit Select"
 * @param {string}   cfg.blurb          one line under the title
 * @param {string}   cfg.titleCol       the sheet column that must be filled
 * @param {string}   cfg.requiredCols   human list of required columns
 * @param {string}   cfg.templateFile   download filename
 * @param {string}   cfg.imageFolder    S3 folder for row photos
 * @param {Function} cfg.getTemplate    () => Promise<Blob>
 * @param {Function} cfg.doUpload       ({key, images}, replace) => Promise<result>
 * @param {string}   [cfg.replaceNote]  extra reassurance on the Replace checkbox
 */
export default function FeatureBulkPage({ cfg }) {
  const [file, setFile] = useState(null)
  // Photos are uploaded BEFORE the sheet and referenced by filename in its
  // `image` column — pasting pictures into Excel is unreliable.
  const [images, setImages] = useState({})
  const [imgBusy, setImgBusy] = useState('')
  const [replace, setReplace] = useState(false)
  const [busy, setBusy] = useState('')
  const [result, setResult] = useState(null)
  const [error, setError] = useState('')

  const downloadTemplate = async () => {
    setError('')
    try {
      setBusy('Preparing template…')
      const blob = await cfg.getTemplate()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = cfg.templateFile
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
        const presign = await api.admin.presignUpload({
          filename: f.name, content_type: ct, folder: cfg.imageFolder,
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
      `Delete previously bulk-uploaded ${cfg.label} rows before inserting?\n\n` +
      'Records created by people themselves are NOT affected, and no other ' +
      'feature is touched.'
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
      const res = await cfg.doUpload({ key: presign.key, images }, replace)
      setResult(res)
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Upload failed.')
    } finally {
      setBusy('')
    }
  }

  // The API is not identical across the four importers: some report
  // `errors`, Privilege reports `rejected`; some report `updated`, some
  // don't. Read both rather than showing a blank result.
  const rows = result?.errors || result?.rejected || []
  const added = result?.inserted ?? 0
  const updated = result?.updated

  return (
    <div style={{ maxWidth: 900 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        {cfg.label} — Bulk Upload
      </h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>{cfg.blurb}</p>

      <CategoryImagePanel scope={cfg.scope} label={cfg.label} step={1} />

      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>2. Download the sample sheet</h3>
        <p style={{ color: '#666', fontSize: 13, margin: '0 0 14px' }}>
          One record per row. {cfg.requiredCols} The category column is a
          dropdown containing only {cfg.label} categories, so a typo cannot
          create a category the app does not know.
        </p>
        <button style={{ ...btn, background: '#1a237e', color: '#fff' }}
                onClick={downloadTemplate} disabled={!!busy}>
          ⬇ Download {cfg.label} sample sheet
        </button>
      </div>

      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>
          3. Upload photos{' '}
          <span style={{ fontWeight: 400, color: '#666', fontSize: 13 }}>(optional)</span>
        </h3>
        <p style={{ color: '#666', fontSize: 13, margin: '0 0 12px' }}>
          Select all the photos first. Then, in the sheet's <b>image</b> column,
          type the matching file name (e.g. <code>ananya.jpg</code>). Matching
          ignores capitals and the extension is optional. A row with no photo
          falls back to its category pool from step 1.
        </p>
        <input type="file" accept="image/*" multiple
               onChange={(e) => { uploadImages(e.target.files); e.target.value = '' }}
               style={{ display: 'block', margin: '0 0 12px', fontSize: 14 }} />
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
        <h3 style={{ margin: '0 0 8px' }}>4. Upload the filled sheet</h3>
        <input type="file" accept=".xlsx,.xlsm"
               onChange={(e) => { setFile(e.target.files?.[0] || null); setResult(null) }}
               style={{ display: 'block', margin: '10px 0 16px', fontSize: 14 }} />

        <label style={{ display: 'flex', alignItems: 'center', gap: 8,
                        fontSize: 14, marginBottom: 16 }}>
          <input type="checkbox" checked={replace}
                 onChange={(e) => setReplace(e.target.checked)} />
          <span>
            Remove previous {cfg.label} bulk uploads first
            <span style={{ color: '#b26a00', marginLeft: 6, fontSize: 12 }}>
              ({cfg.replaceNote || 'records people created themselves are never touched'})
            </span>
          </span>
        </label>

        <button style={{ ...btn, background: '#2e7d32', color: '#fff' }}
                onClick={upload} disabled={!!busy || !file}>
          {busy ? busy : `⬆ Upload & insert into ${cfg.label}`}
        </button>
        <p style={{ color: '#666', fontSize: 12.5, margin: '12px 0 0' }}>
          Re-uploading a corrected sheet is safe — a row that matches an existing
          record updates it instead of creating a duplicate.
        </p>
      </div>

      {error && <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>}

      {result && (
        <div style={card}>
          <h3 style={{ margin: '0 0 10px' }}>Result</h3>
          <p style={{ margin: '4px 0', fontSize: 15 }}>
            ✅ Added <b>{added}</b>
            {updated !== undefined && <>, updated <b>{updated}</b></>}{' '}
            {cfg.label} record(s)
            {result.replaced ? ' (previous bulk uploads were cleared first)' : ''}.
          </p>
          {result.skipped_empty && (
            <p style={{ color: '#b26a00', fontSize: 14 }}>
              No filled rows were found — did you fill in the {cfg.titleCol} column?
            </p>
          )}
          {rows.length > 0 && (
            <>
              <p style={{ color: '#b71c1c', fontWeight: 600, marginTop: 12 }}>
                {rows.length} row(s) had problems:
              </p>
              <ul style={{ margin: 0, paddingLeft: 20, fontSize: 13, color: '#b71c1c' }}>
                {rows.map((er, i) => (
                  <li key={i}>
                    Row {er.row} ({er.name || '—'}): {er.error || er.reason}
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </div>
  )
}

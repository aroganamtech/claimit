// ─────────────────────────────────────────────────────────────────────────
// Admin → Bulk Upload Shops. Download the predefined Excel template, fill one
// shop per row (paste the photo into the Image column), then upload. Rows are
// inserted into the same shops collection seed.py fills. "Replace all" wipes
// the collection first — off by default.
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

export default function AdminBulkShops() {
  const [file, setFile] = useState(null)
  const [replace, setReplace] = useState(false)
  const [busy, setBusy] = useState('')
  const [result, setResult] = useState(null)
  const [error, setError] = useState('')

  const downloadTemplate = async () => {
    setError('')
    try {
      setBusy('Preparing template…')
      const blob = await api.admin.downloadShopTemplate()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'claimit_shops_template.xlsx'
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

  const upload = async () => {
    setError(''); setResult(null)
    if (!file) { setError('Choose a .xlsx file first.'); return }
    if (replace && !window.confirm(
      'Replace all shops? This deletes every existing shop before inserting the file. Continue?'
    )) return
    try {
      setBusy('Uploading & inserting…')
      const fd = new FormData()
      fd.append('file', file)
      const res = await api.admin.bulkUploadShops(fd, replace)
      setResult(res)
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Upload failed.')
    } finally {
      setBusy('')
    }
  }

  return (
    <div style={{ maxWidth: 820 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Bulk Upload Shops</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Add many shops at once from an Excel file. Photos pasted into the Image column
        are uploaded automatically.
      </p>

      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>1. Download the template</h3>
        <p style={{ color: '#666', fontSize: 13, margin: '0 0 14px' }}>
          Fill one shop per row. Required columns are marked with *. See the
          Instructions sheet for the Category ID legend and how to paste photos.
        </p>
        <button style={{ ...btn, background: '#1a237e', color: '#fff' }}
                onClick={downloadTemplate} disabled={!!busy}>
          ⬇ Download Excel template
        </button>
      </div>

      <div style={card}>
        <h3 style={{ margin: '0 0 8px' }}>2. Upload the filled file</h3>
        <input
          type="file"
          accept=".xlsx,.xlsm"
          onChange={(e) => { setFile(e.target.files?.[0] || null); setResult(null) }}
          style={{ display: 'block', margin: '10px 0 16px', fontSize: 14 }}
        />

        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, marginBottom: 16 }}>
          <input type="checkbox" checked={replace} onChange={(e) => setReplace(e.target.checked)} />
          <span>
            Replace all shops first
            <span style={{ color: '#c62828', marginLeft: 6, fontSize: 12 }}>
              (deletes every existing shop — use with care)
            </span>
          </span>
        </label>

        <button style={{ ...btn, background: '#2e7d32', color: '#fff' }}
                onClick={upload} disabled={!!busy || !file}>
          {busy ? busy : '⬆ Upload & insert'}
        </button>
      </div>

      {error && (
        <div style={{ ...card, background: '#fdecea', color: '#b71c1c' }}>{error}</div>
      )}

      {result && (
        <div style={card}>
          <h3 style={{ margin: '0 0 10px' }}>Result</h3>
          <p style={{ margin: '4px 0', fontSize: 15 }}>
            ✅ Inserted <b>{result.inserted}</b> shop(s)
            {result.replaced ? ' (existing shops were replaced)' : ''}.
          </p>
          {result.skipped_empty && (
            <p style={{ color: '#b26a00', fontSize: 14 }}>
              No filled rows were found — did you fill in the Shop Name column?
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

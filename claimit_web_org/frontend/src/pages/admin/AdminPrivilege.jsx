import { useEffect, useState } from 'react'
import api from '../../utils/api'
import PincodeSelect from '../../components/PincodeSelect'

/*
 * Admin → Claimit Privilege
 *
 * Three tabs behind one page: the partner list (with create/edit/delete), the
 * bulk importer, and the read-only approval history.
 *
 * Two things this page is deliberate about:
 *
 *  - Pincode is a dropdown, not free text. A partner with an unresolvable
 *    pincode is saved but invisible in the app, and nobody notices for weeks.
 *  - Every list row shows whether the partner is actually placed on the map,
 *    and the header counts how many are not. That number is the single most
 *    useful thing on the page.
 */

const CARD = { background: '#fff', borderRadius: 14, border: '1px solid #e0e0e0', padding: 20 }
const INPUT = {
  width: '100%', padding: '9px 12px', border: '1.5px solid #ddd', borderRadius: 8,
  fontSize: 14, fontFamily: 'Poppins', outline: 'none', boxSizing: 'border-box',
}
const LABEL = { display: 'block', fontSize: 12.5, fontWeight: 700, color: '#333', marginBottom: 5 }
const TH = { textAlign: 'left', padding: '10px 12px', fontSize: 12, fontWeight: 700,
             color: '#555', borderBottom: '2px solid #eee', whiteSpace: 'nowrap' }
const TD = { padding: '10px 12px', fontSize: 13, borderBottom: '1px solid #f2f2f2' }

const BLANK = {
  name: '', category: 'hotels', discount_percent: '', discount_label: '',
  about: '', privilege_details: '', terms: '',
  area: '', city: '', state: '', pincode: '', address: '', phone: '',
  status: 'active',
}

export default function AdminPrivilege() {
  const [tab, setTab] = useState('partners')

  return (
    <div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>Claimit Privilege</h1>
      <p style={{ color: '#666', fontSize: 13, marginBottom: 20 }}>
        Partner businesses offering show-and-save discounts. Changes here are live
        in the app immediately.
      </p>

      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {[
          ['partners', 'Partners'],
          ['bulk', 'Bulk Upload'],
          ['history', 'Approval History'],
        ].map(([k, label]) => (
          <button
            key={k}
            onClick={() => setTab(k)}
            style={{
              padding: '9px 18px', borderRadius: 8, fontSize: 13.5, fontWeight: 700,
              fontFamily: 'Poppins', cursor: 'pointer',
              border: tab === k ? 'none' : '1px solid #ddd',
              background: tab === k ? '#1565C0' : '#fff',
              color: tab === k ? '#fff' : '#444',
            }}
          >{label}</button>
        ))}
      </div>

      {tab === 'partners' && <PartnersTab />}
      {tab === 'bulk' && <BulkTab />}
      {tab === 'history' && <HistoryTab />}
    </div>
  )
}

// ── Partners ────────────────────────────────────────────────────────────────
function PartnersTab() {
  const [cats, setCats] = useState([])
  const [rows, setRows] = useState([])
  const [unlocated, setUnlocated] = useState(0)
  const [loading, setLoading] = useState(true)
  const [filters, setFilters] = useState({ status: '', category: '', search: '' })

  const [editing, setEditing] = useState(null)   // null | BLANK | a row
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const load = () => {
    setLoading(true)
    const params = {}
    if (filters.status) params.status = filters.status
    if (filters.category) params.category = filters.category
    if (filters.search) params.search = filters.search
    api.admin.privilegeList(params)
      .then(d => { setRows(d.partners || []); setUnlocated(d.unlocated || 0) })
      .catch(() => setRows([]))
      .finally(() => setLoading(false))
  }

  useEffect(() => { api.admin.privilegeCategories().then(d => setCats(d.categories || [])).catch(() => {}) }, [])
  useEffect(load, [filters.status, filters.category])   // eslint-disable-line

  const save = async () => {
    setError('')
    if (!editing.name.trim()) { setError('Name is required'); return }
    const disc = parseFloat(editing.discount_percent)
    if (isNaN(disc) || disc < 0 || disc > 100) { setError('Discount % must be between 0 and 100'); return }
    if (!/^\d{6}$/.test(String(editing.pincode || ''))) {
      setError('Choose a pincode — without one this partner never appears in the app'); return
    }
    setSaving(true)
    try {
      const payload = { ...editing, discount_percent: disc }
      const res = editing.id
        ? await api.admin.privilegeUpdate(editing.id, payload)
        : await api.admin.privilegeCreate(payload)
      if (res && res.located === false) {
        alert('Saved, but that pincode could not be placed on the map — the '
            + 'partner will not appear in the app until it is corrected.')
      }
      setEditing(null)
      load()
    } catch (e) {
      setError(e?.response?.data?.detail || 'Could not save. Please try again.')
    } finally { setSaving(false) }
  }

  const remove = async (row) => {
    if (!window.confirm(`Delete "${row.name}"? This cannot be undone.`)) return
    await api.admin.privilegeDelete(row.id)
    load()
  }

  if (editing) {
    return (
      <div style={{ ...CARD, maxWidth: 760 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 16 }}>
          {editing.id ? 'Edit partner' : 'New partner'}
        </h2>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          <div>
            <label style={LABEL}>Business name *</label>
            <input style={INPUT} value={editing.name}
                   onChange={e => setEditing({ ...editing, name: e.target.value })} />
          </div>
          <div>
            <label style={LABEL}>Category *</label>
            <select style={INPUT} value={editing.category}
                    onChange={e => setEditing({ ...editing, category: e.target.value })}>
              {cats.map(c => <option key={c.id} value={c.id}>{c.label}</option>)}
            </select>
          </div>
          <div>
            <label style={LABEL}>Discount % *</label>
            <input style={INPUT} type="number" min="0" max="100" step="0.1"
                   value={editing.discount_percent}
                   onChange={e => setEditing({ ...editing, discount_percent: e.target.value })} />
          </div>
          <div>
            <label style={LABEL}>Applies to</label>
            <input style={INPUT} placeholder="e.g. Food and Soft Beverages"
                   value={editing.discount_label}
                   onChange={e => setEditing({ ...editing, discount_label: e.target.value })} />
          </div>
        </div>

        <div style={{ marginTop: 14 }}>
          <label style={LABEL}>About</label>
          <textarea style={{ ...INPUT, minHeight: 60 }} value={editing.about}
                    onChange={e => setEditing({ ...editing, about: e.target.value })} />
        </div>
        <div style={{ marginTop: 14 }}>
          <label style={LABEL}>Privilege details</label>
          <textarea style={{ ...INPUT, minHeight: 60 }} value={editing.privilege_details}
                    onChange={e => setEditing({ ...editing, privilege_details: e.target.value })} />
        </div>
        <div style={{ marginTop: 14 }}>
          <label style={LABEL}>Terms &amp; conditions</label>
          <textarea style={{ ...INPUT, minHeight: 60 }} value={editing.terms}
                    onChange={e => setEditing({ ...editing, terms: e.target.value })} />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 14 }}>
          <div>
            <label style={LABEL}>Area</label>
            <input style={INPUT} value={editing.area}
                   onChange={e => setEditing({ ...editing, area: e.target.value })} />
          </div>
          <div>
            <label style={LABEL}>City</label>
            <input style={INPUT} value={editing.city}
                   onChange={e => setEditing({ ...editing, city: e.target.value })} />
          </div>
          <div>
            <label style={LABEL}>Pincode *</label>
            <PincodeSelect value={editing.pincode}
                           onChange={v => setEditing({ ...editing, pincode: v })} />
          </div>
          <div>
            <label style={LABEL}>Phone</label>
            <input style={INPUT} value={editing.phone}
                   onChange={e => setEditing({ ...editing, phone: e.target.value })} />
          </div>
        </div>

        <div style={{ marginTop: 14 }}>
          <label style={LABEL}>Address</label>
          <input style={INPUT} value={editing.address}
                 onChange={e => setEditing({ ...editing, address: e.target.value })} />
        </div>

        <div style={{ marginTop: 14, maxWidth: 240 }}>
          <label style={LABEL}>Status</label>
          <select style={INPUT} value={editing.status}
                  onChange={e => setEditing({ ...editing, status: e.target.value })}>
            <option value="active">active — visible in the app</option>
            <option value="pending">pending — awaiting review</option>
            <option value="disabled">disabled — hidden</option>
          </select>
        </div>

        {error && (
          <div style={{ background: '#FFEBEE', color: '#C62828', borderRadius: 8,
                        padding: '10px 14px', marginTop: 16, fontSize: 13 }}>{error}</div>
        )}

        <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
          <button onClick={save} disabled={saving}
                  style={{ padding: '11px 24px', background: saving ? '#90A4AE' : '#1565C0',
                           color: '#fff', border: 'none', borderRadius: 8, fontWeight: 700,
                           fontSize: 14, fontFamily: 'Poppins', cursor: 'pointer' }}>
            {saving ? 'Saving…' : 'Save'}
          </button>
          <button onClick={() => { setEditing(null); setError('') }}
                  style={{ padding: '11px 24px', background: '#fff', color: '#444',
                           border: '1px solid #ddd', borderRadius: 8, fontWeight: 600,
                           fontSize: 14, fontFamily: 'Poppins', cursor: 'pointer' }}>
            Cancel
          </button>
        </div>
      </div>
    )
  }

  return (
    <div>
      {unlocated > 0 && (
        <div style={{ background: '#FFF8E1', border: '1px solid #FFE082', borderRadius: 10,
                      padding: '12px 16px', marginBottom: 16, fontSize: 13, color: '#6D4C41' }}>
          <strong>{unlocated}</strong> partner{unlocated === 1 ? ' has' : 's have'} no map
          position and will not appear anywhere in the app. Open each one and set a
          valid pincode.
        </div>
      )}

      <div style={{ display: 'flex', gap: 10, marginBottom: 14, flexWrap: 'wrap' }}>
        <select style={{ ...INPUT, width: 160 }} value={filters.status}
                onChange={e => setFilters({ ...filters, status: e.target.value })}>
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="pending">Pending review</option>
          <option value="disabled">Disabled</option>
        </select>
        <select style={{ ...INPUT, width: 220 }} value={filters.category}
                onChange={e => setFilters({ ...filters, category: e.target.value })}>
          <option value="">All categories</option>
          {cats.map(c => <option key={c.id} value={c.id}>{c.label}</option>)}
        </select>
        <input style={{ ...INPUT, width: 220 }} placeholder="Search name…"
               value={filters.search}
               onChange={e => setFilters({ ...filters, search: e.target.value })}
               onKeyDown={e => { if (e.key === 'Enter') load() }} />
        <button onClick={load}
                style={{ padding: '9px 18px', background: '#fff', border: '1px solid #ddd',
                         borderRadius: 8, fontSize: 13, fontFamily: 'Poppins', cursor: 'pointer' }}>
          Search
        </button>
        <button onClick={() => setEditing({ ...BLANK })}
                style={{ padding: '9px 18px', background: '#1565C0', color: '#fff',
                         border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 700,
                         fontFamily: 'Poppins', cursor: 'pointer', marginLeft: 'auto' }}>
          + New partner
        </button>
      </div>

      <div style={{ ...CARD, padding: 0, overflowX: 'auto' }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading…</div>
        ) : rows.length === 0 ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>No partners yet</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead><tr>
              <th style={TH}>Name</th>
              <th style={TH}>Category</th>
              <th style={TH}>Discount</th>
              <th style={TH}>Area / City</th>
              <th style={TH}>Pincode</th>
              <th style={TH}>On map</th>
              <th style={TH}>Status</th>
              <th style={TH}></th>
            </tr></thead>
            <tbody>
              {rows.map(r => (
                <tr key={r.id}>
                  <td style={TD}><strong>{r.name}</strong></td>
                  <td style={TD}>{r.category_label}</td>
                  <td style={TD}>{r.discount_percent}%</td>
                  <td style={TD}>{[r.area, r.city].filter(Boolean).join(', ') || '—'}</td>
                  <td style={TD}>{r.pincode || '—'}</td>
                  <td style={TD}>
                    {r.located
                      ? <span style={{ color: '#2E7D32', fontWeight: 700 }}>yes</span>
                      : <span style={{ color: '#C62828', fontWeight: 700 }}>NO</span>}
                  </td>
                  <td style={TD}>{r.status}</td>
                  <td style={{ ...TD, whiteSpace: 'nowrap' }}>
                    <button onClick={() => setEditing({
                      ...r, discount_percent: String(r.discount_percent ?? ''),
                    })}
                            style={{ padding: '5px 12px', background: '#fff',
                                     border: '1px solid #ddd', borderRadius: 6,
                                     fontSize: 12, cursor: 'pointer', marginRight: 6 }}>
                      Edit
                    </button>
                    <button onClick={() => remove(r)}
                            style={{ padding: '5px 12px', background: '#fff',
                                     border: '1px solid #ef9a9a', color: '#c62828',
                                     borderRadius: 6, fontSize: 12, cursor: 'pointer' }}>
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

// ── Bulk upload ─────────────────────────────────────────────────────────────
function BulkTab() {
  const [images, setImages] = useState({})     // {filename: s3 key}
  const [busy, setBusy] = useState('')
  const [result, setResult] = useState(null)
  const [error, setError] = useState('')
  const [replace, setReplace] = useState(false)

  const toS3 = async (file, folder) => {
    const presign = await api.admin.presignUpload({
      filename: file.name, content_type: file.type, folder,
    })
    const put = await fetch(presign.upload_url, {
      method: 'PUT', headers: { 'Content-Type': file.type }, body: file,
    })
    if (!put.ok) throw new Error(`Upload failed: ${put.status}`)
    return presign.key
  }

  const downloadTemplate = async () => {
    const blob = await api.admin.privilegeTemplate()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'Claimit_Privilege_Template.xlsx'
    a.click()
    URL.revokeObjectURL(url)
  }

  const uploadImages = async (files) => {
    setError(''); setBusy('Uploading images…')
    try {
      const map = { ...images }
      for (const f of files) map[f.name] = await toS3(f, 'privilege')
      setImages(map)
    } catch (e) {
      setError(e.message || 'Could not upload the images')
    } finally { setBusy('') }
  }

  const uploadSheet = async (file) => {
    setError(''); setResult(null); setBusy('Reading the sheet…')
    try {
      const key = await toS3(file, 'bulk')
      const res = await api.admin.privilegeBulkUpload({ key, images }, replace)
      setResult(res)
    } catch (e) {
      setError(e?.response?.data?.detail || e.message || 'Upload failed')
    } finally { setBusy('') }
  }

  return (
    <div style={{ maxWidth: 760 }}>
      <div style={{ ...CARD, marginBottom: 16 }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 6 }}>1. Download the template</h3>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 12 }}>
          It includes the valid category ids and an example row. Delete the example
          before uploading.
        </p>
        <button onClick={downloadTemplate}
                style={{ padding: '9px 18px', background: '#1565C0', color: '#fff',
                         border: 'none', borderRadius: 8, fontSize: 13.5, fontWeight: 700,
                         fontFamily: 'Poppins', cursor: 'pointer' }}>
          Download template
        </button>
      </div>

      <div style={{ ...CARD, marginBottom: 16 }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 6 }}>2. Upload photos (optional)</h3>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 12 }}>
          Upload these first, then put the exact filename in the sheet's{' '}
          <code>image</code> column.
        </p>
        <input type="file" accept="image/*" multiple
               onChange={e => uploadImages(Array.from(e.target.files || []))} />
        {Object.keys(images).length > 0 && (
          <p style={{ fontSize: 12.5, color: '#2E7D32', marginTop: 10, fontWeight: 600 }}>
            {Object.keys(images).length} image(s) ready
          </p>
        )}
      </div>

      <div style={CARD}>
        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 6 }}>3. Upload the sheet</h3>
        <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13,
                        color: '#666', margin: '10px 0 14px' }}>
          <input type="checkbox" checked={replace}
                 onChange={e => setReplace(e.target.checked)} />
          Delete all existing partners first (cannot be undone)
        </label>
        <input type="file" accept=".xlsx"
               onChange={e => { const f = e.target.files?.[0]; if (f) uploadSheet(f) }} />

        {busy && <p style={{ fontSize: 13, color: '#666', marginTop: 12 }}>{busy}</p>}
        {error && (
          <div style={{ background: '#FFEBEE', color: '#C62828', borderRadius: 8,
                        padding: '10px 14px', marginTop: 12, fontSize: 13 }}>{error}</div>
        )}

        {result && (
          <div style={{ marginTop: 16 }}>
            <div style={{ background: '#E8F5E9', color: '#1B5E20', borderRadius: 8,
                          padding: '12px 14px', fontSize: 13.5, fontWeight: 600 }}>
              {result.inserted} partner(s) added · {result.rejected} row(s) rejected
            </div>
            {(result.issues || []).length > 0 && (
              <div style={{ marginTop: 12, maxHeight: 300, overflowY: 'auto',
                            border: '1px solid #eee', borderRadius: 8 }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead><tr>
                    <th style={TH}>Row</th><th style={TH}>Name</th><th style={TH}>Issue</th>
                  </tr></thead>
                  <tbody>
                    {result.issues.map((it, i) => (
                      <tr key={i}>
                        <td style={TD}>{it.row ?? '—'}</td>
                        <td style={TD}>{it.name || '—'}</td>
                        <td style={{ ...TD, color: '#C62828' }}>{it.reason}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Approval history ────────────────────────────────────────────────────────
function HistoryTab() {
  const [rows, setRows] = useState([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.admin.privilegeHistory({ limit: 200 })
      .then(d => { setRows(d.history || []); setTotal(d.total || 0) })
      .catch(() => setRows([]))
      .finally(() => setLoading(false))
  }, [])

  const pretty = (iso) => {
    if (!iso) return '—'
    try { return new Date(iso).toLocaleString('en-IN') } catch { return iso }
  }

  return (
    <div>
      <p style={{ fontSize: 13, color: '#666', marginBottom: 14 }}>
        Every discount approved at a counter. Read-only — this is the record to
        check when a shop disputes a discount. Showing the most recent 200 of {total}.
      </p>
      <div style={{ ...CARD, padding: 0, overflowX: 'auto' }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>Loading…</div>
        ) : rows.length === 0 ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#888' }}>
            No discounts approved yet
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead><tr>
              <th style={TH}>Reference</th>
              <th style={TH}>Customer</th>
              <th style={TH}>Phone</th>
              <th style={TH}>Partner</th>
              <th style={TH}>Discount</th>
              <th style={TH}>Approved</th>
            </tr></thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={r.reference || i}>
                  <td style={{ ...TD, fontFamily: 'monospace', fontSize: 12 }}>{r.reference}</td>
                  <td style={TD}>{r.user_name || '—'}</td>
                  <td style={TD}>{r.user_phone || '—'}</td>
                  <td style={TD}>
                    <strong>{r.partner_name}</strong>
                    {r.partner_area && (
                      <div style={{ fontSize: 11.5, color: '#888' }}>{r.partner_area}</div>
                    )}
                  </td>
                  <td style={TD}>{r.discount_percent}%</td>
                  <td style={TD}>{pretty(r.approved_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

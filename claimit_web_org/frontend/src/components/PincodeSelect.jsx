// ─────────────────────────────────────────────────────────────────────────
// PincodeSelect — pick a PIN code instead of typing one.
//
// Why this exists: every ad is placed on the map from its PIN code, and the
// app only shows content within 5 km of the user. A typed PIN code that is
// wrong, blank, or the old "000000" placeholder produces an ad with no
// position, which then never appears anywhere and nobody notices.
//
// This component only offers PIN codes Claimit can already place, so that
// mistake becomes impossible. It is a searchable combobox (there are
// hundreds), not a plain <select>, and it never blocks: if the list cannot
// be loaded it degrades to a validated text box.
// ─────────────────────────────────────────────────────────────────────────
import { useEffect, useMemo, useRef, useState } from 'react'
import api from '../utils/api'

const box = {
  width: '100%', padding: '10px 12px', border: '1px solid #ccc', borderRadius: 8,
  fontSize: 14, boxSizing: 'border-box', fontFamily: 'inherit', background: '#fff',
}

export default function PincodeSelect({ value, onChange, placeholder = 'Search pincode, area or city…' }) {
  const [all, setAll] = useState([])
  const [loaded, setLoaded] = useState(false)
  const [failed, setFailed] = useState(false)
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const wrapRef = useRef(null)

  useEffect(() => {
    let alive = true
    api.geo.listPincodes()
      .then((d) => { if (alive) { setAll(Array.isArray(d?.pincodes) ? d.pincodes : []); setLoaded(true) } })
      .catch(() => { if (alive) { setFailed(true); setLoaded(true) } })
    return () => { alive = false }
  }, [])

  // Close the list when the user clicks elsewhere.
  useEffect(() => {
    const onDoc = (e) => { if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false) }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [])

  const selected = useMemo(
    () => all.find((p) => p.pincode === String(value || '').trim()) || null,
    [all, value],
  )

  const matches = useMemo(() => {
    const needle = query.trim().toLowerCase()
    const list = needle ? all.filter((p) => (p.label || p.pincode).toLowerCase().includes(needle)) : all
    return list.slice(0, 60)
  }, [all, query])

  // Fallback: the endpoint is unreachable. Never block the admin — accept a
  // typed PIN code but still refuse the shapes that break the map.
  if (failed) {
    const raw = String(value || '')
    const bad = raw.length !== 6 || !/^\d{6}$/.test(raw) || raw === '000000'
    return (
      <div>
        <input
          style={{ ...box, borderColor: bad ? '#e53935' : '#ccc' }}
          value={raw}
          inputMode="numeric"
          maxLength={6}
          onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, 6))}
          placeholder="6-digit pincode"
        />
        {bad && <div style={{ fontSize: 12, color: '#e53935', marginTop: 4 }}>
          Enter a real 6-digit pincode — this is what places the ad on the map.
        </div>}
      </div>
    )
  }

  return (
    <div ref={wrapRef} style={{ position: 'relative' }}>
      <input
        style={{ ...box, borderColor: selected ? '#2e7d32' : '#ccc' }}
        value={open ? query : (selected ? selected.label : (value ? String(value) : ''))}
        placeholder={loaded ? placeholder : 'Loading pincodes…'}
        onFocus={() => { setQuery(''); setOpen(true) }}
        onChange={(e) => { setQuery(e.target.value); setOpen(true) }}
        autoComplete="off"
      />

      {open && (
        <div style={{
          position: 'absolute', zIndex: 30, top: '100%', left: 0, right: 0,
          maxHeight: 260, overflowY: 'auto', background: '#fff',
          border: '1px solid #ddd', borderRadius: 8, marginTop: 2,
          boxShadow: '0 6px 18px rgba(0,0,0,0.12)',
        }}>
          {matches.length === 0 && (
            <div style={{ padding: '12px 14px', fontSize: 13, color: '#888' }}>
              {all.length === 0
                ? 'No pincodes available yet — add a shop first.'
                : 'No match. Claimit has no content in that pincode yet.'}
            </div>
          )}
          {matches.map((p) => (
            <div
              key={p.pincode}
              onClick={() => { onChange(p.pincode); setOpen(false); setQuery('') }}
              style={{
                padding: '9px 14px', fontSize: 14, cursor: 'pointer',
                background: p.pincode === value ? '#f1f8e9' : '#fff',
                borderBottom: '1px solid #f2f2f2', display: 'flex',
                justifyContent: 'space-between', gap: 10,
              }}
              onMouseEnter={(e) => { e.currentTarget.style.background = '#f5f5f5' }}
              onMouseLeave={(e) => { e.currentTarget.style.background = p.pincode === value ? '#f1f8e9' : '#fff' }}
            >
              <span>{p.label}</span>
              {p.shops > 0 && <span style={{ color: '#999', fontSize: 12, whiteSpace: 'nowrap' }}>{p.shops} shops</span>}
            </div>
          ))}
        </div>
      )}

      {!open && !selected && (
        <div style={{ fontSize: 12, color: '#e53935', marginTop: 4 }}>
          Pick a pincode from the list — this is what places the ad on the map.
        </div>
      )}
    </div>
  )
}

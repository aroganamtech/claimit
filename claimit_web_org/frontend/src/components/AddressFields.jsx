import { useEffect, useState } from 'react'
import api from '../utils/api'

// ─────────────────────────────────────────────────────────────────────────────
// AddressFields — reusable structured-address picker used by every registration
// form. All fields are chosen from dropdowns (no free typing) except the 6-digit
// pincode, which is the lookup key: entering it fetches the State, District and
// City/area list from the official India Post API (proxied by our backend).
//
//   value:    { country, state, district, city, pincode }
//   onChange: (nextValue) => void
// ─────────────────────────────────────────────────────────────────────────────

const labelStyle = { display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }
const selectStyle = {
  width: '100%', padding: '12px 14px', border: '1px solid #d0d5dd',
  borderRadius: 8, fontSize: 14, fontFamily: 'Poppins', background: '#fff', boxSizing: 'border-box',
}
const readonlyStyle = { ...selectStyle, background: '#f5f6f8', color: '#555' }

export default function AddressFields({ value, onChange }) {
  const v = value || {}
  const [countries, setCountries] = useState(['India'])
  const [states, setStates] = useState([])
  const [areas, setAreas] = useState(v.city ? [v.city] : [])
  const [pinStatus, setPinStatus] = useState('') // '' | 'loading' | 'ok' | 'error'

  useEffect(() => {
    api.geo.getCountries().then(d => setCountries(d.countries || ['India'])).catch(() => {})
    api.geo.getStates(v.country || 'India').then(d => setStates(d.states || [])).catch(() => {})
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const patch = (p) => onChange({ ...v, ...p })

  const onPincode = async (raw) => {
    const pin = raw.replace(/\D/g, '').slice(0, 6)
    patch({ pincode: pin })
    if (pin.length === 6) {
      setPinStatus('loading')
      try {
        const d = await api.geo.lookupPincode(pin)
        setAreas(d.areas || [])
        setPinStatus('ok')
        onChange({
          ...v,
          pincode: pin,
          country: d.country || 'India',
          state: d.state || v.state || '',
          district: d.district || '',
          city: (d.areas && d.areas.length === 1) ? d.areas[0] : '',
        })
      } catch {
        setPinStatus('error')
        setAreas([])
      }
    } else {
      setPinStatus('')
    }
  }

  return (
    <div>
      {/* Country */}
      <div style={{ marginBottom: 16 }}>
        <label style={labelStyle}>Country</label>
        <select style={selectStyle} value={v.country || 'India'}
          onChange={e => patch({ country: e.target.value })}>
          {countries.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      {/* Pincode (drives State / District / City) */}
      <div style={{ marginBottom: 16 }}>
        <label style={labelStyle}>Pincode <span style={{ color: '#e53935' }}>*</span></label>
        <input
          style={selectStyle}
          inputMode="numeric"
          maxLength={6}
          placeholder="6-digit pincode"
          value={v.pincode || ''}
          onChange={e => onPincode(e.target.value)}
        />
        {pinStatus === 'loading' && <div style={{ fontSize: 12, color: '#1565C0', marginTop: 6 }}>Looking up pincode…</div>}
        {pinStatus === 'error' && <div style={{ fontSize: 12, color: '#e53935', marginTop: 6 }}>No records for this pincode. Please check it.</div>}
      </div>

      {/* State */}
      <div style={{ marginBottom: 16 }}>
        <label style={labelStyle}>State <span style={{ color: '#e53935' }}>*</span></label>
        <select style={selectStyle} value={v.state || ''}
          onChange={e => patch({ state: e.target.value })}>
          <option value="">Select state</option>
          {states.map(s => <option key={s} value={s}>{s}</option>)}
        </select>
      </div>

      {/* District — auto from pincode */}
      <div style={{ marginBottom: 16 }}>
        <label style={labelStyle}>District <span style={{ color: '#e53935' }}>*</span></label>
        <input style={readonlyStyle} readOnly placeholder="Auto-filled from pincode"
          value={v.district || ''} />
      </div>

      {/* City / Area — dropdown from pincode */}
      <div style={{ marginBottom: 16 }}>
        <label style={labelStyle}>City / Area <span style={{ color: '#e53935' }}>*</span></label>
        <select style={selectStyle} value={v.city || ''} disabled={areas.length === 0}
          onChange={e => patch({ city: e.target.value })}>
          <option value="">{areas.length ? 'Select city / area' : 'Enter pincode first'}</option>
          {areas.map(a => <option key={a} value={a}>{a}</option>)}
        </select>
      </div>
    </div>
  )
}

// Helper: true when every required address field is filled.
export function isAddressComplete(v) {
  return !!(v && v.country && v.state && v.district && v.city && v.pincode && v.pincode.length === 6)
}

// Helper: single-line address string for storage / display.
export function formatAddress(v) {
  if (!v) return ''
  return [v.city, v.district, v.state, v.pincode, v.country]
    .filter(Boolean).join(', ')
}

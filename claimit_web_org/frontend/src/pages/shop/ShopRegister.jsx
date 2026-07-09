import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../utils/api'

// ─── Leaflet Map Picker Modal ──────────────────────────────────
function MapPickerModal({ onConfirm, onClose }) {
  const mapDivRef = useRef(null)
  const mapRef = useRef(null)
  const markerRef = useRef(null)
  const [selectedPos, setSelectedPos] = useState(null)
  const [leafletReady, setLeafletReady] = useState(false)
  const [statusMsg, setStatusMsg] = useState('Loading map...')

  // Dynamically load Leaflet CSS + JS from CDN
  useEffect(() => {
    // CSS
    if (!document.getElementById('leaflet-css')) {
      const link = document.createElement('link')
      link.id = 'leaflet-css'
      link.rel = 'stylesheet'
      link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
      link.integrity = 'sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY='
      link.crossOrigin = ''
      document.head.appendChild(link)
    }
    // JS — skip if already loaded
    if (window.L) { setLeafletReady(true); return }
    const script = document.createElement('script')
    script.id = 'leaflet-js'
    script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
    script.integrity = 'sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV/XN/sp38='
    script.crossOrigin = ''
    script.onload = () => setLeafletReady(true)
    script.onerror = () => setStatusMsg('Failed to load map library. Check your internet connection.')
    document.head.appendChild(script)
  }, [])

  // Initialise map once Leaflet is loaded and DOM node is mounted
  useEffect(() => {
    if (!leafletReady || !mapDivRef.current || mapRef.current) return

    const L = window.L

    // Fix missing default marker icons in bundlers
    delete L.Icon.Default.prototype._getIconUrl
    L.Icon.Default.mergeOptions({
      iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
      iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
      shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
    })

    const map = L.map(mapDivRef.current, { zoomControl: true }).setView([20.5937, 78.9629], 5)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map)
    mapRef.current = map
    setStatusMsg('')

    // Place/move marker on map click
    const addOrMoveMarker = (latlng) => {
      if (markerRef.current) {
        markerRef.current.setLatLng(latlng)
      } else {
        const m = L.marker(latlng, { draggable: true }).addTo(map)
        markerRef.current = m
        m.on('dragend', () => {
          const pos = m.getLatLng()
          setSelectedPos({ lat: pos.lat, lng: pos.lng })
        })
      }
      setSelectedPos({ lat: latlng.lat, lng: latlng.lng })
    }

    map.on('click', (e) => addOrMoveMarker(e.latlng))

    // Request device location
    if (navigator.geolocation) {
      setStatusMsg('Requesting your location...')
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const { latitude: lat, longitude: lng } = pos.coords
          map.setView([lat, lng], 16)
          addOrMoveMarker({ lat, lng })
          setStatusMsg('')
        },
        () => {
          // Permission denied or unavailable – let user click manually
          setStatusMsg('Could not detect location. Click on the map to select your shop position.')
        },
        { enableHighAccuracy: true, timeout: 10000 }
      )
    } else {
      setStatusMsg('Geolocation not supported. Click on the map to select your shop position.')
    }

    return () => {
      map.remove()
      mapRef.current = null
      markerRef.current = null
    }
  }, [leafletReady])

  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
      zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center'
    }}>
      <div style={{
        background: '#fff', borderRadius: 16, padding: 24,
        width: '92%', maxWidth: 660,
        boxShadow: '0 12px 48px rgba(0,0,0,0.25)',
        display: 'flex', flexDirection: 'column'
      }}>
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <h3 style={{ fontWeight: 700, fontSize: 18, margin: 0 }}>Select Shop Location</h3>
          <button
            onClick={onClose}
            style={{
              background: 'none', border: 'none', fontSize: 20,
              cursor: 'pointer', color: '#666', lineHeight: 1
            }}
          >✕</button>
        </div>

        <p style={{ fontSize: 13, color: '#888', margin: '0 0 12px' }}>
          Click anywhere on the map to pin your shop location, or drag the marker to adjust.
        </p>

        {/* Status message */}
        {statusMsg && (
          <div style={{
            fontSize: 12, color: '#1565C0', background: '#EEF4FF',
            borderRadius: 6, padding: '8px 12px', marginBottom: 10
          }}>
            {statusMsg}
          </div>
        )}

        {/* Map container */}
        <div
          ref={mapDivRef}
          style={{
            height: 370, borderRadius: 10, overflow: 'hidden',
            border: '1px solid #e0e0e0', background: '#f0f0f0'
          }}
        />

        {/* Selected coords */}
        {selectedPos && (
          <div style={{ fontSize: 12, color: '#2e7d32', marginTop: 8 }}>
            📍 Selected: {selectedPos.lat.toFixed(5)}, {selectedPos.lng.toFixed(5)}
          </div>
        )}

        {/* Footer buttons */}
        <div style={{ display: 'flex', gap: 10, marginTop: 16, justifyContent: 'flex-end' }}>
          <button
            onClick={onClose}
            style={{
              padding: '10px 22px', border: '1px solid #ddd', borderRadius: 8,
              background: '#fff', cursor: 'pointer', fontFamily: 'Poppins', fontSize: 14
            }}
          >Cancel</button>
          <button
            onClick={() => selectedPos && onConfirm(selectedPos)}
            disabled={!selectedPos}
            style={{
              padding: '10px 22px', background: '#1565C0', color: '#fff',
              border: 'none', borderRadius: 8, fontFamily: 'Poppins', fontSize: 14,
              cursor: selectedPos ? 'pointer' : 'not-allowed',
              opacity: selectedPos ? 1 : 0.55
            }}
          >
            Confirm Location
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── ShopRegister ──────────────────────────────────────────────
export default function ShopRegister() {
  const navigate = useNavigate()
  const [form, setForm] = useState({
    shopName: '', shopAddress: '', pincode: '', about: '',
    location: '', phone: '', timing: '',
    lat: null, lng: null,
  })
  const [locating, setLocating] = useState(false)
  const [showMap, setShowMap] = useState(false)
  const [error, setError] = useState('')

  const handleChange = (k, v) => setForm(prev => ({ ...prev, [k]: v }))

  // Opens the map modal (same button, same UI — just opens map now)
  const handleUseLocation = () => {
    setError('')
    setShowMap(true)
  }

  // Called when user confirms a position on the map
  const handleMapConfirm = async ({ lat, lng }) => {
    setShowMap(false)
    setLocating(true)
    setError('')
    try {
      const data = await api.geo.reverse(lat, lng)
      setForm(prev => ({
        ...prev,
        lat,
        lng,
        shopAddress: data.address || prev.shopAddress,
        pincode: data.pincode || prev.pincode,
      }))
    } catch {
      setForm(prev => ({ ...prev, lat, lng }))
      setError('Could not look up address — coordinates saved. Fill address manually if needed.')
    } finally {
      setLocating(false)
    }
  }

  const handleContinue = () => {
    if (!form.shopName || !form.shopAddress || !form.pincode || !form.location || !form.phone || !form.timing) {
      setError('Please fill all required fields')
      return
    }
    sessionStorage.setItem('shop_basic', JSON.stringify(form))
    navigate('/shop/onboard/photos')
  }

  return (
    <>
      {showMap && (
        <MapPickerModal
          onConfirm={handleMapConfirm}
          onClose={() => setShowMap(false)}
        />
      )}

      <div className="auth-layout">
        {/* Left */}
        <div className="auth-left">
          <img
            src="/assets/images/shop_register.png"
            alt="Register your shop"
            style={{ width: 480, height: 480, borderRadius: 12, marginBottom: 52 }}
          />
          <h2 style={{ fontWeight: 700, fontSize: 22, textAlign: 'center', marginBottom: 12 }}>
            Unlock New Horizons for Your Shop
          </h2>
          <p style={{ color: '#666', fontSize: 14, textAlign: 'center', maxWidth: 380, lineHeight: 1.7 }}>
            Partner with Claimit to expand your market reach and transform casual shoppers into dedicated brand advocates for your business.
          </p>
        </div>

        {/* Right */}
        <div className="auth-right">
          <div style={{
            width: '100%', maxWidth: 440, background: '#fff',
            borderRadius: 16, padding: 40, border: '1px solid #e8ecf0',
            boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
          }}>
            <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 6 }}>Shop Registration</h2>
            <p style={{ color: '#888', fontSize: 13, marginBottom: 28 }}>Tell us about your business</p>

            {error && <div style={{ color: '#e53935', fontSize: 13, marginBottom: 12 }}>{error}</div>}

            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Shop Name</label>
              <input className="input-field" placeholder="your shop name"
                value={form.shopName} onChange={e => handleChange('shopName', e.target.value)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Shop Address</label>
              <input className="input-field" placeholder="address of your shop"
                value={form.shopAddress} onChange={e => handleChange('shopAddress', e.target.value)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Pincode</label>
              <input className="input-field" placeholder="Pincode"
                value={form.pincode} onChange={e => handleChange('pincode', e.target.value)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>City / Area <span style={{ color: '#e53935' }}>*</span></label>
              <input className="input-field" placeholder="e.g. Nungambakkam, Chennai"
                value={form.location} onChange={e => handleChange('location', e.target.value)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Phone Number <span style={{ color: '#e53935' }}>*</span></label>
              <input className="input-field" placeholder="+91 99999 99999"
                value={form.phone} onChange={e => handleChange('phone', e.target.value)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Shop Timing <span style={{ color: '#e53935' }}>*</span></label>
              <input className="input-field" placeholder="e.g. Daily: 10am – 10pm"
                value={form.timing} onChange={e => handleChange('timing', e.target.value)} />
            </div>
            <div style={{ marginBottom: 16 }}>
              <button
                onClick={handleUseLocation}
                disabled={locating}
                style={{
                  width: '100%', padding: 13, border: '1.5px solid #ccc',
                  borderRadius: 8, background: '#fff', fontSize: 14, cursor: 'pointer',
                  fontFamily: 'Poppins', color: '#555'
                }}
              >
                {locating ? '📍 Locating…' : '📍 Use my current location'}
              </button>
              {form.lat && form.lng && (
                <div style={{ fontSize: 11, color: '#2e7d32', marginTop: 6 }}>
                  Location captured: {form.lat.toFixed(4)}, {form.lng.toFixed(4)}
                </div>
              )}
            </div>
            <div style={{ marginBottom: 24 }}>
              <label style={labelStyle}>About Shop</label>
              <textarea
                className="input-field"
                placeholder="Short description About shop...."
                value={form.about}
                onChange={e => handleChange('about', e.target.value)}
                rows={3}
                style={{ resize: 'vertical' }}
              />
            </div>
            <button className="btn-primary" onClick={handleContinue}>Continue</button>
          </div>
        </div>
      </div>
    </>
  )
}

const labelStyle = { display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 8 }

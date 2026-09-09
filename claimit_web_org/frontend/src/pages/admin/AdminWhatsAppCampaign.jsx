import { useEffect, useState } from 'react'
import api from '../../utils/api'

/**
 * Admin → WhatsApp Campaign
 *
 * Sends the approved "claim your business" template to a list of shop numbers
 * uploaded as an Excel sheet.
 *
 * The flow is deliberately two-step. Every message costs money and goes to a
 * real shop owner, so nothing is ever sent straight from an upload: the sheet
 * is validated first and the admin sees exactly how many will be messaged,
 * which rows were rejected and why, and the real message text — and only then
 * can press Send.
 */

const BLUE = '#1565C0'

export default function AdminWhatsAppCampaign() {
  const [file, setFile] = useState(null)
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [preview, setPreview] = useState(null)
  const [result, setResult] = useState(null)
  const [log, setLog] = useState(null)

  useEffect(() => { refreshLog() }, [])

  const refreshLog = async () => {
    try { setLog(await api.admin.campaignLog()) } catch { /* not critical */ }
  }

  // ── Step 1: upload + validate (sends nothing) ─────────────────────────────
  const validate = async () => {
    setError(''); setPreview(null); setResult(null)
    if (!file) { setError('Choose the .xlsx file first.'); return }
    setBusy('Uploading and checking the sheet…')
    try {
      const ct = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      // Straight to S3 — a multipart POST to the API is blocked by CloudFront.
      const presign = await api.admin.presignUpload({
        filename: file.name, content_type: ct, folder: 'campaign-uploads',
      })
      const put = await fetch(presign.upload_url, {
        method: 'PUT', headers: { 'Content-Type': ct }, body: file,
      })
      if (!put.ok) throw new Error(`Upload failed (${put.status})`)
      setPreview(await api.admin.campaignPreview(presign.key))
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Could not read that file.')
    } finally {
      setBusy('')
    }
  }

  // ── Step 2: send for real ─────────────────────────────────────────────────
  const send = async () => {
    if (!preview?.recipients?.length) return
    const n = preview.will_send
    if (!window.confirm(
      `Send the WhatsApp message to ${n} shop${n === 1 ? '' : 's'}?\n\n` +
      `This costs ${n} WhatsApp message${n === 1 ? '' : 's'} and cannot be undone.`
    )) return

    setBusy(`Sending to ${n} shops… this takes a few minutes, keep this tab open.`)
    setError('')
    try {
      setResult(await api.admin.campaignSend(preview.recipients))
      await refreshLog()
    } catch (e) {
      setError(e?.response?.data?.detail || e?.message || 'Send failed.')
    } finally {
      setBusy('')
    }
  }

  const card = {
    background: '#fff', border: '1px solid #e5e7eb', borderRadius: 12,
    padding: 20, marginBottom: 18,
  }
  const stat = (label, value, color = '#111827') => (
    <div style={{ textAlign: 'center', padding: '4px 14px' }}>
      <div style={{ fontSize: 26, fontWeight: 700, color }}>{value}</div>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
    </div>
  )

  return (
    <div style={{ maxWidth: 960 }}>
      <h2 style={{ color: BLUE, marginBottom: 4 }}>WhatsApp Campaign</h2>
      <p style={{ color: '#6b7280', fontSize: 14, marginTop: 0 }}>
        Invite bulk-uploaded shops to claim their business.
      </p>

      {/* ── Progress so far ─────────────────────────────────────────────── */}
      {log && (
        <div style={{ ...card, display: 'flex', alignItems: 'center', gap: 10 }}>
          {stat('already messaged', log.sent ?? 0, '#16a34a')}
          {stat('failed', log.failed ?? 0, log.failed ? '#dc2626' : '#111827')}
          <div style={{ fontSize: 13, color: '#6b7280', marginLeft: 12 }}>
            Anyone already messaged is skipped automatically, so you can
            re-upload the same sheet safely.
          </div>
        </div>
      )}

      {/* ── Step 1 ──────────────────────────────────────────────────────── */}
      <div style={card}>
        <h3 style={{ marginTop: 0 }}>1. Upload the sheet</h3>
        <p style={{ fontSize: 13, color: '#374151', marginTop: 0 }}>
          Columns: <b>phone</b> (required) and <b>shop_name</b> (optional —
          blank shows “your shop in your area”). <b>city</b> and <b>pincode</b>{' '}
          are ignored, they are only there so you can filter the sheet.
        </p>
        <input
          type="file"
          accept=".xlsx"
          onChange={e => { setFile(e.target.files?.[0] || null); setPreview(null); setResult(null) }}
        />
        <button
          onClick={validate}
          disabled={!!busy || !file}
          style={{
            marginLeft: 12, padding: '9px 18px', border: 'none', borderRadius: 8,
            background: busy || !file ? '#9ca3af' : BLUE, color: '#fff',
            fontWeight: 600, cursor: busy || !file ? 'not-allowed' : 'pointer',
          }}
        >
          Check sheet
        </button>
      </div>

      {busy && (
        <div style={{ ...card, background: '#EFF6FF', borderColor: '#BFDBFE',
                      color: BLUE, fontWeight: 600 }}>
          {busy}
        </div>
      )}
      {error && (
        <div style={{ ...card, background: '#FEF2F2', borderColor: '#FECACA',
                      color: '#b91c1c' }}>
          {error}
        </div>
      )}

      {/* ── Step 2 ──────────────────────────────────────────────────────── */}
      {preview && (
        <div style={card}>
          <h3 style={{ marginTop: 0 }}>2. Check, then send</h3>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6,
                        borderBottom: '1px solid #e5e7eb', paddingBottom: 12 }}>
            {stat('rows read', preview.rows_read)}
            {stat('valid', preview.valid, '#16a34a')}
            {stat('rejected', preview.rejected?.length ?? 0,
                  preview.rejected?.length ? '#dc2626' : '#111827')}
            {stat('already sent', preview.already_sent, '#6b7280')}
            {stat('WILL SEND', preview.will_send, BLUE)}
          </div>

          {!preview.template_configured && (
            <p style={{ color: '#b91c1c', fontSize: 13 }}>
              TWILIO_CLAIM_TEMPLATE_SID is not set on the server — sending is
              disabled until it is.
            </p>
          )}

          {/* Rejected rows: every one, with the reason. These are the rows the
              admin has to fix, so they are never truncated. */}
          {preview.rejected?.length > 0 && (
            <details style={{ marginTop: 14 }}>
              <summary style={{ cursor: 'pointer', color: '#b91c1c', fontWeight: 600 }}>
                {preview.rejected.length} row(s) will NOT be sent — see why
              </summary>
              <div style={{ maxHeight: 260, overflow: 'auto', marginTop: 10 }}>
                <table style={{ width: '100%', fontSize: 13, borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ background: '#f9fafb', textAlign: 'left' }}>
                      <th style={{ padding: 6 }}>Row</th>
                      <th style={{ padding: 6 }}>Phone</th>
                      <th style={{ padding: 6 }}>Shop</th>
                      <th style={{ padding: 6 }}>Reason</th>
                    </tr>
                  </thead>
                  <tbody>
                    {preview.rejected.map((r, i) => (
                      <tr key={i} style={{ borderTop: '1px solid #f3f4f6' }}>
                        <td style={{ padding: 6 }}>{r.row}</td>
                        <td style={{ padding: 6 }}>{r.phone || '—'}</td>
                        <td style={{ padding: 6 }}>{r.shop_name || '—'}</td>
                        <td style={{ padding: 6, color: '#b91c1c' }}>{r.reason}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </details>
          )}

          {preview.recipients?.length > 0 && (
            <details style={{ marginTop: 10 }}>
              <summary style={{ cursor: 'pointer', color: BLUE, fontWeight: 600 }}>
                Preview the first few messages
              </summary>
              <div style={{ marginTop: 10 }}>
                {preview.recipients.slice(0, 5).map((r, i) => (
                  <div key={i} style={{
                    background: '#F0FDF4', border: '1px solid #BBF7D0',
                    borderRadius: 10, padding: 12, marginBottom: 8, fontSize: 13,
                  }}>
                    <b>+91 {r.phone}</b>
                    <div style={{ marginTop: 6, color: '#374151' }}>
                      “Your shop <b>{r.shop_name || 'in your area'}</b> is
                      already listed on CLAIMIT…”
                    </div>
                  </div>
                ))}
              </div>
            </details>
          )}

          <button
            onClick={send}
            disabled={!!busy || !preview.will_send || !preview.template_configured}
            style={{
              marginTop: 16, padding: '11px 22px', border: 'none', borderRadius: 8,
              background: (!preview.will_send || busy || !preview.template_configured)
                ? '#9ca3af' : '#16a34a',
              color: '#fff', fontWeight: 700, fontSize: 15,
              cursor: (!preview.will_send || busy) ? 'not-allowed' : 'pointer',
            }}
          >
            Send to {preview.will_send} shop{preview.will_send === 1 ? '' : 's'}
          </button>
        </div>
      )}

      {/* ── Result ──────────────────────────────────────────────────────── */}
      {result && (
        <div style={{ ...card, borderColor: '#BBF7D0', background: '#F0FDF4' }}>
          <h3 style={{ marginTop: 0, color: '#166534' }}>Done</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {stat('sent', result.sent, '#16a34a')}
            {stat('failed', result.failed, result.failed ? '#dc2626' : '#111827')}
            {stat('skipped (already sent)', result.skipped_already_sent, '#6b7280')}
            {stat('skipped (bad number)', result.skipped_invalid_number, '#6b7280')}
          </div>
          {result.failed > 0 && (
            <details style={{ marginTop: 12 }}>
              <summary style={{ cursor: 'pointer', color: '#b91c1c' }}>
                Which ones failed
              </summary>
              <div style={{ maxHeight: 220, overflow: 'auto', marginTop: 8, fontSize: 13 }}>
                {result.results.filter(r => r.status === 'failed').map((r, i) => (
                  <div key={i}>+91 {r.phone}</div>
                ))}
              </div>
            </details>
          )}
        </div>
      )}
    </div>
  )
}

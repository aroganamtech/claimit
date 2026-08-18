// ─────────────────────────────────────────────────────────────────────────
// Admin → Learn Claimit. Add a question + upload its answer video (S3,
// presigned PUT — same pattern as AdminCreateAd/AdminCategoryImages). The
// Flutter app's "Learn Claimit" zone shows the question list, then plays
// the matching video with sound + a like button.
// ─────────────────────────────────────────────────────────────────────────
import { useEffect, useState } from 'react'
import api from '../../utils/api'

const input = { width: '100%', padding: '10px 12px', margin: '4px 0 14px', border: '1px solid #ccc', borderRadius: 8, fontSize: 14, boxSizing: 'border-box', fontFamily: 'inherit' }
const label = { fontSize: 13, fontWeight: 600, color: '#333' }
const th = { textAlign: 'left', padding: '10px 12px', fontSize: 12, fontWeight: 700, color: '#374151', borderBottom: '2px solid #e5e7eb', whiteSpace: 'nowrap' }
const td = { padding: '10px 12px', fontSize: 13, color: '#111827', borderBottom: '1px solid #f1f5f9', verticalAlign: 'top' }
const dangerBtn = { background: '#fff', border: '1px solid #e57373', color: '#c62828', padding: '6px 10px', borderRadius: 6, fontSize: 12, cursor: 'pointer', fontFamily: 'Poppins' }

function PageShell({ title, subtitle, children }) {
  return (
    <div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>{title}</h1>
      {subtitle && <p style={{ color: '#666', fontSize: 13, marginBottom: 22 }}>{subtitle}</p>}
      {children}
    </div>
  )
}

export default function AdminLearnClaimit() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [question, setQuestion] = useState('')
  const [video, setVideo] = useState(null)
  const [busy, setBusy] = useState('')
  const [msg, setMsg] = useState(null) // {ok, text}

  const load = () => {
    setLoading(true)
    api.admin.listLearnItems().then(setItems).catch(() => setItems([])).finally(() => setLoading(false))
  }
  useEffect(() => { load() }, [])

  const uploadToS3 = async (file) => {
    const presign = await api.admin.presignUpload({
      filename: file.name, content_type: file.type, folder: 'learn-claimit',
    })
    const put = await fetch(presign.upload_url, {
      method: 'PUT', headers: { 'Content-Type': file.type }, body: file,
    })
    if (!put.ok) throw new Error(`S3 upload failed: ${put.status}`)
    return presign.key
  }

  const submit = async () => {
    setMsg(null)
    if (!question.trim()) { setMsg({ ok: false, text: 'Please enter the question.' }); return }
    if (!video) { setMsg({ ok: false, text: 'Please attach the answer video.' }); return }
    try {
      setBusy('Uploading video…')
      const videoKey = await uploadToS3(video)
      setBusy('Saving…')
      await api.admin.createLearnItem({ question: question.trim(), video_key: videoKey })
      setMsg({ ok: true, text: '✅ Lesson added — it will appear in the app immediately.' })
      setQuestion('')
      setVideo(null)
      load()
    } catch (e) {
      setMsg({ ok: false, text: e?.response?.data?.detail || e?.message || 'Failed to add lesson.' })
    } finally {
      setBusy('')
    }
  }

  const remove = async (id) => {
    if (!confirm('Delete this lesson?')) return
    await api.admin.deleteLearnItem(id)
    load()
  }

  return (
    <PageShell title="Learn Claimit" subtitle="Add a question and its answer video — shown in the app's Learn Claimit tile.">
      <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 12, padding: 22, marginBottom: 24, maxWidth: 720 }}>
        <div style={label}>Question</div>
        <input style={input} value={question} onChange={(e) => setQuestion(e.target.value)} placeholder="e.g. How do I claim my reward?" />

        <div style={label}>Answer video</div>
        <input style={input} type="file" accept="video/*" onChange={(e) => setVideo(e.target.files?.[0] || null)} />

        <button onClick={submit} disabled={!!busy}
          style={{ padding: '10px 18px', background: busy ? '#8a90c0' : '#1a237e', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: busy ? 'default' : 'pointer' }}>
          {busy || 'Add Lesson'}
        </button>

        {msg && (
          <div style={{ marginTop: 16, padding: '12px 14px', borderRadius: 8, fontSize: 13.5, lineHeight: 1.5,
            background: msg.ok ? '#e7f7ec' : '#fdeaea', color: msg.ok ? '#1b7a3d' : '#b3261e' }}>
            {msg.text}
          </div>
        )}
      </div>

      {loading ? (
        <div style={{ color: '#6b7280' }}>Loading…</div>
      ) : items.length === 0 ? (
        <div style={{ padding: 40, textAlign: 'center', color: '#999', background: '#fff', borderRadius: 12, border: '1px solid #eee' }}>
          No lessons yet — add one above.
        </div>
      ) : (
        <div style={{ overflowX: 'auto', background: '#fff', borderRadius: 12, border: '1px solid #eee' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th style={th}>Question</th>
                <th style={th}>Video</th>
                <th style={th}>Likes</th>
                <th style={th}></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it) => (
                <tr key={it.id}>
                  <td style={td}>{it.question}</td>
                  <td style={td}>
                    {it.video_url
                      ? <a href={it.video_url} target="_blank" rel="noreferrer">Preview</a>
                      : <span style={{ color: '#999' }}>—</span>}
                  </td>
                  <td style={td}>{it.like_count || 0}</td>
                  <td style={td}><button style={dangerBtn} onClick={() => remove(it.id)}>Delete</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </PageShell>
  )
}

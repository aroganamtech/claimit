import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import api from '../utils/api'
import AdvertiserSidebar from './advertiser/AdvertiserSidebar'
import SalesSidebar from './sales/SalesSidebar'
import ShopSidebar from './shop/ShopSidebar'

// Pick the right sidebar so the page sits inside the user's portal layout.
function SidebarFor({ role }) {
  if (role === 'sales') return <SalesSidebar />
  if (role === 'shop') return <ShopSidebar />
  return <AdvertiserSidebar />
}

export default function HelpSupport() {
  const { role } = useAuth()
  const [faqs, setFaqs] = useState([])
  const [tickets, setTickets] = useState([])
  const [openIdx, setOpenIdx] = useState(null)
  const [form, setForm] = useState({ subject: '', message: '', category: 'general' })
  const [loading, setLoading] = useState(false)
  const [posted, setPosted] = useState(false)
  const [error, setError] = useState('')

  const fetchAll = () => {
    api.support.getFaqs().then(setFaqs).catch(() => setFaqs([]))
    api.support.getMyTickets().then(setTickets).catch(() => setTickets([]))
  }

  useEffect(() => { fetchAll() }, [])

  const submitTicket = async () => {
    if (!form.subject || !form.message) { setError('Please fill subject and message'); return }
    setError(''); setLoading(true); setPosted(false)
    try {
      await api.support.submitTicket(form)
      setForm({ subject: '', message: '', category: 'general' })
      setPosted(true)
      fetchAll()
      setTimeout(() => setPosted(false), 2500)
    } catch (e) {
      setError(e.response?.data?.detail || 'Could not submit ticket')
    } finally { setLoading(false) }
  }

  return (
    <div style={{ paddingTop: 64 }}>
      <SidebarFor role={role} />
      <main className="main-content">
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Help &amp; Support</h1>
        <p style={{ color: '#888', fontSize: 14, marginBottom: 28 }}>
          Find answers to common questions or open a ticket — we reply within 24 hours.
        </p>

        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 24, alignItems: 'flex-start' }}>
          {/* FAQs */}
          <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24 }}>
            <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Frequently Asked Questions</h3>
            {faqs.length === 0 ? (
              <div style={{ padding: 40, textAlign: 'center', color: '#bbb' }}>
                <div style={{ fontSize: 36, marginBottom: 8 }}>📚</div>
                <div style={{ fontSize: 14 }}>No FAQs available yet.</div>
              </div>
            ) : faqs.map((f, i) => (
              <div key={i} style={{ borderBottom: '1px solid #f5f5f5', padding: '14px 0' }}>
                <div
                  onClick={() => setOpenIdx(openIdx === i ? null : i)}
                  style={{ display: 'flex', justifyContent: 'space-between', cursor: 'pointer', fontWeight: 600, fontSize: 14 }}
                >
                  <span>{f.q}</span>
                  <span style={{ color: '#1565C0' }}>{openIdx === i ? '−' : '+'}</span>
                </div>
                {openIdx === i && (
                  <div style={{ color: '#555', fontSize: 13, marginTop: 8, lineHeight: 1.6 }}>
                    {f.a}
                  </div>
                )}
              </div>
            ))}
          </div>

          {/* Ticket form + history */}
          <div>
            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 24, marginBottom: 20 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 16 }}>Contact Support</h3>
              {posted && (
                <div style={{ background: '#e8f5e9', color: '#2e7d32', borderRadius: 8, padding: '8px 12px', fontSize: 13, marginBottom: 12 }}>
                  Ticket submitted — we&apos;ll get back to you soon.
                </div>
              )}
              {error && (
                <div style={{ background: '#ffebee', color: '#c62828', borderRadius: 8, padding: '8px 12px', fontSize: 13, marginBottom: 12 }}>
                  {error}
                </div>
              )}
              <div style={{ marginBottom: 12 }}>
                <label style={lbl}>Category</label>
                <select className="input-field" value={form.category}
                  onChange={e => setForm(f => ({ ...f, category: e.target.value }))}>
                  <option value="general">General</option>
                  <option value="billing">Billing</option>
                  <option value="technical">Technical</option>
                  <option value="account">Account</option>
                </select>
              </div>
              <div style={{ marginBottom: 12 }}>
                <label style={lbl}>Subject</label>
                <input className="input-field" placeholder="Short summary"
                  value={form.subject} onChange={e => setForm(f => ({ ...f, subject: e.target.value }))} />
              </div>
              <div style={{ marginBottom: 16 }}>
                <label style={lbl}>Message</label>
                <textarea className="input-field" placeholder="Describe your issue..." rows={4}
                  style={{ resize: 'vertical' }}
                  value={form.message} onChange={e => setForm(f => ({ ...f, message: e.target.value }))} />
              </div>
              <button className="btn-primary" onClick={submitTicket} disabled={loading}>
                {loading ? 'Submitting...' : 'Submit Ticket'}
              </button>
            </div>

            <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #eee', padding: 20 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 14, fontSize: 15 }}>Your Tickets</h3>
              {tickets.length === 0 ? (
                <div style={{ color: '#bbb', fontSize: 13, textAlign: 'center', padding: '20px 0' }}>
                  You haven&apos;t opened any tickets yet.
                </div>
              ) : tickets.map(t => (
                <div key={t.id} style={{ borderBottom: '1px solid #f5f5f5', padding: '10px 0' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ fontWeight: 600, fontSize: 13 }}>{t.subject}</span>
                    <span className={t.status === 'open' ? 'badge-scheduled' : 'badge-active'} style={{ fontSize: 11 }}>
                      {t.status}
                    </span>
                  </div>
                  <div style={{ fontSize: 12, color: '#888' }}>{t.category} · {String(t.created_at).slice(0, 16)}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

const lbl = { display: 'block', fontSize: 13, fontWeight: 600, color: '#444', marginBottom: 6 }

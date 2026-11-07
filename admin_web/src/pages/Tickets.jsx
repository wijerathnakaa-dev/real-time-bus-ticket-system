import { useEffect, useState } from 'react';
import { api, fmtTime, money } from '../api.js';

export function summarize(tickets) {
  const paid = tickets.filter((t) => t.payment_status === 'paid');
  return {
    count: tickets.length,
    revenue: paid.reduce((s, t) => s + Number(t.fare), 0),
    inApp: tickets.filter((t) => t.issued_by_role === 'passenger').length,
    cash: tickets.filter((t) => t.payment_method === 'cash').length,
  };
}

export default function Tickets() {
  const [tickets, setTickets] = useState([]);
  const [buses, setBuses] = useState([]);
  const [f, setF] = useState({ bus_id: '', status: '', payment_status: '', from: '', to: '', q: '' });
  const [error, setError] = useState('');

  useEffect(() => {
    api('/buses', { query: { all: 1 } }).then(setBuses).catch(() => {});
  }, []);

  useEffect(() => {
    const t = setTimeout(() => api('/tickets', { query: f }).then(setTickets).catch((e) => setError(e.message)), 250);
    return () => clearTimeout(t);
  }, [f]);

  const cancel = async (t) => {
    if (!confirm(`Cancel ${t.ticket_number} and free seat ${t.seat_number}?`)) return;
    try {
      await api(`/tickets/${t.id}/cancel`, { method: 'POST' });
      setF({ ...f });
    } catch (e) {
      setError(e.message);
    }
  };

  const s = summarize(tickets);
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  return (
    <>
      <header className="page-head"><h1>Tickets</h1></header>
      {error && <div className="alert">{error}</div>}
      <div className="row-form card">
        <input placeholder="Search ticket no. or name" value={f.q} onChange={set('q')} />
        <select value={f.bus_id} onChange={set('bus_id')} aria-label="Bus">
          <option value="">All buses</option>
          {buses.map((b) => <option key={b.id} value={b.id}>{b.plate_number}</option>)}
        </select>
        <select value={f.status} onChange={set('status')} aria-label="Status">
          <option value="">Any status</option>
          <option value="active">Active</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
        </select>
        <select value={f.payment_status} onChange={set('payment_status')} aria-label="Payment">
          <option value="">Any payment</option>
          <option value="paid">Paid</option>
          <option value="pending">Pending</option>
          <option value="refunded">Refunded</option>
          <option value="failed">Failed</option>
        </select>
        <label className="inline">From<input type="date" value={f.from} onChange={set('from')} /></label>
        <label className="inline">To<input type="date" value={f.to} onChange={set('to')} /></label>
      </div>
      <p className="muted">{s.count} tickets · {money(s.revenue)} collected · {s.inApp} in-app · {s.cash} cash</p>
      <section className="card">
        <table>
          <thead><tr><th>Ticket</th><th>Issued</th><th>Bus / seat</th><th>Passenger</th><th>Journey</th><th>Fare</th><th>Payment</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {tickets.map((t) => (
              <tr key={t.id}>
                <td className="mono small">{t.ticket_number}</td>
                <td className="small">{fmtTime(t.issued_at)}</td>
                <td>{t.bus_plate_number} · {t.seat_number}</td>
                <td>{t.passenger_name}<div className="muted small">{t.issued_by_role === 'passenger' ? 'in-app' : 'conductor'}</div></td>
                <td className="small">{t.from_stop_name || '-'} → {t.to_stop_name || '-'}</td>
                <td>{money(t.fare)}</td>
                <td><span className={`pill ${t.payment_status === 'paid' ? 'ok' : t.payment_status === 'pending' ? 'warn' : ''}`}>{t.payment_method} · {t.payment_status}</span></td>
                <td>{t.status}</td>
                <td>{t.status === 'active' && <button className="btn small danger" onClick={() => cancel(t)}>Cancel</button>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}

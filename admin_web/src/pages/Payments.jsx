import { useEffect, useState } from 'react';
import { api, fmtTime, money } from '../api.js';

export default function Payments() {
  const [rows, setRows] = useState([]);
  const [mode, setMode] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    api('/admin/payments').then(setRows).catch((e) => setError(e.message));
    api('/payments/config').then((c) => setMode(c.mode)).catch(() => {});
  }, []);

  const total = rows.filter((r) => r.status === 'success').reduce((s, r) => s + Number(r.amount), 0);

  return (
    <>
      <header className="page-head">
        <h1>Payments</h1>
        {mode && <span className={`pill ${mode === 'live' ? 'ok' : 'warn'}`}>PayHere: {mode}</span>}
      </header>
      {mode === 'simulated' && (
        <div className="notice">PayHere merchant keys are not set on the server, so in-app payments run in simulated demo mode. Set PAYHERE_MERCHANT_ID and PAYHERE_MERCHANT_SECRET in backend/.env for the PayHere sandbox.</div>
      )}
      {error && <div className="alert">{error}</div>}
      <p className="muted">{rows.length} payments · {money(total)} successful</p>
      <section className="card">
        <table>
          <thead><tr><th>Time</th><th>Ticket</th><th>Passenger</th><th>Provider</th><th>Reference</th><th>Amount</th><th>Status</th></tr></thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td className="small">{fmtTime(r.created_at)}</td>
                <td className="mono small">{r.ticket_number}</td>
                <td>{r.passenger_name}</td>
                <td>{r.provider}</td>
                <td className="mono small">{r.provider_ref || '-'}</td>
                <td>{money(r.amount)}</td>
                <td><span className={`pill ${r.status === 'success' ? 'ok' : 'warn'}`}>{r.status}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}

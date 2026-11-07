import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { Occupancy } from './Overview.jsx';

export default function Buses() {
  const [buses, setBuses] = useState([]);
  const [routes, setRoutes] = useState([]);
  const [conductors, setConductors] = useState([]);
  const [error, setError] = useState('');
  const [msg, setMsg] = useState('');
  const [filter, setFilter] = useState('all');
  const [form, setForm] = useState({ plate_number: '', total_seats: 40, route_id: '' });

  const load = async () => {
    try {
      const [b, r, c] = await Promise.all([api('/buses', { query: { all: 1 } }), api('/routes'), api('/admin/users', { query: { role: 'conductor' } })]);
      setBuses(b);
      setRoutes(r);
      setConductors(c);
    } catch (e) {
      setError(e.message);
    }
  };
  useEffect(() => {
    load();
  }, []);

  const act = async (fn, ok) => {
    setError('');
    try {
      await fn();
      setMsg(ok);
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const approve = (b, approved) => act(() => api(`/buses/${b.id}/approve`, { method: 'POST', body: { approved } }), `${b.plate_number} ${approved ? 'approved' : 'suspended'}`);
  const assign = (b, body) => act(() => api(`/buses/${b.id}/assign`, { method: 'POST', body }), `${b.plate_number} updated`);
  const register = (e) => {
    e.preventDefault();
    act(
      () => api('/buses', { method: 'POST', body: { ...form, total_seats: Number(form.total_seats), route_id: form.route_id || undefined } }),
      `${form.plate_number} registered`,
    ).then(() => setForm({ plate_number: '', total_seats: 40, route_id: '' }));
  };

  const shown = buses.filter((b) => filter === 'all' || (filter === 'pending' ? !b.approved : b.status === filter));

  return (
    <>
      <header className="page-head">
        <h1>Buses</h1>
        <select value={filter} onChange={(e) => setFilter(e.target.value)} aria-label="Filter buses">
          <option value="all">All buses</option>
          <option value="pending">Awaiting approval</option>
          <option value="on_trip">On trip</option>
          <option value="idle">Idle</option>
        </select>
      </header>
      {error && <div className="alert">{error}</div>}
      {msg && <div className="notice">{msg}</div>}
      <section className="card">
        <table>
          <thead>
            <tr><th>Bus</th><th>Status</th><th>Route</th><th>Conductor</th><th>Seats free</th><th>Approval</th></tr>
          </thead>
          <tbody>
            {shown.map((b) => (
              <tr key={b.id}>
                <td>
                  <div className="bus-cell">
                    {b.photo_url ? <img src={b.photo_url} alt="" /> : <div className="ph" aria-hidden>🚌</div>}
                    <Link to={`/buses/${b.id}`} className="plate">{b.plate_number}</Link>
                  </div>
                </td>
                <td><span className={`pill ${b.status === 'on_trip' ? 'ok' : ''}`}>{b.status.replace('_', ' ')}</span></td>
                <td>
                  <select value={b.route_id || ''} onChange={(e) => assign(b, { route_id: e.target.value })} aria-label={`Route for ${b.plate_number}`}>
                    <option value="" disabled>Choose route</option>
                    {routes.map((r) => <option key={r.id} value={r.id}>{r.route_number} {r.origin} - {r.destination}</option>)}
                  </select>
                </td>
                <td>
                  <select value={b.conductor_id || ''} onChange={(e) => assign(b, { conductor_id: e.target.value })} aria-label={`Conductor for ${b.plate_number}`}>
                    <option value="" disabled>Assign conductor</option>
                    {conductors.map((c) => <option key={c.id} value={c.id}>{c.name}{c.assigned_bus_plate && c.assigned_bus_id !== b.id ? ` (on ${c.assigned_bus_plate})` : ''}</option>)}
                  </select>
                </td>
                <td><Occupancy free={b.available_seats} total={b.total_seats} /></td>
                <td>
                  {b.approved ? (
                    <button className="btn small" onClick={() => approve(b, false)}>Suspend</button>
                  ) : (
                    <button className="btn small primary" onClick={() => approve(b, true)}>Approve</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
      <section className="card">
        <h2>Register a bus</h2>
        <form className="row-form" onSubmit={register}>
          <input placeholder="Number plate (e.g. NB-2451)" value={form.plate_number} onChange={(e) => setForm({ ...form, plate_number: e.target.value })} required />
          <input type="number" min="1" max="80" value={form.total_seats} onChange={(e) => setForm({ ...form, total_seats: e.target.value })} aria-label="Seats" />
          <select value={form.route_id} onChange={(e) => setForm({ ...form, route_id: e.target.value })} aria-label="Route">
            <option value="">No route yet</option>
            {routes.map((r) => <option key={r.id} value={r.id}>{r.route_number} {r.origin} - {r.destination}</option>)}
          </select>
          <button className="btn primary">Register</button>
        </form>
      </section>
    </>
  );
}

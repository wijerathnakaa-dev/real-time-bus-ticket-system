import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, fmtTime, liveEvents, money } from '../api.js';

/** One bus: live seat map with admin override, per-stop ETA, arrival/departure history, trip tickets. */
export default function BusDetail() {
  const { id } = useParams();
  const [bus, setBus] = useState(null);
  const [seats, setSeats] = useState([]);
  const [eta, setEta] = useState(null);
  const [events, setEvents] = useState([]);
  const [tickets, setTickets] = useState([]);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const [b, s, e, ev, t] = await Promise.all([
        api(`/buses/${id}`),
        api(`/buses/${id}/seats`),
        api(`/buses/${id}/eta`),
        api(`/buses/${id}/stop-events`),
        api('/tickets', { query: { bus_id: id, status: 'active' } }),
      ]);
      setBus(b);
      setSeats(s);
      setEta(e);
      setEvents(ev);
      setTickets(t);
    } catch (err) {
      setError(err.message);
    }
  }, [id]);

  useEffect(() => {
    load();
    return liveEvents((e) => {
      if (e.bus_id && e.bus_id !== id) return;
      if (e.type === 'seat_booked' || e.type === 'seat_released') {
        setSeats((ss) => ss.map((s) => (s.seat_number === String(e.seat_number) ? { ...s, status: e.status } : s)));
      }
      if (e.type === 'bus_location' && e.stops) setEta((x) => ({ ...x, ...e, stops: e.stops }));
      if (e.type !== 'bus_location' && e.type !== 'disconnected') load();
    });
  }, [id, load]);

  const override = async (s) => {
    const to = s.status === 'available' ? 'taken' : 'available';
    if (!confirm(`Mark seat ${s.seat_number} as ${to}?${s.ticket_id && to === 'available' ? ' Its ticket will be completed.' : ''}`)) return;
    try {
      await api('/seats/override', { method: 'POST', body: { bus_id: id, seat_number: s.seat_number, status: to } });
    } catch (e) {
      setError(e.message);
    }
  };

  if (!bus) return <div className="muted">{error || 'Loading…'}</div>;
  const free = seats.filter((s) => s.status === 'available').length;

  return (
    <>
      <header className="page-head">
        <h1><Link to="/buses" className="plain muted">Buses /</Link> {bus.plate_number}</h1>
        <span className={`pill ${bus.status === 'on_trip' ? 'ok' : ''}`}>{bus.status.replace('_', ' ')}</span>
      </header>
      {error && <div className="alert">{error}</div>}
      <p className="muted">
        Route {bus.route_number || '-'} {bus.route_name} · Conductor: {bus.conductor_name || 'unassigned'} · {bus.approved ? 'Approved' : 'Awaiting approval'}
      </p>
      <div className="grid-2">
        <section className="card">
          <h2>Seats - {free} of {seats.length} free</h2>
          <p className="muted small">Click a seat to correct its status.</p>
          <div className="seat-grid">
            {seats.map((s, i) => (
              <button
                key={s.seat_number}
                className={`seat ${s.status}`}
                style={{ marginRight: i % 4 === 1 ? 24 : 0 }}
                onClick={() => override(s)}
                title={s.ticket_id ? `Ticket ${s.ticket_id}` : s.status}
              >
                {s.seat_number}
              </button>
            ))}
          </div>
        </section>
        <section className="card">
          <h2>Stops & ETA</h2>
          <ol className="stops">
            {(eta?.stops || []).map((s) => (
              <li key={s.stop_id} className={`${s.state} ${s.stop_id === eta.next_stop_id ? 'next' : ''}`}>
                <strong>{s.stop_name}</strong>
                <span className="muted small">
                  {s.actual_departure
                    ? `departed ${new Date(s.actual_departure).toLocaleTimeString()}`
                    : s.actual_arrival
                      ? `arrived ${new Date(s.actual_arrival).toLocaleTimeString()}`
                      : s.eta_minutes != null
                        ? `ETA ${Math.round(s.eta_minutes)} min · ${s.distance_km} km`
                        : s.state}
                </span>
              </li>
            ))}
          </ol>
        </section>
      </div>
      <div className="grid-2">
        <section className="card">
          <h2>Active tickets ({tickets.length})</h2>
          <table>
            <thead><tr><th>Seat</th><th>Passenger</th><th>Journey</th><th>Fare</th><th>Paid</th></tr></thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={t.id}>
                  <td>{t.seat_number}</td>
                  <td>{t.passenger_name}<div className="muted small">{t.ticket_number}</div></td>
                  <td className="small">{t.from_stop_name || '-'} → {t.to_stop_name || '-'}</td>
                  <td>{money(t.fare)}</td>
                  <td><span className={`pill ${t.payment_status === 'paid' ? 'ok' : 'warn'}`}>{t.payment_method} · {t.payment_status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <section className="card">
          <h2>Arrival / departure history</h2>
          <table>
            <thead><tr><th>Time</th><th>Stop</th><th>Event</th><th>By</th></tr></thead>
            <tbody>
              {events.map((e) => (
                <tr key={e.id}>
                  <td className="small">{fmtTime(e.occurred_at)}</td>
                  <td>{e.stop_name}</td>
                  <td>{e.event_type}</td>
                  <td className="small">{e.automatic ? 'GPS (auto)' : e.confirmed_by_name}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </div>
    </>
  );
}

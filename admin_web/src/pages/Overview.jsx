import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, describeEvent, liveEvents, money } from '../api.js';
import LiveMap from '../components/LiveMap.jsx';

export default function Overview() {
  const [stats, setStats] = useState(null);
  const [buses, setBuses] = useState([]);
  const [routes, setRoutes] = useState([]);
  const [feed, setFeed] = useState([]);
  const [online, setOnline] = useState(false);
  const [error, setError] = useState('');
  const plates = useRef({});
  const reloadTimer = useRef();

  const load = useCallback(async () => {
    try {
      const [s, b, rs] = await Promise.all([api('/admin/stats'), api('/buses', { query: { all: 1 } }), api('/routes')]);
      const full = await Promise.all(rs.map((r) => api(`/routes/${r.id}`)));
      plates.current = Object.fromEntries(b.map((x) => [x.id, x.plate_number]));
      setStats(s);
      setBuses(b);
      setRoutes(full);
      setError('');
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    load();
    return liveEvents((e) => {
      if (e.type === 'resync') return setOnline(true), load();
      if (e.type === 'disconnected') return setOnline(false);
      if (e.type === 'bus_location') {
        setBuses((bs) => bs.map((b) => (b.id === e.bus_id ? { ...b, latitude: e.latitude, longitude: e.longitude, speed_kmh: e.speed_kmh } : b)));
        return;
      }
      const text = describeEvent(e, plates.current);
      if (text) setFeed((f) => [{ text, at: new Date(), key: Math.random() }, ...f].slice(0, 40));
      clearTimeout(reloadTimer.current);
      reloadTimer.current = setTimeout(load, 500);
    });
  }, [load]);

  const onTrip = buses.filter((b) => b.status === 'on_trip');

  return (
    <>
      <header className="page-head">
        <h1>Overview</h1>
        <span className={`pill ${online ? 'ok' : 'warn'}`}>{online ? 'Live' : 'Reconnecting…'}</span>
      </header>
      {error && <div className="alert">{error}</div>}
      {stats && (
        <div className="stats">
          <Stat label="Buses on trip" value={`${stats.buses_on_trip} / ${stats.buses}`} />
          <Stat label="Awaiting approval" value={stats.buses_pending_approval} link="/buses" warn={stats.buses_pending_approval > 0} />
          <Stat label="Seats taken now" value={`${stats.seats_taken} / ${stats.seats_total}`} />
          <Stat label="Tickets today" value={stats.tickets_today} />
          <Stat label="Revenue today" value={money(stats.revenue_today)} />
          <Stat label="Routes" value={stats.routes} />
        </div>
      )}
      <div className="grid-2">
        <section className="card">
          <h2>Live map</h2>
          <LiveMap buses={buses} routes={routes} />
        </section>
        <section className="card">
          <h2>Live activity</h2>
          {feed.length === 0 ? (
            <p className="muted">Seat bookings, payments, trips and stop events appear here as they happen.</p>
          ) : (
            <ul className="feed">
              {feed.map((f) => (
                <li key={f.key}>
                  <span className="muted small">{f.at.toLocaleTimeString()}</span> {f.text}
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
      <section className="card">
        <h2>Buses on trip</h2>
        {onTrip.length === 0 ? (
          <p className="muted">No buses are on a trip right now.</p>
        ) : (
          <table>
            <thead>
              <tr><th>Bus</th><th>Route</th><th>Conductor</th><th>Seats free</th><th>Speed</th></tr>
            </thead>
            <tbody>
              {onTrip.map((b) => (
                <tr key={b.id}>
                  <td><Link to={`/buses/${b.id}`}>{b.plate_number}</Link></td>
                  <td>{b.route_number} {b.route_name}</td>
                  <td>{b.conductor_name || '-'}</td>
                  <td><Occupancy free={b.available_seats} total={b.total_seats} /></td>
                  <td>{b.speed_kmh != null ? `${Math.round(b.speed_kmh)} km/h` : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  );
}

function Stat({ label, value, link, warn }) {
  const body = (
    <div className={`stat ${warn ? 'warn' : ''}`}>
      <div className="stat-value">{value}</div>
      <div className="muted small">{label}</div>
    </div>
  );
  return link ? <Link to={link} className="plain">{body}</Link> : body;
}

export function Occupancy({ free, total }) {
  const pct = total ? ((total - free) / total) * 100 : 0;
  return (
    <div className="occ" title={`${total - free} of ${total} taken`}>
      <div className="occ-bar"><div style={{ width: `${pct}%` }} /></div>
      <span>{free}/{total}</span>
    </div>
  );
}

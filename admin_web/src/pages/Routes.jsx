import { useEffect, useState } from 'react';
import { api, money } from '../api.js';

const blank = { route_number: '', origin: '', destination: '', standard_fare: 500, estimated_duration_mins: 60, stops: [] };

export default function RoutesPage() {
  const [routes, setRoutes] = useState([]);
  const [edit, setEdit] = useState(null); // route being edited (with stops) or blank for new
  const [error, setError] = useState('');

  const load = () => api('/routes').then(setRoutes).catch((e) => setError(e.message));
  useEffect(() => {
    load();
  }, []);

  const open = async (r) => setEdit(r ? await api(`/routes/${r.id}`) : { ...blank, stops: [{ stop_name: '', latitude: '', longitude: '' }] });

  const save = async (e) => {
    e.preventDefault();
    setError('');
    const body = {
      ...edit,
      standard_fare: Number(edit.standard_fare),
      estimated_duration_mins: Number(edit.estimated_duration_mins),
      stops: edit.stops.filter((s) => s.stop_name.trim()).map((s) => ({ stop_name: s.stop_name.trim(), latitude: Number(s.latitude), longitude: Number(s.longitude) })),
    };
    if (body.stops.length < 2) return setError('A route needs at least 2 stops.');
    if (body.stops.some((s) => Number.isNaN(s.latitude) || Number.isNaN(s.longitude))) return setError('Every stop needs a numeric latitude and longitude.');
    try {
      await api(edit.id ? `/routes/${edit.id}` : '/routes', { method: edit.id ? 'PUT' : 'POST', body });
      setEdit(null);
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const remove = async (r) => {
    if (!confirm(`Delete route ${r.route_number}? Buses on it will have no route.`)) return;
    try {
      await api(`/routes/${r.id}`, { method: 'DELETE' });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const setStop = (i, k, v) => setEdit({ ...edit, stops: edit.stops.map((s, j) => (j === i ? { ...s, [k]: v } : s)) });
  const moveStop = (i, d) => {
    const stops = [...edit.stops];
    [stops[i], stops[i + d]] = [stops[i + d], stops[i]];
    setEdit({ ...edit, stops });
  };

  return (
    <>
      <header className="page-head">
        <h1>Routes &amp; stops</h1>
        <button className="btn primary" onClick={() => open(null)}>New route</button>
      </header>
      {error && <div className="alert">{error}</div>}
      {edit && (
        <form className="card" onSubmit={save}>
          <h2>{edit.id ? `Edit route ${edit.route_number}` : 'New route'}</h2>
          <div className="row-form">
            <input placeholder="Route number" value={edit.route_number} onChange={(e) => setEdit({ ...edit, route_number: e.target.value })} required />
            <input placeholder="Origin" value={edit.origin} onChange={(e) => setEdit({ ...edit, origin: e.target.value })} required />
            <input placeholder="Destination" value={edit.destination} onChange={(e) => setEdit({ ...edit, destination: e.target.value })} required />
            <label className="inline">Full fare (Rs.)<input type="number" min="0" value={edit.standard_fare} onChange={(e) => setEdit({ ...edit, standard_fare: e.target.value })} /></label>
            <label className="inline">Minutes<input type="number" min="1" value={edit.estimated_duration_mins} onChange={(e) => setEdit({ ...edit, estimated_duration_mins: e.target.value })} /></label>
          </div>
          <h3>Stops in travel order</h3>
          <table>
            <thead><tr><th>#</th><th>Stop name</th><th>Latitude</th><th>Longitude</th><th></th></tr></thead>
            <tbody>
              {edit.stops.map((s, i) => (
                <tr key={i}>
                  <td>{i + 1}</td>
                  <td><input value={s.stop_name} onChange={(e) => setStop(i, 'stop_name', e.target.value)} aria-label={`Stop ${i + 1} name`} /></td>
                  <td><input value={s.latitude} onChange={(e) => setStop(i, 'latitude', e.target.value)} aria-label={`Stop ${i + 1} latitude`} /></td>
                  <td><input value={s.longitude} onChange={(e) => setStop(i, 'longitude', e.target.value)} aria-label={`Stop ${i + 1} longitude`} /></td>
                  <td className="nowrap">
                    <button type="button" className="btn small" disabled={i === 0} onClick={() => moveStop(i, -1)} aria-label="Move up">↑</button>
                    <button type="button" className="btn small" disabled={i === edit.stops.length - 1} onClick={() => moveStop(i, 1)} aria-label="Move down">↓</button>
                    <button type="button" className="btn small" onClick={() => setEdit({ ...edit, stops: edit.stops.filter((_, j) => j !== i) })} aria-label="Remove stop">✕</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="actions">
            <button type="button" className="btn" onClick={() => setEdit({ ...edit, stops: [...edit.stops, { stop_name: '', latitude: '', longitude: '' }] })}>Add stop</button>
            <span className="spacer" />
            <button type="button" className="btn" onClick={() => setEdit(null)}>Cancel</button>
            <button className="btn primary">Save route</button>
          </div>
        </form>
      )}
      <section className="card">
        <table>
          <thead><tr><th>Route</th><th>From → To</th><th>Stops</th><th>Duration</th><th>Full fare</th><th></th></tr></thead>
          <tbody>
            {routes.map((r) => (
              <tr key={r.id}>
                <td><strong>{r.route_number}</strong></td>
                <td>{r.origin} → {r.destination}</td>
                <td>{r.stop_count}</td>
                <td>{r.estimated_duration_mins} min</td>
                <td>{money(r.standard_fare)}</td>
                <td className="nowrap">
                  <button className="btn small" onClick={() => open(r)}>Edit</button>
                  <button className="btn small danger" onClick={() => remove(r)}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}

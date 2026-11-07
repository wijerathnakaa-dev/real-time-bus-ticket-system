import { useEffect, useState } from 'react';
import { api, fmtTime } from '../api.js';

export default function Users() {
  const [role, setRole] = useState('conductor');
  const [rows, setRows] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    api('/admin/users', { query: { role } }).then(setRows).catch((e) => setError(e.message));
  }, [role]);

  return (
    <>
      <header className="page-head">
        <h1>Users</h1>
        <select value={role} onChange={(e) => setRole(e.target.value)} aria-label="Role">
          <option value="conductor">Conductors</option>
          <option value="passenger">Passengers</option>
          <option value="admin">Admins</option>
          <option value="">Everyone</option>
        </select>
      </header>
      {error && <div className="alert">{error}</div>}
      <p className="muted">Assign conductors to buses on the Buses page.</p>
      <section className="card">
        <table>
          <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Role</th><th>Assigned bus</th><th>Joined</th></tr></thead>
          <tbody>
            {rows.map((u) => (
              <tr key={u.id}>
                <td>{u.name}</td>
                <td>{u.email}</td>
                <td>{u.phone || '-'}</td>
                <td>{u.role}</td>
                <td>{u.assigned_bus_plate || '-'}</td>
                <td className="small">{fmtTime(u.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}

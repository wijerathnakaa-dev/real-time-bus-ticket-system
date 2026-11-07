import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { api, getToken, setToken } from './api.js';
import Login from './pages/Login.jsx';
import Overview from './pages/Overview.jsx';
import Buses from './pages/Buses.jsx';
import BusDetail from './pages/BusDetail.jsx';
import RoutesPage from './pages/Routes.jsx';
import Tickets from './pages/Tickets.jsx';
import Payments from './pages/Payments.jsx';
import Users from './pages/Users.jsx';

export default function App() {
  const [user, setUser] = useState(null);
  const [checking, setChecking] = useState(!!getToken());

  useEffect(() => {
    if (!getToken()) return;
    api('/auth/me')
      .then((u) => (u.role === 'admin' ? setUser(u) : setToken(null)))
      .catch(() => setToken(null))
      .finally(() => setChecking(false));
  }, []);

  const logout = () => {
    setToken(null);
    setUser(null);
  };

  if (checking) return <div className="center muted">Loading…</div>;
  if (!user) return <Login onLogin={setUser} />;

  return (
    <div className="shell">
      <aside className="nav">
        <div className="brand">
          CityBus Go <span>Admin</span>
        </div>
        <NavLink to="/" end>Overview</NavLink>
        <NavLink to="/buses">Buses</NavLink>
        <NavLink to="/routes">Routes &amp; stops</NavLink>
        <NavLink to="/tickets">Tickets</NavLink>
        <NavLink to="/payments">Payments</NavLink>
        <NavLink to="/users">Users</NavLink>
        <div className="nav-foot">
          <div className="muted small">{user.name}</div>
          <button className="link" onClick={logout}>Sign out</button>
        </div>
      </aside>
      <main className="main">
        <Routes>
          <Route path="/" element={<Overview />} />
          <Route path="/buses" element={<Buses />} />
          <Route path="/buses/:id" element={<BusDetail />} />
          <Route path="/routes" element={<RoutesPage />} />
          <Route path="/tickets" element={<Tickets />} />
          <Route path="/payments" element={<Payments />} />
          <Route path="/users" element={<Users />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </main>
    </div>
  );
}

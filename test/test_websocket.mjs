// Live-sync check: a client subscribed to one bus receives seat_booked / seat_released
// within the 2-5 s target when a conductor issues and frees a ticket.
//   API_URL=http://127.0.0.1:5000 node test/test_websocket.mjs
const API = (process.env.API_URL || 'http://127.0.0.1:5000').replace(/\/$/, '');
const BUS = 'bus_nb2451';
const j = async (method, path, body, token) => {
  const r = await fetch(API + '/api/v1' + path, { method, headers: { 'Content-Type': 'application/json', ...(token && { Authorization: 'Bearer ' + token }) }, body: body && JSON.stringify(body) });
  return [r.status, await r.json().catch(() => null)];
};
const [, login] = await j('POST', '/auth/login', { email: 'conductor1@citybus.lk', password: 'Conductor@123' });
const [, seats] = await j('GET', `/buses/${BUS}/seats`);
const seat = seats.reverse().find(s => s.status === 'available').seat_number;

const ws = new WebSocket(API.replace(/^http/, 'ws') + '/ws?bus_id=' + BUS);
const other = new WebSocket(API.replace(/^http/, 'ws') + '/ws?bus_id=bus_nc7832');
let otherGot = 0; other.onmessage = () => otherGot++;
const got = [];
const t0 = { v: 0 };
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.seat_number === seat) got.push([m.type, Date.now() - t0.v]); };
await new Promise(r => ws.onopen = r);
await new Promise(r => setTimeout(r, 200));
t0.v = Date.now();
await j('POST', '/tickets', { bus_id: BUS, seat_number: seat }, login.token);
await j('POST', '/seats/release', { bus_id: BUS, seat_number: seat }, login.token);
await new Promise(r => setTimeout(r, 1000));
ws.close(); other.close();
const types = got.map(g => g[0]);
const ok = types.includes('seat_booked') && types.includes('seat_released') && got.every(g => g[1] < 2000) && otherGot === 0;
console.log(ok ? 'PASS' : 'FAIL', `seat ${seat}:`, JSON.stringify(got), `| other-bus client received ${otherGot}`);
process.exit(ok ? 0 : 1);

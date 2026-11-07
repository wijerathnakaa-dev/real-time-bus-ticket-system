// Go REST API + WebSocket client for the admin dashboard.
export const API_URL = (import.meta.env?.VITE_API_URL || 'http://localhost:5000').replace(/\/$/, '');

const TOKEN_KEY = 'citybus_admin_token';

export function getToken() {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setToken(t) {
  try {
    t ? localStorage.setItem(TOKEN_KEY, t) : localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* private mode: session-only login */
  }
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function api(path, { method = 'GET', body, query } = {}) {
  const qs = query ? '?' + new URLSearchParams(Object.entries(query).filter(([, v]) => v !== '' && v != null)) : '';
  let res;
  try {
    res = await fetch(`${API_URL}/api/v1${path}${qs}`, {
      method,
      headers: { 'Content-Type': 'application/json', ...(getToken() && { Authorization: `Bearer ${getToken()}` }) },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError(0, `Cannot reach the API at ${API_URL}. Is the Go backend running?`);
  }
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    if (res.status === 401) setToken(null);
    throw new ApiError(res.status, data?.error || `Request failed (${res.status})`);
  }
  return data;
}

/** Subscribes to every live event (admin view). Reconnects with backoff; calls onEvent({type:'resync'}) on (re)connect. */
export function liveEvents(onEvent) {
  let ws;
  let closed = false;
  let attempt = 0;
  let timer;
  const connect = () => {
    ws = new WebSocket(API_URL.replace(/^http/, 'ws') + '/ws');
    ws.onopen = () => {
      attempt = 0;
      onEvent({ type: 'resync' });
    };
    ws.onmessage = (e) => {
      try {
        onEvent(JSON.parse(e.data));
      } catch {
        /* ignore malformed */
      }
    };
    ws.onclose = () => {
      if (closed) return;
      onEvent({ type: 'disconnected' });
      timer = setTimeout(connect, [1000, 2000, 4000, 8000, 15000][Math.min(attempt++, 4)]);
    };
  };
  connect();
  return () => {
    closed = true;
    clearTimeout(timer);
    ws?.close();
  };
}

export const money = (v) => `Rs. ${Number(v || 0).toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export const fmtTime = (iso) => (iso ? new Date(iso).toLocaleString('en-LK', { dateStyle: 'medium', timeStyle: 'short' }) : '-');

/** Describes a live event in one line for the activity feed. */
export function describeEvent(e, plates = {}) {
  const bus = plates[e.bus_id] || e.bus_id;
  switch (e.type) {
    case 'seat_booked':
      return `${bus}: seat ${e.seat_number} taken${e.issued_by_role ? ` (${e.issued_by_role === 'passenger' ? 'in-app' : 'conductor'})` : ''}`;
    case 'seat_released':
      return `${bus}: seat ${e.seat_number} freed${e.reason ? ` (${e.reason.replace('_', ' ')})` : ''}`;
    case 'ticket_paid':
      return `${bus}: ticket for seat ${e.seat_number} paid`;
    case 'stop_arrival':
      return `${bus}: arrived at a stop${e.automatic ? ' (GPS)' : ''}`;
    case 'stop_departure':
      return `${bus}: departed a stop`;
    case 'trip_start':
      return `${bus}: trip started`;
    case 'trip_end':
      return `${bus}: trip ended`;
    case 'bus_approaching':
      return e.title;
    case 'bus_registered':
      return `New bus registered - awaiting approval`;
    default:
      return null;
  }
}

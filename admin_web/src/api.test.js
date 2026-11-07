import { describe, expect, it } from 'vitest';
import { describeEvent, money } from './api.js';
import { project } from './components/LiveMap.jsx';
import { summarize } from './pages/Tickets.jsx';

describe('admin dashboard helpers', () => {
  it('formats rupees', () => {
    expect(money(1000)).toBe('Rs. 1,000.00');
    expect(money(undefined)).toBe('Rs. 0.00');
  });

  it('turns live events into readable activity lines', () => {
    const plates = { bus_nb2451: 'NB-2451' };
    expect(describeEvent({ type: 'seat_booked', bus_id: 'bus_nb2451', seat_number: '7', issued_by_role: 'passenger' }, plates)).toBe('NB-2451: seat 7 taken (in-app)');
    expect(describeEvent({ type: 'seat_released', bus_id: 'bus_nb2451', seat_number: '7', reason: 'manual_override' }, plates)).toBe('NB-2451: seat 7 freed (manual override)');
    expect(describeEvent({ type: 'bus_location' }, plates)).toBeNull();
  });

  it('summarizes revenue only from paid tickets', () => {
    const s = summarize([
      { fare: 1000, payment_status: 'paid', payment_method: 'cash', issued_by_role: 'conductor' },
      { fare: 290, payment_status: 'pending', payment_method: 'payhere', issued_by_role: 'passenger' },
      { fare: 400, payment_status: 'paid', payment_method: 'payhere', issued_by_role: 'passenger' },
    ]);
    expect(s).toEqual({ count: 3, revenue: 1400, inApp: 2, cash: 1 });
  });

  it('projects lat/lng into the schematic map with north up', () => {
    const pts = [{ lat: 6.84, lng: 79.97 }, { lat: 6.06, lng: 80.24 }];
    const xy = project(pts, 800, 400);
    const [x1, y1] = xy(pts[0]);
    const [x2, y2] = xy(pts[1]);
    expect(y1).toBeLessThan(y2); // Makumbura (north) above Galle
    expect(x1).toBeLessThan(x2); // and to the west
    for (const v of [x1, y1, x2, y2]) expect(v).toBeGreaterThanOrEqual(0);
  });
});

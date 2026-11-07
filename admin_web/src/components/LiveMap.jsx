import { useEffect, useRef } from 'react';

const MAPS_KEY = import.meta.env?.VITE_GOOGLE_MAPS_KEY || '';

let mapsPromise;
function loadGoogleMaps() {
  if (window.google?.maps) return Promise.resolve(window.google.maps);
  mapsPromise ??= new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(MAPS_KEY)}`;
    s.async = true;
    s.onload = () => resolve(window.google.maps);
    s.onerror = reject;
    document.head.appendChild(s);
  });
  return mapsPromise;
}

/**
 * All on-trip buses and route stops. Uses Google Maps when VITE_GOOGLE_MAPS_KEY is set,
 * otherwise a schematic SVG projection (no key needed) so monitoring always works.
 */
export default function LiveMap({ buses, routes, height = 360 }) {
  return MAPS_KEY ? <GoogleLiveMap buses={buses} routes={routes} height={height} /> : <SchematicMap buses={buses} routes={routes} height={height} />;
}

function GoogleLiveMap({ buses, routes, height }) {
  const el = useRef(null);
  const map = useRef(null);
  const markers = useRef([]);

  useEffect(() => {
    let cancelled = false;
    loadGoogleMaps().then((maps) => {
      if (cancelled || !el.current) return;
      map.current ??= new maps.Map(el.current, { center: { lat: 6.75, lng: 80.0 }, zoom: 9, streetViewControl: false, mapTypeControl: false });
      markers.current.forEach((m) => m.setMap(null));
      markers.current = [];
      for (const r of routes) {
        if (!r.stops?.length) continue;
        markers.current.push(new maps.Polyline({ map: map.current, path: r.stops.map((s) => ({ lat: s.latitude, lng: s.longitude })), strokeColor: '#1E88E5', strokeWeight: 3 }));
        for (const s of r.stops) {
          markers.current.push(new maps.Marker({ map: map.current, position: { lat: s.latitude, lng: s.longitude }, title: s.stop_name, icon: { path: maps.SymbolPath.CIRCLE, scale: 4, fillColor: '#fff', fillOpacity: 1, strokeColor: '#1E88E5', strokeWeight: 2 } }));
        }
      }
      for (const b of buses) {
        if (b.latitude == null) continue;
        markers.current.push(new maps.Marker({ map: map.current, position: { lat: b.latitude, lng: b.longitude }, title: `${b.plate_number} - ${b.available_seats}/${b.total_seats} free`, label: { text: b.plate_number, fontSize: '11px', fontWeight: '700' } }));
      }
    });
    return () => {
      cancelled = true;
    };
  }, [buses, routes]);

  return <div ref={el} className="map" style={{ height }} />;
}

export function project(points, w, h, pad = 24) {
  const lats = points.map((p) => p.lat);
  const lngs = points.map((p) => p.lng);
  const [minLat, maxLat, minLng, maxLng] = [Math.min(...lats), Math.max(...lats), Math.min(...lngs), Math.max(...lngs)];
  const span = Math.max(maxLat - minLat, maxLng - minLng, 0.01);
  const scale = Math.min((w - pad * 2) / span, (h - pad * 2) / span);
  const ox = (w - (maxLng - minLng) * scale) / 2;
  const oy = (h - (maxLat - minLat) * scale) / 2;
  return ({ lat, lng }) => [ox + (lng - minLng) * scale, oy + (maxLat - lat) * scale];
}

function SchematicMap({ buses, routes, height }) {
  const W = 800;
  const H = height;
  const pts = [
    ...routes.flatMap((r) => (r.stops || []).map((s) => ({ lat: s.latitude, lng: s.longitude }))),
    ...buses.filter((b) => b.latitude != null).map((b) => ({ lat: b.latitude, lng: b.longitude })),
  ];
  if (!pts.length) return <div className="map center muted" style={{ height }}>No route or GPS data yet</div>;
  const xy = project(pts, W, H);
  return (
    <div className="map" style={{ height }}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height="100%" role="img" aria-label="Schematic map of routes and buses">
        {routes.map((r) => {
          const stops = r.stops || [];
          if (stops.length < 2) return null;
          const path = stops.map((s, i) => `${i ? 'L' : 'M'}${xy({ lat: s.latitude, lng: s.longitude }).join(',')}`).join(' ');
          return (
            <g key={r.id}>
              <path d={path} fill="none" stroke="var(--route)" strokeWidth="3" strokeLinecap="round" />
              {stops.map((s) => {
                const [x, y] = xy({ lat: s.latitude, lng: s.longitude });
                return (
                  <g key={s.id}>
                    <circle cx={x} cy={y} r="5" fill="var(--surface)" stroke="var(--route)" strokeWidth="2" />
                    <text x={x + 8} y={y + 4} className="map-label">{s.stop_name.replace(' Interchange', '')}</text>
                  </g>
                );
              })}
            </g>
          );
        })}
        {buses.filter((b) => b.latitude != null).map((b) => {
          const [x, y] = xy({ lat: b.latitude, lng: b.longitude });
          return (
            <g key={b.id}>
              <circle cx={x} cy={y} r="10" fill={b.status === 'on_trip' ? 'var(--ok)' : 'var(--muted)'} stroke="#fff" strokeWidth="2" />
              <text x={x} y={y - 14} textAnchor="middle" className="map-bus">{b.plate_number} · {b.available_seats} free</text>
            </g>
          );
        })}
      </svg>
      <div className="map-note">Schematic view - set VITE_GOOGLE_MAPS_KEY for Google Maps</div>
    </div>
  );
}

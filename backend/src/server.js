require('dotenv').config();
const http = require('http');
const app = require('./app');
const { Server } = require('socket.io');

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' }
});

// Real-time seat updates & GPS broadcasting via Socket.IO
io.on('connection', (socket) => {
  console.log(`[Socket.IO] Client connected: ${socket.id}`);

  // Join a specific bus room
  socket.on('join_bus', (busId) => {
    socket.join(`bus_${busId}`);
    console.log(`[Socket.IO] Client ${socket.id} joined room bus_${busId}`);
  });

  // Conductor broadcasts seat status update
  socket.on('seat_update', ({ busId, seatNumber, status, passengerId }) => {
    io.to(`bus_${busId}`).emit('seat_changed', { seatNumber, status, passengerId, timestamp: new Date() });
  });

  // Conductor broadcasts live GPS ping
  socket.on('gps_telemetry', ({ busId, latitude, longitude, speed, accuracy }) => {
    io.to(`bus_${busId}`).emit('location_update', { busId, latitude, longitude, speed, accuracy, timestamp: new Date() });
  });

  socket.on('disconnect', () => {
    console.log(`[Socket.IO] Client disconnected: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`[Server] Real-Time Bus System backend listening on port ${PORT}`);
});


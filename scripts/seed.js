const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
const seedDataPath = path.join(__dirname, 'seed_data.json');

if (!fs.existsSync(keyPath)) {
  console.error('Error: scripts/serviceAccountKey.json not found.');
  console.error('Please download your private key from Firebase Console -> Project Settings -> Service Accounts');
  process.exit(1);
}

const serviceAccount = require(keyPath);
const data = require(seedDataPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedDatabase() {
  console.log('Seeding Firestore database...');

  // 1. Seed Routes
  for (const route of data.routes) {
    const { id, ...routeData } = route;
    await db.doc(`routes/${id}`).set(routeData);
    console.log(`✓ Seeded route: routes/${id}`);
  }

  // 2. Seed Buses and Seats
  for (const bus of data.buses) {
    const { id, availableSeats, ...busData } = bus;
    await db.doc(`buses/${id}`).set({
      ...busData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✓ Seeded bus: buses/${id}`);

    // Batch seed 40 individual seats per bus
    const batch = db.batch();
    for (let i = 1; i <= bus.totalSeats; i++) {
      const seatNum = String(i).padStart(2, '0');
      const seatRef = db.doc(`buses/${id}/seats/${seatNum}`);
      batch.set(seatRef, {
        seatNumber: seatNum,
        status: 'available',
        bookedBy: null,
        bookedAt: null,
        ticketId: null
      });
    }
    await batch.commit();
    console.log(`  ✓ Seeded ${bus.totalSeats} seats under buses/${id}/seats/`);
  }

  console.log('Database seeding successfully completed!');
}

seedDatabase().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});


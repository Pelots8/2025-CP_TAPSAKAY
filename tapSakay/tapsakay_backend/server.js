require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const mongoose = require('mongoose');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/user');
const tapRoutes = require('./routes/tap');
const walletRoutes = require('./routes/wallet');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: (process.env.CLIENT_ORIGINS || '*').split(','), methods: ['GET','POST'] }
});

app.set('io', io);

app.use(cors({ origin: (process.env.CLIENT_ORIGINS || '*').split(',') }));
app.use(express.json());

// API
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/taps', tapRoutes);
app.use('/api/wallets', walletRoutes);

// Socket handlers (simple)
io.on('connection', socket => {
  console.log('socket connected', socket.id);
  socket.on('join_room', ({ room }) => {
    socket.join(room);
    console.log(`socket ${socket.id} joined room ${room}`);
  });
  socket.on('disconnect', () => console.log('socket disconnected', socket.id));
});

// DB connect + change streams
const start = async () => {
  await mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true });
  console.log('MongoDB connected');

  // watch wallets (collection name is 'wallets')
  const db = mongoose.connection;
  try {
    const walletStream = db.collection('wallets').watch();
    walletStream.on('change', async change => {
      if (change.operationType === 'update' || change.operationType === 'replace') {
        const full = change.fullDocument;
        if (full && full.ownerId) {
          io.to(`user:${full.ownerId}`).emit('wallet_updated', { ownerId: String(full.ownerId), wallet: full });
        }
      }
    });

    const userStream = db.collection('users').watch();
    userStream.on('change', change => {
      if (change.operationType === 'update' || change.operationType === 'replace') {
        const full = change.fullDocument;
        if (full && full._id) io.to(`user:${String(full._id)}`).emit('user_updated', { userId: String(full._id), user: full });
      }
    });

    const tapsStream = db.collection('nfctaps').watch();
    tapsStream.on('change', change => {
      if (change.operationType === 'insert') {
        const full = change.fullDocument;
        if (full) {
          if (full.ownerId) io.to(`user:${String(full.ownerId)}`).emit('tap_recorded', full);
          if (full.driverId) io.to(`driver:${String(full.driverId)}`).emit('tap_recorded', full);
        }
      }
    });
  } catch (err) {
    console.warn('Change streams error (replica set required):', err.message);
  }

  const port = process.env.PORT || 3000;
  server.listen(port, () => console.log(`Server listening on ${port}`));
};

start().catch(err => { console.error(err); process.exit(1); });

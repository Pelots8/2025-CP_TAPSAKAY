// server.js
require('dotenv').config();

if (!process.env.MONGO_URI) {
  console.error('Missing MONGO_URI in .env. Aborting.');
  process.exit(1);
}
if (!process.env.JWT_SECRET) {
  console.error('Missing JWT_SECRET in .env. Aborting.');
  process.exit(1);
}

const express = require('express');
const morgan = require('morgan');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const mongoSanitize = require('express-mongo-sanitize');
const cors = require('cors');
const connectDB = require('./config/db');
const errorHandler = require('./middleware/errorHandler');

const authRoutes = require('./routes/auth');
const walletRoutes = require('./routes/wallet');
const tapRoutes = require('./routes/tap');
const adminRoutes = require('./routes/admin');

const app = express();

app.use(helmet());
app.use(mongoSanitize());
app.use(cors());
app.use(express.json());
if (process.env.NODE_ENV !== 'production') app.use(morgan('dev'));

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 200 });
app.use(limiter);

app.use('/api/auth', authRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/tap', tapRoutes);
app.use('/api/admin', adminRoutes);

app.get('/', (req, res) => res.send('TapSakay backend is running'));

app.use(errorHandler);

const PORT = process.env.PORT || 5000;
connectDB(process.env.MONGO_URI).then(() => {
  const server = app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

  // graceful shutdown
  process.on('SIGINT', () => {
    console.info('SIGINT received — shutting down gracefully.');
    server.close(() => process.exit(0));
  });
});

process.on('unhandledRejection', (reason, p) => {
  console.error('Unhandled Rejection at:', p, 'reason:', reason);
});

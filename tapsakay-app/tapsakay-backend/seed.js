require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');

async function seed() {
  await mongoose.connect(process.env.MONGO_URI);
  const pw = await bcrypt.hash('password123', 10);
  const u = new User({ full_name: 'Pelota Rean', email: 'w@w.w', password: pw, balance: 100 });
  await u.save();
  console.log('seeded', u.email);
  process.exit();
}
seed();
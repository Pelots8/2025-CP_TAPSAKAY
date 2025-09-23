// seed/seed.js
require('dotenv').config();
const connectDB = require('../config/db');
const User = require('../models/User');

async function seed() {
  await connectDB(process.env.MONGO_URI);

  const adminEmail = 'admin@tapsakay.local';
  let admin = await User.findOne({ email: adminEmail });
  if (!admin) {
    admin = await User.create({
      name: 'TapSakay Admin',
      email: adminEmail,
      password: 'Admin123', // change immediately in prod
      role: 'admin',
      isVerified: true
    });
    console.log('Admin created:', adminEmail, 'password: Admin123!');
  } else {
    console.log('Admin exists:', adminEmail);
  }
  process.exit(0);
}

seed().catch(err => {
  console.error(err);
  process.exit(1);
});

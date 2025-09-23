// controllers/authController.js
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const Driver = require('../models/Driver');
const asyncHandler = require('../utils/asyncHandler');

function generateToken(user) {
  return jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });
}

function createError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

exports.register = asyncHandler(async (req, res) => {
  const { name, email, password, phone } = req.body;
  if (!name || !email || !password) throw createError(400, 'Missing fields');
  const exists = await User.findOne({ email: email.toLowerCase() });
  if (exists) throw createError(409, 'Email already registered');

  const user = await User.create({ name, email: email.toLowerCase(), password, phone, role: 'passenger' });
  res.status(201).json({
    user: { id: user._id, name: user.name, email: user.email, role: user.role },
    token: generateToken(user)
  });
});

exports.login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) throw createError(400, 'Missing credentials');

  const user = await User.findOne({ email: email.toLowerCase() });
  if (!user || !(await user.matchPassword(password))) {
    throw createError(401, 'Invalid credentials');
  }

  res.json({
    user: { id: user._id, name: user.name, email: user.email, role: user.role, balanceCents: user.balanceCents },
    token: generateToken(user)
  });
});

exports.registerDriver = asyncHandler(async (req, res) => {
  const { name, email, password, phone, licenseNumber, plateNumber, vehicleModel } = req.body;
  if (!name || !email || !password || !licenseNumber || !plateNumber) throw createError(400, 'Missing required driver fields');

  const exists = await User.findOne({ email: email.toLowerCase() });
  if (exists) throw createError(409, 'Email already registered');

  const user = await User.create({ name, email: email.toLowerCase(), password, phone, role: 'driver' });
  const driver = await Driver.create({
    user: user._id,
    licenseNumber,
    plateNumber,
    vehicleModel,
    approved: false
  });

  res.status(201).json({ message: 'Driver registered; pending approval', driverId: driver._id });
});

exports.me = asyncHandler(async (req, res) => {
  const user = req.user;
  res.json({
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    balanceCents: user.balanceCents
  });
});

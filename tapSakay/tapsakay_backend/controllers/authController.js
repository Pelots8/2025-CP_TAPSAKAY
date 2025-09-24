const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

exports.register = async (req, res) => {
  const { name, email, phone, password, role } = req.body;
  const passwordHash = await bcrypt.hash(password || '123456', 10);
  const user = await User.create({ name, email, phone, passwordHash, role });
  res.json({ user });
};

exports.login = async (req, res) => {
  const { login, password } = req.body;
  const user = await User.findOne({ $or: [{ email: login }, { phone: login }] });
  if (!user) return res.status(401).json({ error: 'Invalid credentials' });
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(401).json({ error: 'Invalid credentials' });
  const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET || 'secret', { expiresIn: '7d' });
  res.json({ token, user });
};

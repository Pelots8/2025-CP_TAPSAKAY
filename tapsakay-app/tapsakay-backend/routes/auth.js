const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

router.post('/register', async (req, res) => {
  try {
    const { full_name, email, password, role, nfc_card_id } = req.body;
    if (!full_name || !email || !password) return res.status(400).json({ msg: 'Missing fields' });
    if (await User.findOne({ email })) return res.status(400).json({ msg: 'User exists' });
    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(password, salt);
    const user = new User({ full_name, email, password: hash, role: role || 'passenger', nfc_card_id: nfc_card_id || null });
    await user.save();
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    res.json({ token, user: { id: user._id, full_name: user.full_name, email: user.email, role: user.role, balance: user.balance } });
  } catch (err) { console.error(err); res.status(500).send('Server error'); }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ msg: 'Missing fields' });
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ msg: 'Invalid credentials' });
    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(400).json({ msg: 'Invalid credentials' });
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    res.json({ token, user: { id: user._id, full_name: user.full_name, email: user.email, role: user.role, balance: user.balance } });
  } catch (err) { console.error(err); res.status(500).send('Server error'); }
});

module.exports = router;

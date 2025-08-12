const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const User = require('../models/User');
const Transaction = require('../models/Transaction');

router.get('/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) return res.status(404).json({ msg: 'User not found' });
    res.json(user);
  } catch (err) { res.status(500).send('Server error'); }
});

router.put('/me', auth, async (req, res) => {
  try {
    const allowed = ['full_name','nfc_card_id'];
    const updates = {};
    allowed.forEach(k => { if (req.body[k] !== undefined) updates[k] = req.body[k]; });
    const user = await User.findByIdAndUpdate(req.user.id, { $set: updates }, { new: true }).select('-password');
    res.json(user);
  } catch (err) { res.status(500).send('Server error'); }
});

router.post('/topup', auth, async (req, res) => {
  try {
    const { amount, method } = req.body;
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) return res.status(400).json({ msg: 'Invalid amount' });
    const user = await User.findById(req.user.id);
    user.balance = Number((user.balance + amt).toFixed(2));
    await user.save();
    await Transaction.create({ user: user._id, type: 'top_up', amount: amt, location: method || 'GCash' });
    res.json({ balance: user.balance });
  } catch (err) { res.status(500).send('Server error'); }
});

router.get('/transactions', auth, async (req, res) => {
  try {
    const tx = await Transaction.find({ user: req.user.id }).sort({ date: -1 }).limit(100);
    res.json(tx);
  } catch (err) { res.status(500).send('Server error'); }
});

module.exports = router;

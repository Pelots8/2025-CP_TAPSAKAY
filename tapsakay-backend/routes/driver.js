// routes/driver.js
const express = require('express');
const router = express.Router();
const driverCtrl = require('../controllers/driverController');
const auth = require('../middleware/auth'); // your existing middleware that sets req.user
const User = require('../models/User');

// role-check middleware
async function requireDriverRole(req, res, next) {
  try {
    if (!req.user?.id) return res.status(401).json({ msg: 'Unauthorized' });
    const u = await User.findById(req.user.id).select('role');
    if (!u) return res.status(401).json({ msg: 'User not found' });
    if (u.role !== 'driver') return res.status(403).json({ msg: 'Forbidden: drivers only' });
    next();
  } catch (err) {
    console.error('requireDriverRole', err);
    res.status(500).json({ msg: 'Server error' });
  }
}

// protect and require driver role
router.use(auth); // middleware should set req.user = { id, ... } from token
router.use(requireDriverRole);

router.get('/profile', driverCtrl.getProfile);
router.get('/rides', driverCtrl.getAssignedRides);
router.post('/rides/:rideId/accept', driverCtrl.acceptRide);
router.post('/rides/:rideId/complete', driverCtrl.completeRide);

module.exports = router;

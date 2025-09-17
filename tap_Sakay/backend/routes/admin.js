// routes/admin.js
const express = require('express');
const router = express.Router();
const adminCtrl = require('../controllers/adminController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect);
router.use(authorize('admin'));

router.get('/stats', adminCtrl.getStats);
router.get('/drivers', adminCtrl.listDrivers);
router.put('/drivers/:driverId/approve', adminCtrl.approveDriver);

module.exports = router;

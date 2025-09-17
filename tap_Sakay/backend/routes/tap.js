// routes/tap.js
const express = require('express');
const { check } = require('express-validator');
const router = express.Router();
const tapCtrl = require('../controllers/tapController');
const { protect } = require('../middleware/auth');
const { runValidation } = require('../middleware/validate');

router.post(
  '/',
  protect,
  [
    check('driverId').notEmpty().withMessage('driverId required'),
    check('fare').notEmpty().withMessage('fare required')
  ],
  runValidation,
  tapCtrl.tap
);

module.exports = router;

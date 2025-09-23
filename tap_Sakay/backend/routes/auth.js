// routes/auth.js
const express = require('express');
const { check } = require('express-validator');
const router = express.Router();

// controller and validation middleware
const authCtrl = require('../controllers/authController');
const { runValidation } = require('../middleware/validate');
const { protect } = require('../middleware/auth');

// passenger registration
router.post(
  '/register',
  [
    check('name').notEmpty().withMessage('Name is required'),
    check('email').isEmail().withMessage('Valid email required'),
    check('password').isLength({ min: 6 }).withMessage('Password at least 6 chars')
  ],
  runValidation,
  authCtrl.register
);

router.post(
  '/login',
  [
    check('email').isEmail().withMessage('Valid email required'),
    check('password').notEmpty().withMessage('Password required')
  ],
  runValidation,
  authCtrl.login
);

router.post(
  '/driver/register',
  [
    check('name').notEmpty(),
    check('email').isEmail(),
    check('password').isLength({ min: 6 }),
    check('licenseNumber').notEmpty(),
    check('plateNumber').notEmpty()
  ],
  runValidation,
  authCtrl.registerDriver
);

router.get('/me', protect, authCtrl.me);

module.exports = router;

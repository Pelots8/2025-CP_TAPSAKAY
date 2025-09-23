// routes/wallet.js
const express = require('express');
const { check } = require('express-validator');
const router = express.Router();
const walletCtrl = require('../controllers/walletController');
const { protect } = require('../middleware/auth');
const { runValidation } = require('../middleware/validate');

// top-up: amount is a decimal in PHP (e.g., 100.50)
router.post('/topup',
  protect,
  [ check('amount').notEmpty().withMessage('Amount required') ],
  runValidation,
  walletCtrl.topup
);

router.get('/balance', protect, walletCtrl.getBalance);
router.get('/transactions', protect, walletCtrl.listTransactions);

module.exports = router;

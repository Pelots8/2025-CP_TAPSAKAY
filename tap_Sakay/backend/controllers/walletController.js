// controllers/walletController.js
const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const Transaction = require('../models/Transaction');
const asyncHandler = require('../utils/asyncHandler');
const { toCents, centsToPHP } = require('../utils/money');

function createError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

exports.topup = asyncHandler(async (req, res) => {
  const user = req.user;
  const amountRaw = req.body.amount;
  const amountCents = toCents(amountRaw);
  if (!Number.isFinite(amountCents) || amountCents <= 0) throw createError(400, 'Amount is required and must be a positive number');

  user.balanceCents = (user.balanceCents || 0) + amountCents;
  await user.save();

  const tx = await Transaction.create({
    txId: uuidv4(),
    type: 'topup',
    amountCents,
    platformCommissionCents: 0,
    fromUser: null,
    toUser: user._id,
    status: 'success',
    meta: { externalReference: req.body.externalReference || null }
  });

  res.json({
    message: 'Top-up successful',
    balanceCents: user.balanceCents,
    balancePHP: centsToPHP(user.balanceCents),
    transaction: tx
  });
});

exports.getBalance = asyncHandler(async (req, res) => {
  const user = req.user;
  res.json({ balanceCents: user.balanceCents || 0, balancePHP: centsToPHP(user.balanceCents || 0) });
});

exports.listTransactions = asyncHandler(async (req, res) => {
  const user = req.user;
  const txs = await Transaction.find({ $or: [{ fromUser: user._id }, { toUser: user._id }] })
    .sort({ createdAt: -1 })
    .limit(200);
  res.json(txs);
});

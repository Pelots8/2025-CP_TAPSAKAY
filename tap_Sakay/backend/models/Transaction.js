// models/Transaction.js
const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  txId: { type: String, required: true, unique: true, index: true },
  type: { type: String, enum: ['topup', 'payment'], required: true },
  amountCents: { type: Number, required: true },
  platformCommissionCents: { type: Number, default: 0 },
  fromUser: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  toUser: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver' },
  status: { type: String, enum: ['success', 'failed', 'pending'], default: 'success' },
  meta: { type: mongoose.Schema.Types.Mixed },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Transaction', transactionSchema);

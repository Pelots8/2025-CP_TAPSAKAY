const mongoose = require('mongoose');
const TxSchema = new mongoose.Schema({
  walletId: { type: mongoose.Schema.Types.ObjectId, ref: 'Wallet', required: true },
  ownerType: String,
  ownerId: { type: mongoose.Schema.Types.ObjectId },
  type: String,
  amount: Number,
  direction: { type: String, enum: ['credit','debit'] },
  meta: mongoose.Schema.Types.Mixed,
  balanceAfter: Number,
  createdAt: { type: Date, default: Date.now }
});
TxSchema.index({ ownerId: 1, createdAt: -1 });
module.exports = mongoose.model('Transaction', TxSchema);

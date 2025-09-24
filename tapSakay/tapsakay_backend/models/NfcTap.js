const mongoose = require('mongoose');

const NFCTapSchema = new mongoose.Schema({
  cardId: String,
  deviceId: String,
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  driverId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  timestamp: { type: Date, default: Date.now },
  location: { type: { type: String, default: 'Point' }, coordinates: [Number] },
  result: String,
  meta: mongoose.Schema.Types.Mixed
}, { timestamps: true });

module.exports = mongoose.model('NfcTap', NFCTapSchema);

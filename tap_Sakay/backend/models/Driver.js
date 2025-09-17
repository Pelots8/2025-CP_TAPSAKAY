// models/Driver.js
const mongoose = require('mongoose');

const driverSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  licenseNumber: { type: String, required: true },
  plateNumber: { type: String, required: true },
  vehicleModel: { type: String },
  approved: { type: Boolean, default: false },
  earningsCents: { type: Number, default: 0 },
  documents: [{ filename: String, url: String }],
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Driver', driverSchema);

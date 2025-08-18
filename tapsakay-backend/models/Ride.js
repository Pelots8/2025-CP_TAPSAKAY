// models/Ride.js
const mongoose = require('mongoose');

const rideSchema = new mongoose.Schema({
  passengerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  driverId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  pickup: { type: String, required: true },
  dropoff: { type: String, required: true },
  fare: { type: Number, default: 0 },
  status: {
    type: String,
    enum: ['pending','assigned','ongoing','completed','cancelled'],
    default: 'pending'
  },
  requestedAt: { type: Date, default: Date.now },
  acceptedAt: { type: Date, default: null },
  completedAt: { type: Date, default: null }
}, { timestamps: true });

module.exports = mongoose.model('Ride', rideSchema);

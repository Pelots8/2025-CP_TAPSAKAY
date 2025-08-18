// controllers/driverController.js
const Joi = require('joi');
const Ride = require('../models/Ride');
const User = require('../models/User');
const mongoose = require('mongoose');

const idSchema = Joi.object({ rideId: Joi.string().required() });

exports.getProfile = async (req, res) => {
  try {
    const userId = req.user?.id;
    const user = await User.findById(userId).select('-password -__v');
    if (!user) return res.status(404).json({ msg: 'User not found' });
    res.json({ user });
  } catch (err) {
    console.error('getProfile', err);
    res.status(500).json({ msg: 'Server error' });
  }
};

exports.getAssignedRides = async (req, res) => {
  try {
    const userId = req.user?.id;
    const rides = await Ride.find({ driverId: userId, status: { $in: ['assigned','ongoing'] } })
      .populate('passengerId', 'full_name email phone')
      .sort({ requestedAt: -1 });
    res.json({ rides });
  } catch (err) {
    console.error('getAssignedRides', err);
    res.status(500).json({ msg: 'Server error' });
  }
};

// ATOMIC accept implementation to avoid race conditions
exports.acceptRide = async (req, res) => {
  try {
    const { error } = idSchema.validate(req.params);
    if (error) return res.status(400).json({ msg: 'Invalid ride id' });

    const userId = req.user?.id;
    const rideId = req.params.rideId;
    if (!mongoose.Types.ObjectId.isValid(rideId)) return res.status(400).json({ msg: 'Invalid ride id format' });

    // Atomic update: set driverId only if unassigned or already assigned to this same driver AND status pending/assigned
    const updated = await Ride.findOneAndUpdate(
      {
        _id: rideId,
        $or: [{ driverId: null }, { driverId: userId }],
        status: { $in: ['pending','assigned'] }
      },
      {
        $set: { driverId: userId, status: 'ongoing', acceptedAt: new Date() }
      },
      { new: true }
    ).populate('passengerId', 'full_name email phone');

    if (!updated) {
      return res.status(409).json({ msg: 'Ride could not be accepted (already taken or wrong status)' });
    }

    return res.json({ ride: updated });
  } catch (err) {
    console.error('acceptRide', err);
    return res.status(500).json({ msg: 'Server error' });
  }
};

exports.completeRide = async (req, res) => {
  try {
    const { error } = idSchema.validate(req.params);
    if (error) return res.status(400).json({ msg: 'Invalid ride id' });

    const userId = req.user?.id;
    const rideId = req.params.rideId;
    const ride = await Ride.findById(rideId);
    if (!ride) return res.status(404).json({ msg: 'Ride not found' });

    if (!ride.driverId || String(ride.driverId) !== String(userId)) {
      return res.status(403).json({ msg: 'Not authorized to complete this ride' });
    }

    if (ride.status !== 'ongoing') return res.status(400).json({ msg: `Cannot complete ride in status ${ride.status}` });

    ride.status = 'completed';
    ride.completedAt = new Date();
    await ride.save();

    const populated = await ride.populate('passengerId', 'full_name email phone');
    res.json({ ride: populated });
  } catch (err) {
    console.error('completeRide', err);
    res.status(500).json({ msg: 'Server error' });
  }
};

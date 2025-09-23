// controllers/adminController.js
const User = require('../models/User');
const Driver = require('../models/Driver');
const Transaction = require('../models/Transaction');
const asyncHandler = require('../utils/asyncHandler');
const { centsToPHP } = require('../utils/money');

exports.getStats = asyncHandler(async (req, res) => {
  const usersCount = await User.countDocuments();
  const driversCount = await Driver.countDocuments();
  const totalTx = await Transaction.aggregate([{ $group: { _id: null, totalCents: { $sum: "$amountCents" }, count: { $sum: 1 } } }]);

  const totalCents = totalTx[0] ? totalTx[0].totalCents : 0;
  res.json({
    usersCount,
    driversCount,
    totalTransactionAmountCents: totalCents,
    totalTransactionAmountPHP: centsToPHP(totalCents),
    totalTransactions: totalTx[0] ? totalTx[0].count : 0
  });
});

exports.listDrivers = asyncHandler(async (req, res) => {
  const drivers = await Driver.find().populate('user', 'name email phone role');
  res.json(drivers);
});

exports.approveDriver = asyncHandler(async (req, res) => {
  const { driverId } = req.params;
  const driver = await Driver.findById(driverId);
  if (!driver) return res.status(404).json({ message: 'Driver not found' });
  driver.approved = true;
  await driver.save();
  await User.findByIdAndUpdate(driver.user, { isVerified: true });
  res.json({ message: 'Driver approved', driver });
});

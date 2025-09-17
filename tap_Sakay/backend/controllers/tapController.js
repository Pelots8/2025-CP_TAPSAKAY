// controllers/tapController.js
const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const Driver = require('../models/Driver');
const Transaction = require('../models/Transaction');
const asyncHandler = require('../utils/asyncHandler');
const { toCents, centsToPHP } = require('../utils/money');

const PLATFORM_COMMISSION_PERCENT = Number(process.env.PLATFORM_COMMISSION_PERCENT || 10);

function createError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

exports.tap = asyncHandler(async (req, res) => {
  const passenger = req.user;
  const { driverId } = req.body;
  const fareCents = toCents(req.body.fare);

  if (!driverId) throw createError(400, 'driverId is required');
  if (!Number.isFinite(fareCents) || fareCents <= 0) throw createError(400, 'fare is required and must be a positive number');

  let session;
  try {
    session = await mongoose.startSession();
    session.startTransaction();

    const passengerDoc = await User.findById(passenger._id).session(session);
    if (!passengerDoc) throw createError(404, 'Passenger not found');

    const driverDoc = await Driver.findById(driverId).session(session);
    if (!driverDoc) throw createError(404, 'Driver not found');
    if (!driverDoc.approved) throw createError(403, 'Driver not approved');

    if ((passengerDoc.balanceCents || 0) < fareCents) throw createError(400, 'Insufficient balance');

    const commissionCents = Math.round((fareCents * PLATFORM_COMMISSION_PERCENT) / 100);
    const driverShareCents = fareCents - commissionCents;

    passengerDoc.balanceCents = passengerDoc.balanceCents - fareCents;
    driverDoc.earningsCents = (driverDoc.earningsCents || 0) + driverShareCents;

    await passengerDoc.save({ session });
    await driverDoc.save({ session });

    const txs = await Transaction.create([{
      txId: uuidv4(),
      type: 'payment',
      amountCents: fareCents,
      platformCommissionCents: commissionCents,
      fromUser: passengerDoc._id,
      toUser: driverDoc.user,
      driver: driverDoc._id,
      status: 'success',
      meta: { route: req.body.route || null }
    }], { session });

    await session.commitTransaction();
    session.endSession();

    res.json({
      message: 'Tap successful',
      fareCents,
      farePHP: centsToPHP(fareCents),
      commissionCents,
      commissionPHP: centsToPHP(commissionCents),
      driverShareCents,
      driverSharePHP: centsToPHP(driverShareCents),
      passengerBalanceCents: passengerDoc.balanceCents,
      passengerBalancePHP: centsToPHP(passengerDoc.balanceCents),
      transaction: txs[0]
    });
  } catch (err) {
    if (session && session.inTransaction()) {
      try { await session.abortTransaction(); } catch (e) { console.error('abort error', e); }
    }
    if (session) session.endSession();
    throw err;
  }
});

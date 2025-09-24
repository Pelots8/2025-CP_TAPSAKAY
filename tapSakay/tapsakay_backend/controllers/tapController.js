const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const NfcTap = require('../models/NfcTap');
const mongoose = require('mongoose');

async function findOwnerByCardId(cardId) {
  // placeholder function: adapt to your card mapping table
  // For demo we'll return the first passenger (not secure)
  const User = require('../models/User');
  return await User.findOne({ role: 'passenger' });
}

async function calculateFare() {
  // placeholder fare: 15.00 PHP in cents => 1500
  return 1500;
}

exports.handleTap = async (req, res) => {
  const io = req.app.get('io');
  const { cardId, deviceId, lat, lng } = req.body;
  const owner = await findOwnerByCardId(cardId);
  if (!owner) return res.status(404).json({ error: 'Card owner not found' });

  const session = await mongoose.startSession();
  try {
    let result = null;
    await session.withTransaction(async () => {
      const wallet = await Wallet.findOne({ ownerId: owner._id }).session(session);
      const fare = await calculateFare();
      if (!wallet || wallet.balance < fare) {
        // record failed tap
        const tapFailed = await NfcTap.create([{ cardId, deviceId, ownerId: owner._id, result: 'insufficient_balance', location: { type: 'Point', coordinates: [lng, lat] } }], { session });
        io.to(`user:${String(owner._id)}`).emit('tap_failed', { ownerId: String(owner._id), reason: 'insufficient_balance' });
        result = { success: false, reason: 'insufficient_balance' };
        return;
      }

      wallet.balance -= fare;
      await wallet.save({ session });

      const tx = await Transaction.create([{
        walletId: wallet._id, ownerType: 'user', ownerId: owner._id, type: 'fare', amount: fare, direction: 'debit', balanceAfter: wallet.balance
      }], { session });

      const tapRec = await NfcTap.create([{
        cardId, deviceId, ownerId: owner._id, result: 'success', location: { type: 'Point', coordinates: [lng, lat] }
      }], { session });

      // emit immediate events
      io.to(`user:${String(owner._id)}`).emit('wallet_updated', { ownerId: String(owner._id), wallet, transaction: tx[0] });
      io.to(`driver:all`).emit('tap_recorded', { tap: tapRec[0] }); // broadcast to all drivers OR send to a specific driver room
      result = { success: true, wallet, transaction: tx[0], tap: tapRec[0] };
    });

    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    session.endSession();
  }
};

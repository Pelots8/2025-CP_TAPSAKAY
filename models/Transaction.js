const mongoose = require('mongoose');
const txSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, enum: ['tap_in','tap_out','top_up'], required: true },
  date: { type: Date, default: Date.now },
  location: { type: String, default: '' },
  amount: { type: Number, default: 0.0 }
});
module.exports = mongoose.model('Transaction', txSchema);

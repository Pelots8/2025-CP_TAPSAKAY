const mongoose = require('mongoose');
const userSchema = new mongoose.Schema({
  full_name: { type: String, required: true, trim: true, maxlength: 100 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true, maxlength: 100 },
  password: { type: String, required: true },
  role: { type: String, enum: ['admin','passenger','driver'], default: 'passenger' },
  nfc_card_id: { type: String, default: null, maxlength: 50 },
  balance: { type: Number, default: 0.00, min: 0 },
  registered_date: { type: Date, default: Date.now }
});
module.exports = mongoose.model('User', userSchema);

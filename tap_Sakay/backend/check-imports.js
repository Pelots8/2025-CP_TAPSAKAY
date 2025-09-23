// check-imports.js
const path = require('path');

function safeRequire(p) {
  try {
    return { ok: true, keys: Object.keys(require(p) || {}) };
  } catch (err) {
    return { ok: false, err: err.message };
  }
}

const authCtrl = safeRequire('./controllers/authController');
const validate = safeRequire('./middleware/validate');
const auth = safeRequire('./middleware/auth');

console.log('controllers/authController =>', authCtrl);
console.log('middleware/validate =>', validate);
console.log('middleware/auth =>', auth);

// check-imports-wallet.js
function safeRequire(p) {
  try {
    const mod = require(p);
    return { ok: true, keys: Object.keys(mod || {}) };
  } catch (err) {
    return { ok: false, err: err.message };
  }
}

console.log('walletCtrl =>', safeRequire('./controllers/walletController'));
console.log('validate =>', safeRequire('./middleware/validate'));
console.log('auth =>', safeRequire('./middleware/auth'));

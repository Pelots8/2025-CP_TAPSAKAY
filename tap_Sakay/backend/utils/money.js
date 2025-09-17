// utils/money.js
function toCents(amount) {
  const n = Number(amount);
  if (!Number.isFinite(n)) return NaN;
  return Math.round(n * 100);
}

function centsToPHP(cents) {
  return (Number(cents) / 100).toFixed(2);
}

module.exports = { toCents, centsToPHP };

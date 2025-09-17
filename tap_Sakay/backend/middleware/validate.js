// middleware/validate.js
const { validationResult } = require('express-validator');

/**
 * runValidation middleware
 * - reads results from express-validator checks
 * - if there are errors, respond 422 with array of errors
 * - otherwise call next()
 */
function runValidation(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ errors: errors.array() });
  }
  next();
}

// Export as a named property so require(...) returns { runValidation: [Function] }
module.exports = { runValidation };

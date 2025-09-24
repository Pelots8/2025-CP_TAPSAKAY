const router = require('express').Router();
const walletCtrl = require('../controllers/walletController');

router.get('/owner/:ownerId', walletCtrl.getWalletByOwner);
router.post('/topup', walletCtrl.topUp);

module.exports = router;

const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');
const env = require('../config/env');

const router = express.Router();

router.use(authenticate);

router.post('/sign', (request, response) => {
  const { cloudName, apiKey, apiSecret } = env.cloudinary;

  if (!cloudName || !apiKey || !apiSecret) {
    return response.status(503).json({
      error: 'cloudinary_not_configured',
      message: 'Cloudinary credentials are not fully configured on the server.',
    });
  }

  const timestamp = Math.round(Date.now() / 1000);
  const folder = request.body.folder || `gradtrack/${request.user.uid}`;
  const paramsToSign = {
    folder,
    timestamp: String(timestamp),
  };

  const sortedKeys = Object.keys(paramsToSign).sort();
  const signatureString =
    sortedKeys.map((k) => `${k}=${paramsToSign[k]}`).join('&') + apiSecret;

  const signature = crypto
    .createHash('sha1')
    .update(signatureString)
    .digest('hex');

  return response.json({
    signature,
    timestamp,
    folder,
    apiKey,
    cloudName,
  });
});

module.exports = router;

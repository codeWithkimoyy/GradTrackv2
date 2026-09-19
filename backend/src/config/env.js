const path = require('node:path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const port = Number.parseInt(process.env.PORT ?? '3000', 10);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be an integer between 1 and 65535.');
}

const corsOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:8080')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

module.exports = Object.freeze({
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port,
  corsOrigins,
  mysql: {
    host:
      process.env.MYSQL_HOST || process.env.SQL_HOST || 'localhost',
    port: Number.parseInt(
      process.env.MYSQL_PORT || process.env.SQL_PORT || '3306',
      10,
    ),
    user: process.env.MYSQL_USER || process.env.SQL_USER || 'root',
    password:
      process.env.MYSQL_PASSWORD ?? process.env.SQL_PASS ?? '',
    database:
      process.env.MYSQL_DATABASE || process.env.SQL_DATABASE || 'gradtrack_db',
  },
  adminSeed: {
    email: process.env.ADMIN_SEED_EMAIL ?? 'admin@gradtrack.edu.ph',
    password: process.env.ADMIN_SEED_PASSWORD ?? 'admin123',
    fullName: process.env.ADMIN_SEED_NAME ?? 'System Administrator',
  },
  messageEncryptionKey: process.env.MESSAGE_ENCRYPTION_KEY ?? '',
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME ?? '',
    apiKey: process.env.CLOUDINARY_API_KEY ?? '',
    apiSecret: process.env.CLOUDINARY_API_SECRET ?? '',
  },
  google: {
    // Web OAuth client ID used to verify Google Sign-In ID tokens.
    clientId: process.env.GOOGLE_SIGN_IN_CLIENT_ID ?? '',
  },
  smtp: {
    host: process.env.SMTP_HOST ?? 'smtp.gmail.com',
    port: Number.parseInt(process.env.SMTP_PORT ?? '465', 10),
    secure: (process.env.SMTP_SECURE ?? 'true') === 'true',
    user: process.env.SMTP_USER ?? '',
    pass: process.env.SMTP_PASS ?? '',
    from: process.env.SMTP_FROM ?? '',
  },
});

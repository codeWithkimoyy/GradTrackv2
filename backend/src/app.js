const cors = require('cors');
const express = require('express');
const helmet = require('helmet');

const env = require('./config/env');
const { isConnected: isMySQLConnected } = require('./config/mysql');
const profileRouter = require('./routes/profile');
const uploadRouter = require('./routes/upload');
const alumniRouter = require('./routes/alumni');
const authRouter = require('./routes/auth');
const employmentRouter = require('./routes/employment');
const documentsRouter = require('./routes/documents');
const surveysRouter = require('./routes/surveys');
const notificationsRouter = require('./routes/notifications');
const messagesRouter = require('./routes/messages');
const contentRouter = require('./routes/content');
const statsRouter = require('./routes/stats');
const auditRouter = require('./routes/audit');
const settingsRouter = require('./routes/settings');

const app = express();

app.disable('x-powered-by');
app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (
        env.corsOrigins.includes('*') ||
        !origin ||
        env.corsOrigins.includes(origin)
      ) {
        return callback(null, true);
      }
      return callback(new Error('Origin is not allowed by CORS.'));
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_request, response) => {
  response.json({
    status: 'ok',
    service: 'gradtrack-backend',
    mysqlConfigured: isMySQLConnected,
    database: 'MySQL',
  });
});

app.get('/api', (_request, response) => {
  response.json({
    name: 'GradTrack API',
    version: '2.0.0',
    database: 'MySQL',
  });
});

// In-memory sliding-window rate limiter for sensitive authentication endpoints
const authRateLimits = new Map();
function authRateLimiter(maxRequests = 30, windowMs = 60 * 1000) {
  return (req, res, next) => {
    if (env.nodeEnv === 'test') return next();
    const ip = req.ip || req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    const timestamps = (authRateLimits.get(ip) || []).filter((t) => now - t < windowMs);
    if (timestamps.length >= maxRequests) {
      return res.status(429).json({
        error: 'rate_limited',
        message: 'Too many attempts. Please wait a minute and try again.',
      });
    }
    timestamps.push(now);
    authRateLimits.set(ip, timestamps);
    return next();
  };
}

app.use('/api/profile', profileRouter);
app.use('/api/upload', uploadRouter);
app.use('/api/alumni', alumniRouter);
app.use('/api/auth', authRateLimiter(30, 60 * 1000), authRouter);
app.use('/api/employment', employmentRouter);
app.use('/api/documents', documentsRouter);
app.use('/api/surveys', surveysRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/conversations', messagesRouter);
app.use('/api/content', contentRouter);
app.use('/api/stats', statsRouter);
app.use('/api/audit-logs', auditRouter);
app.use('/api/settings', settingsRouter);

app.use((_request, response) => {
  response.status(404).json({
    error: 'not_found',
    message: 'The requested endpoint does not exist.',
  });
});

app.use((error, _request, response, _next) => {
  if (error.message === 'Origin is not allowed by CORS.') {
    return response.status(403).json({
      error: 'cors_rejected',
      message: error.message,
    });
  }

  // Gracefully handle database connection drop or unreachable MySQL host
  if (
    error.code === 'ECONNREFUSED' ||
    error.code === 'ENOTFOUND' ||
    error.code === 'ETIMEDOUT' ||
    error.code === 'PROTOCOL_CONNECTION_LOST' ||
    error.message?.includes('MySQL connection pool is not initialized')
  ) {
    return response.status(503).json({
      error: 'database_unavailable',
      message: 'Database service is temporarily unavailable. Please try again shortly.',
    });
  }

  if (env.nodeEnv !== 'test') {
    console.error(error);
  }
  return response.status(500).json({
    error: 'internal_server_error',
    message: 'An unexpected server error occurred.',
  });
});

module.exports = app;

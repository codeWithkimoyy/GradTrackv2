const cors = require('cors');
const express = require('express');
const helmet = require('helmet');

const env = require('./config/env');
const { hasFirebaseCredentials } = require('./config/firebase');
const { isConnected: isMySQLConnected } = require('./config/mysql');
const profileRouter = require('./routes/profile');
const uploadRouter = require('./routes/upload');
const alumniRouter = require('./routes/alumni');

const app = express();

app.disable('x-powered-by');
app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || env.corsOrigins.includes(origin)) {
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
    firebaseConfigured: hasFirebaseCredentials,
    mysqlConfigured: isMySQLConnected,
  });
});

app.get('/api', (_request, response) => {
  response.json({
    name: 'GradTrack API',
    version: '1.0.0',
    database: 'MySQL (Primary) + Firebase (Auth/Sync)',
  });
});

app.use('/api/profile', profileRouter);
app.use('/api/upload', uploadRouter);
app.use('/api/alumni', alumniRouter);

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

  if (env.nodeEnv !== 'test') {
    console.error(error);
  }
  return response.status(500).json({
    error: 'internal_server_error',
    message: 'An unexpected server error occurred.',
  });
});

module.exports = app;

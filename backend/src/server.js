const app = require('./app');
const env = require('./config/env');

const server = app.listen(env.port, () => {
  console.log(`GradTrack backend running on http://localhost:${env.port}`);
});

function shutdown(signal) {
  console.log(`${signal} received. Shutting down GradTrack backend.`);
  server.close(() => process.exit(0));
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

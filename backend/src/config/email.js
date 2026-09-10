const nodemailer = require('nodemailer');
const env = require('./env');

const { host, port, secure, user, pass, from } = env.smtp;

const hasSmtpCredentials = Boolean(host && user && pass);

let transporter = null;

if (hasSmtpCredentials) {
  transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });
}

async function sendCodeEmail({ to, code }) {
  if (transporter == null) {
    const error = new Error('SMTP is not configured on the server.');
    error.code = 'smtp_not_configured';
    throw error;
  }

  const sender = from || user;

  await transporter.sendMail({
    from: `GradTrack <${sender}>`,
    to,
    subject: 'Your GradTrack password reset code',
    text: [
      'You requested to reset your GradTrack account password.',
      '',
      `Your verification code is: ${code}`,
      '',
      'Enter this code in the app to confirm your identity. ',
      'The code expires in 10 minutes.',
      '',
      'If you did not request this, you can safely ignore this email.',
    ].join('\n'),
    html: [
      '<div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">',
      '<h2 style="color:#1d4ed8;">GradTrack Password Reset</h2>',
      '<p>You requested to reset your GradTrack account password. Use this code in the app:</p>',
      `<p style="font-size: 32px; letter-spacing: 8px; font-weight: bold; color:#111827;">${code}</p>`,
      '<p>This code expires in <strong>10 minutes</strong>.</p>',
      '<p style="color:#6b7280;">If you did not request this, you can safely ignore this email.</p>',
      '</div>',
    ].join('\n'),
  });
}

module.exports = {
  hasSmtpCredentials,
  sendCodeEmail,
};
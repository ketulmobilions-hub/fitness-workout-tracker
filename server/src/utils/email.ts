import nodemailer from 'nodemailer';
import { env } from './env.js';

// Transporter initialized once at module load and reused across all calls
// to avoid opening a new SMTP connection per email.
const transporter: nodemailer.Transporter | null = env.SMTP_HOST
  ? nodemailer.createTransport({
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_PORT === 465,
      auth:
        env.SMTP_USER && env.SMTP_PASS
          ? { user: env.SMTP_USER, pass: env.SMTP_PASS }
          : undefined,
    })
  : null;

export const sendPasswordResetEmail = async (to: string, resetUrl: string): Promise<void> => {
  if (!transporter) {
    // Log that the email was suppressed — do NOT log the token or the reset URL,
    // as those values are secrets and must not appear in log aggregation systems.
    // Do not log the email address — it is PII and must not appear in log aggregators
    console.log('[email] SMTP not configured — password reset email suppressed');
    return;
  }

  await transporter.sendMail({
    from: env.SMTP_FROM,
    to,
    subject: 'Reset your password',
    text: [
      'Click the link below to reset your password. This link expires in 1 hour.',
      '',
      resetUrl,
      '',
      "If you didn't request this, you can safely ignore this email.",
    ].join('\n'),
    html: [
      '<p>Click the link below to reset your password. This link expires in 1 hour.</p>',
      `<p><a href="${resetUrl}">${resetUrl}</a></p>`,
      "<p>If you didn't request this, you can safely ignore this email.</p>",
    ].join(''),
  });
};

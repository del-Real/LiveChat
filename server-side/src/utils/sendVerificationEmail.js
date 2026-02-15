import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

export const sendVerificationEmail = async (email, token) => {
  const link = `${process.env.FRONTEND_URL}/#/verify-email?token=${token}`;

  await transporter.sendMail({
    from: `"LiveChat" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: 'Verify your email',
    html: `
      <h2>Email Verification</h2>
      <p>Click the link below to verify your email:</p>
      <a href="${link}">${link}</a>
    `,
  });
};

export const sendResetPasswordEmail = async (email, token) => {
  const link = `${process.env.FRONTEND_URL}/#/reset-password/${token}`;

  await transporter.sendMail({
    from: `"LiveChat" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: 'Reset your password',
    html: `
      <h2>Password Reset</h2>
      <p>Click the link below to reset your password:</p>
      <a href="${link}">${link}</a>
      <p>This link expires in 15 minutes.</p>
    `,
  });
};


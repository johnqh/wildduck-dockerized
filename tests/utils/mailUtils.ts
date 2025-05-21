

import nodemailer from 'nodemailer';
import { connect } from 'imap-simple';

export async function sendMail({ username: user, password: pass, from, to, subject, text }: {
  username: string, password: string, from: string, to: string, subject: string, text: string
}) {
  const transporter = nodemailer.createTransport({
    host: process.env['IMAP_HOST'] || 'localhost',
    port: parseInt(process.env['SMTP_PORT'] || '25'),
    secure: false,
    auth: { user, pass },
  });

  return transporter.sendMail({ from, to, subject, text });
}

export async function fetchInbox({ username: user, password: pass }: { username: string, password: string }) {
  const conn = await connect({
    imap: {
      user,
      password: pass,
      host: process.env['IMAP_HOST'] || 'localhost',
      port: parseInt(process.env['IMAP_PORT'] || '143'),
      tls: false,
    },
  });

  await conn.openBox('INBOX');
  const messages = await conn.search(['ALL'], { bodies: ['HEADER'], struct: true });
  conn.end();
  return messages
}


import { ImapFlow } from 'imapflow';
import nodemailer from 'nodemailer';

export async function sendMail({ username: user, password: pass, from, to, subject, text }: {
  username: string, password: string, from: string, to: string, subject: string, text: string
}) {
  try {

    const transporter = nodemailer.createTransport({
      host: process.env['SMTP_HOST'] || 'localhost',
      port: parseInt(process.env['SMTP_PORT'] || '25'),
      secure: true,
      auth: { user, pass },

    });

    return transporter.sendMail({ from, to, subject, text });
  } catch (error) {
    console.error(error);
    throw error;
  }
}

export async function fetchInbox({ username: user, password: pass }: { username: string, password: string }) {
  const client = new ImapFlow({
    auth: {
      user,
      pass
    },
    host: process.env['IMAP_HOST'] || 'localhost',
    port: parseInt(process.env['IMAP_PORT'] || '143'),
    emitLogs: false,
    logger: false,
    secure: true,
  })
  try {


    await client.connect();
    let lock = await client.getMailboxLock('INBOX');
    if (!client.mailbox) {
      throw new Error('Mailbox does not exist');
    }


    // fetch latest message source
    // client.mailbox includes information about currently selected mailbox
    // "exists" value is also the largest sequence number available in the mailbox
    // const messages = await client.fetch("1:*", { source: true, envelope: true, bodyParts: ['HEADER', 'TEXT'] });

    // console.debug("messages", messages);
    const message = await client.fetchOne("*", { source: true, envelope: true, bodyParts: ['HEADER', 'TEXT'] });

    // console.debug("message", message);
    // Make sure lock is released, otherwise next `getMailboxLock()` never returns
    lock.release();

    // log out and close connection
    await client.logout();
    return message;
  } catch (error) {
    client.close()
    console.error(error);
    throw error;
  }
}


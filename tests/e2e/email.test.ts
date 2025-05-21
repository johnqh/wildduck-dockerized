
import { createUser, deleteUser } from '../utils/usersApi';
import { fetchInbox, sendMail } from '../utils/mailUtils';
import { sleep } from '../utils/time';

const DOMAIN_NAME = process.env.DOMAIN_NAME;
const testUsernName = `user_${Date.now()}`;
describe('Full email flow E2E tests', () => {
  // Step 1: Create two users

  const users = [
    { username: `${testUsernName}@${DOMAIN_NAME}`, password: 'useAveryBigPassword123123' },
    { username: `${testUsernName}_2@${DOMAIN_NAME}`, password: 'useAveryBigPassword123123' },
  ];

  let userIds: string[] = [];
  it('creates two users', async () => {
    for (const user of users) {
      const created = await createUser(user.username, user.password);
      expect(created).toHaveProperty('id');
      userIds.push(created.id);
    }
  });

  // Step 2: Send email with invalid SMTP auth - expect failure
  it('fails to send email with invalid SMTP auth', async () => {
    await expect(
      sendMail({
        username: users[0]!.username,
        password: 'wrong-password',
        from: users[0]!.username,
        to: users[1]!.username,
        subject: 'Invalid Auth Test',
        text: 'Should fail',
      })
    ).rejects.toThrow();
  }, 60000);

  // Step 3: Retrieve email with invalid auth - expect failure
  it('fails to retrieve emails with invalid IMAP auth', async () => {
    await expect(
      fetchInbox({
        username: users[1]!.username,
        password: 'wrong-password',
      })
    ).rejects.toThrow();
  });

  // Step 4: Retrieve email with valid auth - expect empty inbox
  it('retrieves empty inbox with valid IMAP auth', async () => {
    const emails = await fetchInbox({
      username: users[1]!.username,
      password: users[1]!.password,
    });
    expect(emails).toBe(false)
  });

  // Step 5: Send email with valid SMTP auth - expect success
  it('sends email successfully with valid SMTP auth', async () => {
    const result = await sendMail({
      username: users[0]!.username,
      password: users[0]!.password,
      from: users[0]!.username,
      to: users[1]!.username,
      subject: 'Hello from user1',
      text: 'This is a test email',
    });
    expect(result.accepted).toContain(users[1]!.username);
  });

  // Step 6: Retrieve email with valid IMAP - expect to get email
  it('retrieves inbox with the sent email', async () => {
    console.debug("waiting for message to be delivered")
    await sleep(4000);
    const email = await fetchInbox({
      username: users[1]!.username,
      password: users[1]!.password,
    });
    // console.debug("retrieved email", email);
    expect(email).toBeDefined();
    expect(email.envelope?.subject?.includes('Hello from user1')).toBe(true);
  }, 20000);

  // Step 7: Delete user1 - expect success
  it('deletes user1 successfully', async () => {
    await expect(deleteUser(userIds[0]!)).resolves.toBeDefined();
  });

  // Step 8: Delete user2 - expect success
  it('deletes user2 successfully', async () => {
    await expect(deleteUser(userIds[1]!)).resolves.toBeDefined();
  });
});

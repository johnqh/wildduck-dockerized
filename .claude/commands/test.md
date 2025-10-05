# Test Command

Run integration tests for the mail server deployment.

Tests include:
- User authentication
- Email sending (SMTP)
- Email receiving (IMAP)
- API operations

Prerequisites:
- Services must be running
- .env file configured with test credentials

```bash
npm test
```

For individual tests, see the tests/ directory.

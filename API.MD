Here are the API endpoints with descriptions:

Email Related Endpoints:

```
/api/get-all-emails
- Retrieves all emails from the system, including sent, scheduled, and draft emails
- Supports pagination and filtering by status, date range, and campaign

/api/send-email
- Sends an immediate email to specified recipients
- Accepts email content, subject, recipients, and attachments
- Returns delivery status and tracking ID

/api/schedule-send-emails
- Schedules emails for future delivery
- Accepts email content, subject, recipients, and desired send time
- Supports recurring schedules and time zone specifications

/api/generate-emails
- Automatically generates personalized email content using templates
- Takes template ID and recipient data as input
- Returns generated email content with merged variables

/api/email-clicked
- Tracks email engagement metrics (opens, clicks)
- Records timestamp and user information when links in emails are clicked
- Used for analytics and campaign performance tracking
```

LinkedIn Related Endpoints:

```
/api/getLinkedinMessages
- Retrieves LinkedIn messages and conversations
- Supports filtering by date, contact, or conversation status
- Returns message content, sender info, and timestamps

/api/sendLinkedinMessages
- Sends messages to LinkedIn connections
- Accepts message content and recipient LinkedIn IDs
- Supports template-based messaging
```

Prospect Related Endpoint:

```
/api/getProspects
- Retrieves list of sales prospects from the database
- Supports filtering by industry, company size, location
- Returns prospect details including contact info and engagement history
```

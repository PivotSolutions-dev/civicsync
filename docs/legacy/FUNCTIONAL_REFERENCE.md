# CivicSync Functional Reference

This document explains what CivicSync can do, how the main workflows operate, and what checks the system applies. It is written for committee members, office bearers, and future implementation teams.

## Purpose

CivicSync is a residential society management system. It helps the society manage members, legal documents, payment advice, receipts, vouchers, notices, admin roles, and society settings from one shared workspace.

The app has two main work areas:

- Admin workspace: for the society office bearers and authorized admins.
- Member portal: for residents/members to view their profile, documents, dues, payments, notices, and account state.

The login page uses the CivicSync logo, a compact Member/Admin content switcher, and a raised white login panel on an IBM Carbon blue page background.

## Interface Standards

Recent UI standards are applied across admin and portal screens:

- Tabs use compact content-switcher styling with visible boundaries and a full-width line below the tab bar.
- Tab contents sit inside a white body box with small internal padding.
- Inputs use boxed styling with a slight grey background instead of underline-only fields.
- Filled member phone/email fields use a very light blue input background, while verification icons stay outside that filled background.
- Modal button labels are vertically centered.
- Primary action buttons on settings, member details, and portal screens use consistent wider sizing and alignment.

## User Roles

### Super Admin

The Super Admin has the highest authority in the app.

Typical Super Admin powers:

- Add, edit, activate, deactivate, and delete members.
- Change member tower/unit and login username.
- Activate members after all activation conditions are satisfied.
- Create and manage admin accounts.
- Raise and delete payment advice.
- Create expense vouchers.
- Delete cancelled vouchers.
- Manage payment gateway, WhatsApp, organization, and integration settings.
- Export reports.

### Admin

Admins support daily operations. Their permissions depend partly on their organizational role.

General admin powers:

- View member records.
- Update allowed member details.
- Deactivate members.
- Reset member passwords.
- Upload or verify allowed documents if their organizational role permits it.
- View payments, vouchers, reports, notices, and activity where allowed.

### Organizational Roles

Organizational roles describe the office bearer position, such as:

- President
- General Secretary
- Treasurer
- Joint Treasurer
- Executive Member

These roles add functional permissions. For example:

- President and General Secretary can verify member documents.
- Treasurer and Joint Treasurer can raise/delete payment advice and delete cancelled vouchers.

### Member

Members use the portal for their own account.

Typical member powers:

- Log in to their own portal.
- View and update contact details.
- Upload personal documents.
- Delete their own documents.
- View payment advice and payment history.
- Pay outstanding dues.
- View notices.

## Member Lifecycle

### Member Creation

Admins can add a member with:

- Name
- Tower
- Flat/unit number
- Phone number
- Email
- Aadhaar/reference details, where applicable

The system expects the flat/unit value to be numeric.

### Contact Verification

The app tracks whether phone and email are verified.

Current prototype behavior:

- Blank phone or email values show no verification icon.
- Filled unverified phone or email values show a red cross without a green background.
- Verified phone or email values show a green tick without a green background.
- Verification actions are available only in the member portal.
- Verified contacts show a disabled Verify button.
- Mock verification is available for phone and email until live OTP delivery is connected.
- When phone or email is changed, the related verification is reset and the account is deactivated until activation gates pass again.
- Phone/email changes are blocked while the member has unresolved payment advice, because contact changes can deactivate the account.

Production target:

- Phone verification should happen through mobile OTP.
- Email verification should happen through email OTP.

### Legal Document Verification

Members can upload documents such as:

- Allotment letter
- Aadhaar
- PAN
- Sale deed
- Possession letter
- Other supporting documents

The allotment letter is the most important activation document.

Document verification can be done by:

- Super Admin
- President
- General Secretary

### Activation

A member can become active only when all activation gates pass:

- A verified allotment letter exists.
- Phone is verified.
- There is no lapsed or reinstatement-pending payment advice.
- The member has not been deleted.

Only the Super Admin should activate a member.

### Deactivation

A member can become inactive in several ways:

- Manual deactivation by an authorized admin.
- Deleting the last verified allotment letter.
- Failing to pay after the full payment escalation process completes.

Inactive members remain in history but are excluded from new payment manifests.

The only exception is an inactive member with a lapsed payment advice that still needs a linked reinstatement advice.

### Deletion

Deleting a member is a soft delete.

This means:

- Historical records are preserved.
- The member is removed from active operations.
- The record is not physically erased from all history.

Only the Super Admin can delete members.

## Payment Advice And Payments

### What Payment Advice Means

A payment advice is a formal due raised against one or more members. It tells the member:

- Why payment is required.
- How much is due.
- When it is due.
- What the current payment state is.

Payment advice statuses include:

- Pending
- Level 1 escalation
- Level 2 escalation
- Level 3 escalation
- Paid
- Cancelled
- Lapsed
- Reinstate pending
- Reinstate paid

### Raising Payment Advice

Payment advice can be raised by:

- Super Admin
- Treasurer
- Joint Treasurer

Advice can be raised for:

- All eligible active members.
- Selected eligible active members.
- Inactive members who have a lapsed payment advice and do not already have a linked reinstatement advice.

Eligible active members must generally have verified contact details.

When advice is raised for a member who is inactive because of a lapsed payment advice, the new advice is created as Reinstate pending and is linked to the specific lapsed advice that caused the deactivation.

### Deleting Payment Advice

Payment advice can be deleted only when it is:

- Pending
- Cancelled

Paid, lapsed, reinstate-pending, and reinstate-paid advice should not be manually deleted, because these states are tied to financial history or account reinstatement.

Allowed delete roles:

- Super Admin
- Treasurer
- Joint Treasurer

### Payment Escalation

The payment escalation matrix can move unpaid dues through configured levels.

Example flow:

1. Payment advice is raised.
2. Due date passes.
3. Level 1 escalation applies, if configured.
4. Level 2 escalation applies, if configured.
5. Level 3 escalation applies, if configured.
6. After the final grace period, the advice is marked lapsed and the member is made inactive.

A pending payment advice alone does not make the member inactive. Account deactivation happens only through manual Super Admin deactivation, deleting the last verified allotment letter when no unresolved payment advice exists, changing contact details when no unresolved payment advice exists, or the final payment failure step of the escalation matrix.

The escalation runner advances advice one stage at a time. It must not move a newly pending advice through all configured escalation levels and into lapsed status in a single processing pass.

When final escalation completes:

- The old advice becomes lapsed.
- The member becomes inactive.
- Any unfinished pending payment attempt attached to that advice is marked failed.

### Payment After Deactivation

If a member becomes inactive because of failed payment escalation:

1. The old advice remains as Lapsed.
2. Super Admin, Treasurer, or Joint Treasurer raises a fresh advice for that inactive member.
3. The fresh advice is created as Reinstate pending and is linked to the specific lapsed advice.
4. The member pays the reinstatement advice from the portal.
5. The advice becomes Reinstate paid.
6. The linked lapsed advice is deleted automatically.
7. Once all activation gates pass, the Super Admin can activate the member again.

Only the lapsed advice linked to the paid reinstatement advice is deleted. Unrelated lapsed records are preserved.

Activation should not be available before the reinstatement payment is completed.

### Mock Payments

The current app supports mock payments for testing.

Mock payment behavior:

- Records a successful payment.
- Marks the related payment advice as paid, or reinstate paid for reinstatement advice.
- Creates payment history for receipts and audit.

### Razorpay-Ready Flow

Razorpay Standard Checkout is wired for test-mode style use.

Expected flow:

1. Member selects an outstanding payment advice.
2. Backend creates a Razorpay order.
3. Frontend opens Razorpay Checkout.
4. Razorpay returns payment details.
5. Backend verifies the Razorpay signature.
6. Advice becomes paid or reinstate paid only after successful verification.

Opening the checkout screen alone does not mark payment as paid.

Payment actions are available only in the member portal. Admin tables and admin notifications should not show Pay dues actions.

## Payment History And Receipts

Payment history shows completed or historical financial activity.

It can include:

- Mock payments
- Razorpay payments
- Legacy imported payments
- Paid advice
- Cancelled advice history where retained
- Reinstatement payments

Receipts can be printed for successful payment records.

## Expense Vouchers

### Voucher Purpose

Expense vouchers are used for society expenses that require review, approval, printing, and accounting history.

Voucher examples:

- Petty cash
- Travel
- Statutory expenses
- Food
- Legal
- Accounting
- Services
- Miscellaneous

### Creating Vouchers

Only the Super Admin can create vouchers.

Voucher creation requires:

- Voucher type
- Amount
- Expense date
- Assigned organizational role
- Assigned people
- Description, where needed

### Approving Or Rejecting Vouchers

Assigned admins can approve or reject vouchers that are pending for them.

Voucher statuses include:

- Pending approval
- Accepted
- Rejected
- Approved
- Paid
- Cancelled

### Printing Vouchers

Accepted vouchers can be printed.

The printout uses the organization profile, including society name and registration details where available.

### Deleting Cancelled Vouchers

Only cancelled vouchers can be deleted.

Allowed delete roles:

- Super Admin
- Treasurer
- Joint Treasurer

No other voucher status should be deleted.

## Notices

The notice board allows authorized admins to publish announcements.

Notices can include:

- Title
- Body text
- Attachment, where supported
- WhatsApp relay status, where configured

Members can view notices from the portal.

## Documents

### Member Documents

Members may upload their own documents.

Admins with verification authority can:

- View pending documents.
- Approve documents.
- Reject documents.

Seeded/admin-uploaded allotment documents are viewable when the stored document metadata points to the restored seed assets.

### Deleting Documents

Members may delete their own documents.

The admin member detail view does not expose document deletion. Portal document deletion remains available to the member.

If a member deletes the last verified allotment letter:

- The app warns the member.
- The account becomes inactive after deletion.
- Another allotment letter must be verified before activation can happen again.

Verified allotment letter deletion is blocked while the member has unresolved payment advice, because deleting it would deactivate the account during an active payment workflow.

## Admin Management

Super Admin can manage admin accounts.

Admin setup includes:

- Linking the admin account to a member.
- Assigning app role, such as admin or super admin.
- Assigning organizational role, such as Treasurer or General Secretary.
- Setting or resetting login credentials.

Admin permissions are based on both:

- App role
- Organizational role

## Settings

### Organization Settings

The society can manage:

- Society name
- Registration number
- Logo
- Phone number
- Email address

These details are used in the app and printable documents.

### Payment Gateway Settings

The app stores Razorpay-ready settings:

- Key ID
- Key Secret
- Webhook Secret
- Enabled/disabled state

For production, secrets should be managed securely through hosting provider secret storage or a dedicated secret manager.

### Payment Escalation Settings

The escalation matrix can define:

- Level 1 percentage/penalty
- Level 1 timing
- Level 2 percentage/penalty
- Level 2 timing
- Level 3 percentage/penalty
- Level 3 timing
- Days after last escalation before deactivation

### WhatsApp And Integrations

The app has settings for WhatsApp/Meta integration.

Current use cases include:

- Sending payment advice messages.
- Relaying notices.
- Preparing for future production messaging.
- Preparing WhatsApp OTP delivery.

WhatsApp OTP settings include:

- OTP enabled flag
- Template name
- Language code
- Button component type
- Button index
- OTP length
- Expiry minutes
- Resend wait seconds
- Maximum verification attempts

The WhatsApp integration modal is organized into Connection, Security, OTP, and Notes tabs.

Live WhatsApp OTP is not enabled yet because the Meta WABA review is still pending. The app should keep using mock verification for portal testing until the account is approved or an alternate provider is selected.

### Notifications

CivicSync has notification bells in both the admin workspace and member portal.

Notification rules:

- Portal notifications may include member-only actions such as paying dues.
- Admin notifications should not include actions that can only happen from the portal.
- Ordinary success/toast notifications auto-dismiss after 5 seconds.
- Account active/inactive messages are intentionally preserved instead of being auto-dismissed.

## Reports And Exports

The app supports exports for operational reporting.

Examples:

- Member export
- Financial export

Exports are intended for committee reporting, audit preparation, and reconciliation.

## Legacy Data Migration

CivicSync supports importing legacy society data.

Legacy migration can include:

- Members
- Users
- Documents
- Payment requests/advice
- Payment history

The goal is to keep old records visible while moving future operations into CivicSync.

## Important Validation Rules

### Member Validation

- Name is required and should not contain numbers.
- Phone number should be a valid 10-digit local number for India-oriented flows.
- Tower is required.
- Flat/unit must be numeric.
- Tower plus flat/unit should be unique among active, non-deleted members.
- Only Super Admin can change tower/unit.
- Only Super Admin can change login username.

### Activation Validation

A member cannot be activated unless:

- Allotment letter is verified.
- Phone is verified.
- No lapsed or reinstate-pending payment advice exists.
- Contact details and verified allotment letter deletion cannot be used to deactivate the account while payment advice is unresolved.

### Payment Advice Validation

- Reason/title is required.
- Amount must be greater than zero.
- Due date is required.
- Due date cannot be before today.
- Advice can be raised for eligible active members.
- Advice can also be raised for inactive members only when they have an unpaired lapsed advice that needs reinstatement.
- Paid advice cannot be deleted.
- Cancelled and pending advice can be deleted by authorized financial roles.
- A reinstate-pending advice must reference the specific lapsed advice it is meant to clear.

### Payment Validation

- Payment must relate to payable advice.
- Payable advice statuses are pending, escalation states, or reinstate pending.
- Cancelled advice cannot be paid.
- Paid advice should not be paid again.
- Lapsed advice is not paid directly. It is cleared only by paying the linked reinstate-pending advice.
- Razorpay payments must pass signature verification before being recorded as successful.

### Voucher Validation

- Voucher type is required.
- Amount must be greater than zero.
- Expense date is required.
- Assigned organizational role is required.
- At least one matching assignee is required.
- Only cancelled vouchers can be deleted.

### Document Validation

- Document type is required.
- File is required for upload.
- Only authorized roles can verify/reject documents.
- Removing the last verified allotment letter deactivates the member.

### Access Validation

- Super Admin has full operational access.
- Treasurer and Joint Treasurer can manage payment advice deletion/creation and cancelled voucher deletion.
- President and General Secretary can verify documents.
- Members can access only their own portal information.

### OTP Validation

The backend is prepared for OTP-based flows in four places:

- Login with mobile OTP.
- Forgot password.
- Mobile verification.
- Email verification through email OTP.

The final delivery provider can be WhatsApp Cloud API, Twilio, Gupshup, email SMTP, or another configured provider, but the business flows should remain provider-neutral.

## Recommended Operational Flows

### New Member Onboarding

1. Admin adds the member.
2. Member or admin adds contact details.
3. Contact is verified.
4. Member uploads allotment letter.
5. Authorized role verifies the allotment letter.
6. Super Admin activates the member.

### Payment Default Recovery

1. Member fails to pay through escalation levels.
2. Final escalation marks the old advice as lapsed and deactivates the member.
3. Treasurer, Joint Treasurer, or Super Admin raises a reinstatement payment advice.
4. The new advice is created as Reinstate pending and linked to the lapsed advice.
5. Member pays the reinstatement advice from the portal.
6. The advice becomes Reinstate paid and the linked lapsed advice is deleted automatically.
7. Super Admin activates the member after all gates pass.

### Voucher Cleanup

1. Voucher reaches cancelled status.
2. Super Admin, Treasurer, or Joint Treasurer deletes the cancelled voucher if it is no longer needed.
3. Non-cancelled vouchers remain protected.

### Document Risk Flow

1. Member deletes a verified allotment letter.
2. If no other verified allotment letter remains, the member is deactivated.
3. Member uploads a replacement allotment letter.
4. Authorized role verifies it.
5. Super Admin reactivates the member if all gates pass.

## Current Prototype Notes

Some features are intentionally prototype-ready rather than final production-ready.

Current prototype items:

- Mock contact verification is available until real OTP verification is fully connected.
- Mock payment is available for testing payment history and receipt flows.
- Local file storage is used for uploaded documents/logos.
- WhatsApp OTP settings exist, but live WhatsApp OTP delivery is waiting for Meta WABA approval.

Production work still recommended:

- Real OTP login, forgot password, mobile verification, and email verification.
- Live Razorpay flow and webhook hardening.
- Durable object storage for legal documents and logos.
- Secret encryption or managed secret storage.
- Full SaaS tenant deployment hardening.

## Glossary

- Active member: A member currently eligible for normal operations and new payment manifests.
- Inactive member: A member preserved in history but blocked from normal active workflows.
- Payment advice: A due/payment request raised against a member.
- Lapsed advice: A due that reached final escalation, failed pending payment attempts, and deactivated the member.
- Reinstate pending: A new payable advice linked to a lapsed advice for account reinstatement.
- Reinstate paid: A paid reinstatement advice that clears its linked lapsed advice and allows activation gates to be checked again.
- Escalation matrix: The rule set that increases/changes overdue payment states and can deactivate a member.
- Voucher: A society expense record that may need approval, printing, or deletion if cancelled.
- Soft delete: Hiding/removing a record from active operations while preserving history.
- Verified allotment letter: The key legal document needed for activation.

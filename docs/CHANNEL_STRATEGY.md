# CivicSync — Messaging Channel Strategy

**Status:** Accepted · **Date:** 26 Aug 2026 · **Supersedes** the SMS-first assumption in
`MESSAGING_COMPLIANCE.md` Part 1 · **Implemented in:** Packet 03 (`platform.messaging`)

## Decisions

1. **WhatsApp is the primary channel. TRAI DLT registration is deferred, not abandoned.**
2. **One WABA (Pivot Solutions), one shared template set, society passed as a parameter.**
3. **Per-society WABA is an enterprise-tier option**, added later via Meta's Tech Provider
   programme — the architecture supports both from day one.

---

## Part 1 — Skipping DLT

### Why this is the right call

You already hold a verified WABA. That single fact removes most of the argument for SMS:

| | WhatsApp Utility | SMS via DLT |
| --- | --- | --- |
| Setup | **Already done** | PEID + header + PE–TM binding + per-template approval, 1–4 weeks, ~₹5,900 |
| Cost per message | ~₹0.115 | ~₹0.12–0.25 |
| Length | 1,024 characters | 160, or **70** for any Unicode |
| Rich content | Buttons, PDFs, images, payment links | Text only |
| Onboarding a new society | Zero marginal work | Zero, but only after the platform registration exists |
| Delivery receipts | Sent / delivered / **read** | Delivered at best |
| Template fragility | Parameterised, forgiving | Byte-exact match; a curly quote breaks it |

WhatsApp is not merely the cheaper path here — it is the **better product**. A dues
reminder with a "Pay now" button and a PDF receipt attached is a materially better
experience than 160 characters of text, and it is what residents already expect from
MyGate and their bank.

### The one real risk, and how to close it without SMS

**WhatsApp-only creates a single point of failure on the login path.** If a resident
cannot receive the OTP, they cannot get into the app at all. And some residents in a
400-unit society genuinely will not have WhatsApp — elderly owners, feature phones, a
number registered to a relative.

Meta is also a single vendor on a critical path. It has changed WhatsApp pricing twice in
eighteen months and can restrict an account on quality grounds.

**Two fallbacks, neither requiring DLT:**

1. **Email OTP.** Free, no registration, and you need SMTP anyway. Covers anyone with an
   email address.
2. **Society-issued activation code.** The committee office generates a single-use code
   for a resident and hands it over in person or on a printed slip. Costs nothing,
   requires no third party, and every RWA has an office and a notice board. This is the
   fallback that covers the 78-year-old owner with a feature phone — and it is a better
   answer than SMS for that person anyway, because it is how the society already
   operates.

With those two in place, WhatsApp-only carries no unrecoverable failure mode.

### When to revisit SMS

Add DLT when any of these becomes true — not before:

- The pilot shows more than ~5% of residents cannot be reached on WhatsApp
- A society explicitly requires SMS in a contract
- WhatsApp quality rating problems make delivery unreliable
- Meta pricing moves enough to change the economics

Because `platform.messaging` is built around a provider-neutral `MessageChannel`
interface, adding SMS later is **an adapter and a configuration row** — no business logic
changes. That is what makes deferring safe rather than merely optimistic.

**Keep `MESSAGING_COMPLIANCE.md` Part 1.** The DLT research does not expire, and the day
you need it you will not want to redo it.

---

## Part 2 — Multi-tenancy on WhatsApp

You framed three options. There is a fourth, and it is the answer.

### The options

| | Approach | Verdict |
| --- | --- | --- |
| **A** | Each society gets its own WABA; you help them onboard | **Enterprise tier only** |
| **B** | Separate templates per society under your WABA | **No** |
| **C** | One template per action type, society as a parameter | **Yes — standard tier** |
| **D** | **C by default, A as an upgrade** | **This is the plan** |

### Why not B, even though the limits allow it

A **verified** WABA — which yours is — permits **6,000 templates**, not the 250 an
unverified one gets, at up to 100 created per hour. So eight templates × 100 societies =
800 is comfortably within limits.

It is still wrong:

- **Onboarding becomes gated on Meta's review queue.** Society 47 cannot receive a single
  message until its eight templates are approved — minutes usually, up to 48 hours
  sometimes, and occasionally rejected. Your onboarding SLA would depend on a queue you
  do not control.
- **Every wording change is 100 resubmissions.** Fix a typo in the dues reminder and you
  re-approve one template per society.
- **Quality is scored per template.** A hundred low-volume templates each accumulate weak,
  noisy signal instead of one template with strong history.
- **Nothing is gained.** The society's name can simply be a parameter.

### Why C is right

One set of templates. The society is a variable, exactly as templates are designed for.

```
Template: civicsync_dues_reminder  (Utility, en)

Hello {{1}},

Your maintenance for {{2}} at {{3}} is ₹{{4}}, due on {{5}}.

Outstanding balance: ₹{{6}}

— {{3}} via CivicSync

[Button: Pay now → https://app.civicsync.in/p/{{7}}]
```

`{{3}}` is the society's name. The sender display name is **CivicSync**, which is correct
— you are the platform, and the body attributes the society. Onboarding society 47 costs
one row in your database and zero seconds of Meta's time.

### The one thing that cannot be parameterised: OTP

Meta's **authentication template body is fixed** and not customisable:

```
<VERIFICATION_CODE> is your verification code.
```

You may add only a security disclaimer and an expiry line. **No society name, no branding,
no URL, no emoji**, and parameters capped at 15 characters.

So the resident sees a code from **CivicSync**. That is correct behaviour, not a
limitation — they are authenticating into CivicSync, not into the society. Do not fight
this; a template that tries to smuggle the society name into an authentication message
gets rejected.

### When a society earns its own WABA (Option A)

Legitimate reasons, all commercial rather than technical:

- It wants its own display name and its own number on residents' phones
- It wants **quality-rating isolation** — which also protects *you*, since one society's
  complaints currently affect all of them
- Its bye-laws or committee require it to own the communication channel

The mechanism is Meta's **Tech Provider** programme: the society completes its own Meta
business verification (a registered society has a registration certificate, so this is
feasible — just slow) and provides a dedicated phone number, then onboards its WABA
through **Embedded Signup inside your admin console**. The WABA belongs to them; you
operate it via API. This is precisely how MSG91 and every other BSP works, and you can
do it directly.

**Price it as an enterprise-tier feature.** The society bears the verification effort,
which is the natural filter for who actually wants it.

No schema change is needed. `service_integrations` is already org-scoped with
`whatsapp_phone_number_id` and `whatsapp_business_account_id`. A standard-tier society
has nulls there and falls back to the platform WABA; an enterprise society has its own.

---

## Part 3 — Webhook routing

Your question: how does the webhook know which society a message belongs to?

**It does not. You resolve it from your own state.** Meta's webhook carries the WABA ID,
the `phone_number_id` that received it, the sender's number, and the message id — never a
tenant identifier of yours.

Three cases, in resolution order:

```
resolveOrg(webhook) :=

  1. STATUS webhook (sent / delivered / read / failed)
     → look up wamid in notification_deliveries → org_id.
     Exact, always. You recorded the org when you sent it.

  2. INBOUND message, enterprise tier
     → phone_number_id maps to exactly one org via service_integrations → org_id.
     Exact.

  3. INBOUND message, shared platform number
     → look up the sender's phone in party_contacts
        · exactly one active org       → that org
        · more than one (owns flats in
          two societies)               → most recent conversation_session;
                                         if ambiguous, reply with a numbered menu
        · none                         → unknown sender: log, auto-reply with
                                         onboarding guidance, never guess
```

```sql
CREATE TABLE conversation_sessions (
    id            uuid PRIMARY KEY DEFAULT uuidv7(),
    org_id        uuid NOT NULL REFERENCES control.tenants(org_id),
    phone_e164    text NOT NULL,
    party_id      uuid REFERENCES parties(id),
    channel       text NOT NULL DEFAULT 'whatsapp',
    last_inbound_at  timestamptz,
    last_outbound_at timestamptz,
    window_expires_at timestamptz,   -- the 24h free-form service window
    UNIQUE (org_id, phone_e164, channel)
);
```

`window_expires_at` matters commercially: once a resident replies, you may send free-form
messages for 24 hours at **no cost**. Support conversations should ride that window
rather than burning utility templates.

Note that case 2 is *simpler* than case 3 — the enterprise tier is easier to route, not
harder. Another reason the hybrid model is comfortable.

---

## Part 4 — Template inventory for Release 1.0

Eight templates. That is the entire messaging surface.

| # | Template | Category | Notes |
| --- | --- | --- | --- |
| 1 | `civicsync_otp` | **Authentication** | Fixed body. Copy-code button. Used for login, password reset, contact verification |
| 2 | `civicsync_welcome` | Utility | Sent on activation. Society name, unit, portal link |
| 3 | `civicsync_dues_reminder` | Utility | Amount, due date, balance, **Pay now** button |
| 4 | `civicsync_payment_receipt` | Utility | Receipt number, amount, date; **PDF attached** |
| 5 | `civicsync_overdue_notice` | Utility | Dunning stage, penalty applied, consequence |
| 6 | `civicsync_announcement` | Utility | Title, summary, optional PDF, link to full notice |
| 7 | `civicsync_document_status` | Utility | Verified or rejected, with reason |
| 8 | `civicsync_visitor_alert` | Utility | *(Release 2.0 — register it now, it costs nothing)* |

Every one except #1 carries the society name as a parameter.

### Payment links

Meta supports a **dynamic URL suffix** on a URL button: the template stores
`https://app.civicsync.in/p/{{1}}` and you supply an opaque token. That token resolves to
`(org, invoice, party)` on your side, and your page then creates the Razorpay order
**against that society's own merchant account**.

The token must be single-use or short-lived and must not be guessable — it is effectively
a bearer credential to a payment page showing someone's dues. Use a random 22-character
token, not the invoice UUID.

This pattern also keeps the door open for SMS later: a fixed domain with a variable
suffix is exactly what DLT's URL-whitelisting rules require.

---

## Part 5 — Opt-in, consent and quality

### Opt-in

Meta requires opt-in before sending templates, and a society handing you 400 phone numbers
is **not** opt-in by Meta's standard.

- **Capture consent explicitly at resident onboarding**, in `party_contacts`, with a
  timestamp, the channel, and the wording shown. This satisfies Meta and it satisfies the
  DPDP Act, which needs the same record.
- **Prefer resident-initiated first contact** where you can — a "Message us on WhatsApp"
  link on the welcome slip opens a 24-hour window and establishes the relationship
  cleanly.
- **Per-category opt-out**, honoured per resident. Dues notices may be non-optional as a
  condition of the service; announcements must be opt-outable.

### Protecting the shared quality rating

Because all standard-tier societies share one rating, one society can damage
deliverability for every other. These are product controls, not policies:

- **Per-society daily send caps**, configurable, defaulting to something sane — so an
  enthusiastic secretary cannot broadcast four times in an evening
- **Per-resident frequency caps** across all categories
- **Everything Utility or Authentication.** No marketing templates to residents. Ever.
- **Quality rating monitored and alerted on** as a business metric
- **Throttle a society whose residents consistently complain** — and be prepared to have
  that commercial conversation

---

## Part 6 — Cost

At ~5 messages per resident per month — one dues reminder, one receipt, two
announcements, occasional OTP:

| Scale | Residents | Messages/month | Cost/month (incl. 18% GST) | Per unit |
| --- | ---: | ---: | ---: | ---: |
| Pilot | 370 | ~1,850 | **~₹250** | ₹0.68 |
| 10 societies | 4,000 | ~20,000 | ~₹2,700 | ₹0.68 |
| 100 societies | 40,000 | ~200,000 | **~₹27,000** | ₹0.68 |

**About ₹0.70 per unit per month** — roughly 2–4% of a ₹20–40 per-unit subscription. Not
a material cost, and a fraction of what SMS at the same volume would cost once
registration and Unicode segment inflation are counted.

Utility messages sent **inside** an open 24-hour service window are free, so real spend
will be below these figures.

---

## Part 7 — What Packet 03 must build

- `MessageChannel` interface with a **WhatsApp adapter** implemented, and **email** and
  **SMS** adapters stubbed behind the same interface
- `message_templates` — org-scoped, carrying provider template name, category, language,
  parameter schema, and the DLT fields left null for now
- `outbox` → dispatcher → `notification_deliveries`, recording `wamid`, status
  transitions and failures
- Webhook handler implementing the three-case `resolveOrg` above
- `conversation_sessions`, including the 24-hour window
- Consent capture on `party_contacts` and per-category opt-out
- Per-society and per-resident rate limiting, backed by Redis
- Quality-rating polling with an alert

The email adapter is not optional — it is the fallback that makes skipping DLT safe.

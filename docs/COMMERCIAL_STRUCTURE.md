# CivicSync — Who Registers What: Pivot Solutions vs the Society

**Status:** Accepted, with two items to confirm professionally · **Date:** 26 Aug 2026
**Related:** `MESSAGING_COMPLIANCE.md`, `MODULE_REGISTER.md`

## The short answer

| Registration | Whose | Why |
| --- | --- | --- |
| **Udyam / MSME, GST, PAN** | **Pivot Solutions** | Your business identity. Nothing to do with the society |
| **TRAI DLT** (SMS) | **Pivot Solutions**, as Principal Entity | Residents are CivicSync users; these are your service messages |
| **Meta WABA** (WhatsApp) | **Pivot Solutions** | Same reasoning; one verification instead of a hundred |
| **Razorpay / payment gateway** | **Each society, separately** | **Money must never touch your account.** This is the regulatory line |

The pattern: **messaging is platform-level, money is society-level.** Everything follows
from that one sentence.

---

## 1. Udyam / MSME — Pivot Solutions

Not really a question. It is your company's registration and it is what makes you a
registrable entity for DLT and verifiable for Meta. The society has its own registration
under the Societies Registration Act or a state Co-operative Societies Act, and that is
irrelevant to any of this.

Free, online, same day. **Do it first — everything else depends on it.**

---

## 2. DLT — Pivot Solutions as Principal Entity

### The regulatory distinction

TRAI's DLT framework separates two roles:

- **Principal Entity (PE)** — an organisation communicating with **its own customers**
- **Telemarketer (TM)** — a service provider sending SMS **on behalf of** other entities

If you registered as a PE and then sent messages that were plainly the *society's*
communications to the *society's* members, you would arguably be operating as an
unregistered telemarketer.

### Why Pivot is legitimately the Principal Entity

**Because the resident is your user.** They hold a CivicSync account, they accepted
CivicSync's terms, they log into your app, and the messages are about their account: an
OTP to sign in, a receipt for a payment made through your platform, a reminder about a
due shown in your app. That is a direct service relationship, and service messages within
it are your own communications.

This is also how comparable Indian platforms operate — MyGate and similar send under
their own header, not a per-society one.

**Three product conditions make this defensible, and they are cheap to build:**

1. **Residents accept CivicSync's own Terms of Service and Privacy Policy** at onboarding
   — not only the society's rules. Captured with a timestamp, in `parties`.
2. **Messages are Service Implicit in substance**, not just in category: about the
   resident's own account, dues, documents or access. Never marketing, never on behalf
   of a third party, never a society's promotional campaign.
3. **Every message identifies both** — "CivicSync · Mahira 63A WA" — so the recipient
   knows the platform and the society. Honest attribution is most of the compliance
   argument.

The alternative is unworkable anyway: a society will not complete a ₹5,900 DLT
registration, a PE–TM binding and template approvals as a condition of buying your
software. Requiring it would kill your sales motion at the first meeting.

### The escape hatch you already have

A large society may want its *own* header — "MAHIRA" rather than "CVCSYN" — for brand or
governance reasons. The schema already supports it: `message_templates` is org-scoped and
carries `dlt_header` and `dlt_template_id`. That society registers its own PEID, binds
MSG91 as its telemarketer, and its rows point at its own header.

**Build the platform header as the default in Release 1.0; expose per-society sender IDs
as an enterprise-tier feature later.** No schema change is needed — this decision was
already made correctly in `MESSAGING_COMPLIANCE.md`.

### Practical consequence

**One** PEID, **one** header, **one** set of templates, registered once by Pivot. Adding
society number 47 costs nothing and takes no time. That is the difference between a
product and a consulting engagement.

---

## 3. WhatsApp / WABA — Pivot Solutions

Same reasoning, and the same impossibility on the other path: Meta business verification
requires GST or incorporation documents, a dedicated phone number not on consumer
WhatsApp, and display-name approval. No RWA committee will do that.

One WABA under Pivot Solutions, display name **CivicSync**, one business verification.

### The concentration risk — take this seriously

Meta's quality rating is **per Business Portfolio**, and since October 2025 messaging
limits are portfolio-level too, so extra phone numbers do not add capacity. Practically:

> **One society's annoyed residents can damage deliverability for all of them.**

Three residents of one society marking your messages as spam moves your rating toward
yellow. Sustained, it blocks new template approvals — across every society you serve.

Mitigations, all of which are product decisions rather than paperwork:

- **Everything is Utility or Authentication.** No marketing templates, ever, to residents.
- **Per-society and per-resident send caps** in `platform.messaging`, so one society's
  over-enthusiastic secretary cannot blast 400 messages in an evening.
- **Easy opt-out** for non-critical categories, honoured per resident and per category.
- **Quality rating monitored** and alerted on. It is a business metric, not an ops one.
- **A society whose residents consistently complain gets throttled** — that is a real
  commercial conversation you should be prepared to have.

For an enterprise-tier society, a **dedicated phone number** under your WABA gives it a
separate display name. It does not give separate limits, but it does separate the brand.

---

## 4. Payments — each society, and this one is not negotiable

**Pivot Solutions must never receive residents' maintenance payments.**

### Why

Collecting funds from many payers and settling them to many businesses is, in RBI's
framing, **payment aggregation** — an activity that requires authorisation as a Payment
Aggregator under the RBI's PA/PG guidelines. A SaaS vendor pooling ten societies'
maintenance collections in its own Razorpay account and remitting them onward is doing
exactly that, without a licence.

It is also bad in three ordinary ways, quite apart from the licence question:

- **Tax.** Money landing in your account looks like Pivot's revenue. You would be
  arguing with a GST officer about ₹10 crore of flow-through that was never yours.
- **Liability.** You would be holding society funds. A dispute, a chargeback or a failed
  settlement becomes your legal problem, not the society's.
- **Trust.** "Your maintenance goes into the software vendor's bank account" is a
  sentence that loses you the deal in the committee meeting.

### The correct structure

**Each society holds its own Razorpay merchant account.** Money settles directly from
the resident to the society's own bank account. CivicSync orchestrates the payment and
records it; it never custodies a rupee.

The schema already does this: gateway credentials are **per-organization**, stored as
envelope-encrypted secrets with a per-org data key. That was the right call for security;
it turns out to be the right call for regulation too.

**Make onboarding painless by becoming a Razorpay Partner.** The partner programme lets
you generate merchant onboarding for each society, track their status, and typically earn
a share of transaction revenue — so you get an additional revenue line *and* an easier
onboarding flow, without ever touching the money. Ask Razorpay's partnerships team about
this before your second society.

### Where your own revenue comes from

Your subscription fee is a **separate, ordinary B2B transaction**: Pivot invoices the
society, the society pays Pivot. That money is legitimately yours and goes through your
own account. Keep the two flows completely distinct — different Razorpay accounts,
different ledgers, different invoices. Never net your fee out of collected maintenance;
that is the behaviour that turns a clean structure into an aggregation problem.

> **Confirm this with a chartered accountant or company secretary before your second
> society onboards.** I am confident about the principle and about industry practice; I
> am not your lawyer, and the PA/PG guidelines have been amended repeatedly. It is a
> one-hour conversation that protects the whole business.

---

## 5. Data protection — the society is the Fiduciary

Under the DPDP Act 2023:

- **The society is the Data Fiduciary.** Residents' personal data is collected for the
  society's purposes; it decides why and how.
- **Pivot Solutions is the Data Processor.** You process on the society's instructions.

This shapes several things:

- You need a **Data Processing Agreement** with each society. Write one template now; it
  becomes part of your standard contract and it is the kind of document that makes a
  committee take you seriously.
- **Erasure requests come through the society**, not directly from residents — though
  your product should let a society action one in a few clicks.
- **A breach requires you to notify the society**, which notifies the Data Protection
  Board.
- **Retention policy is the society's decision**, which is why it is configurable
  master data.

There is a tension worth being conscious of: you are the *Fiduciary* for the CivicSync
account relationship (login, T&Cs, service messaging) and the *Processor* for society
data (dues, documents, occupancy). Both are true simultaneously. Your privacy policy
should say so plainly rather than pretending it is simple.

---

## 6. Onboarding checklist for a new society

What this structure means in practice. Note how little of it is theirs.

**Pivot does once, ever:**

- [ ] Udyam / GST / PAN
- [ ] DLT: PEID, header, PE–TM binding, templates
- [ ] Meta: business verification, WABA, display name, templates
- [ ] Razorpay Partner registration
- [ ] Resident Terms of Service and Privacy Policy
- [ ] Data Processing Agreement template

**Per society, on onboarding:**

- [ ] Signed subscription agreement + DPA
- [ ] Society's **own Razorpay merchant account** (via your partner link) → credentials
      stored per-org, envelope-encrypted
- [ ] Society bank account verified for settlement
- [ ] Master data configured: blocks, unit types, charge heads, roles, document types
- [ ] Unit register imported and verified
- [ ] Committee roles assigned
- [ ] *(Enterprise tier only)* own DLT header, own WhatsApp number

**The society's paperwork burden is one contract and one Razorpay account.** That is the
whole point of putting the messaging registrations at platform level — and it is a
genuine competitive advantage over anything that asks a committee of volunteers to
complete a TRAI registration.

---

## 7. Open items to confirm professionally

| # | Question | Ask |
| --- | --- | --- |
| 1 | Confirm Pivot must not collect maintenance into its own account, and that per-society merchant accounts are the correct structure | Chartered accountant or company secretary |
| 2 | Razorpay Partner programme terms — onboarding flow, commission, whether societies can be onboarded as sub-merchants without you becoming the merchant of record | Razorpay partnerships |
| 3 | Whether sending under Pivot's DLT header for society-related service messages is accepted by your provider without a Telemarketer registration | `dlt-support@msg91.com`, in writing |
| 4 | DPA template and resident T&Cs / privacy policy | Lawyer familiar with DPDP |
| 5 | Whether your entity should be a sole proprietorship or a Private Limited before signing societies | CA — this affects liability, and societies handling crores may ask |

Item 5 is worth raising even though you did not ask. A committee signing a contract that
routes ₹1 crore a year of members' money through software will, sooner or later, ask who
they are contracting with. "Sidhant, personally" is a harder answer than "Pivot Solutions
Private Limited". Not urgent for the pilot; think about it before society number three.

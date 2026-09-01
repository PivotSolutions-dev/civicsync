# CivicSync — SMS (TRAI DLT) and WhatsApp (Meta WABA) Registration

**Status:** Action required · **Date:** 26 Aug 2026 · **Owner:** Sidhant
**Why now:** both are approval processes measured in weeks, neither depends on code, and
together they are the most likely cause of a launch that is otherwise ready but cannot
send an OTP.

---

## The two findings that change your plan

**1. You cannot use the DLT "Transactional" category.** It is restricted to banks and
RBI-approved wallets. Your OTPs and dues reminders go under **Service Implicit**, which
still bypasses DND and still delivers 24/7 — functionally identical for your purposes.
But registering headers or templates as "Transactional" gets them rejected.

**2. TRAI no longer permits individual DLT registration.** You need a registered
business entity. A **sole proprietorship qualifies**, but you must hold at least one of:
GST certificate, Shop & Establishment certificate, MSME/Udyam registration, or a trade
licence.

> **If you hold none of those today, get Udyam/MSME registration first.** It is free,
> online, and issued same-day — and the *same certificate* is accepted by Meta for
> business verification. One document unlocks both processes. This is step zero.

---

## Part 1 — TRAI DLT (for SMS via MSG91)

### The five stages

Most guides list four and omit stage 2, which is the one that silently breaks sending.

| # | Stage | Produces | Typical time |
| --- | --- | --- | --- |
| 1 | Principal Entity registration | PEID (19 digits) | 24–72 working hours |
| 2 | **PE–TM chain binding** | Link to MSG91's telemarketer | ~40 min + your approval |
| 3 | Header / Sender ID | 6-character sender ID | 24–48 hours |
| 4 | Content templates | One template ID per message | 24–48 hours per batch |
| 5 | Consent template | Only for promotional | — |

**Clean run: 3–7 working days. With one rejection cycle: 3–4 weeks.**

### Stage 2 is the one people miss

Mandatory since 11 December 2024. If your telemarketer is not approved on your DLT
portal, **every** SMS is rejected — OTP included. MSG91's telemarketer:

> **Walkover Web Solutions Pvt. Ltd — TM ID `1302157225275643280`**

DLT portal → PE-TM Chain → new chain request → add Walkover Web Solutions → submit
MSG91's approval form → approve the returned request.

### Which portal

Register on **SmartPing** (smartping.live) — MSG91's recommended platform, fastest
approvals. Put **"Referred by MSG91 (Walkover)"** in the remarks field.

Note: **PingConnect (Tanla) shut down its DLT operations on 8 October 2025** and
migrated everything to SmartPing. Any guide telling you to register there is stale.

Whether registration propagates to other operators is genuinely disputed across
sources — the practical consensus is that your PEID, headers and templates are visible
ledger-wide for scrubbing, so one registration suffices. Register on one; chase a second
only if you see operator-specific delivery failures. **PE–TM binding definitely does not
propagate** and must be redone if you ever change SMS vendor.

### Documents

- **PAN** — proprietor's individual PAN is fine for a sole proprietorship
- **Entity proof** — GST certificate, Shop & Establishment certificate, **Udyam/MSME**,
  Certificate of Incorporation, or trade licence
- **Letter of Authorisation** on letterhead (self-authorisation if you are the proprietor)
- **Photo ID** of the authorised signatory
- **Bank proof** — cancelled cheque or statement

**Pay from your registered business bank account.** Paying from a personal account while
registering a business entity is a rejection trigger. Scans must be flat, sharp, all
four corners visible — not angled phone photos.

### Fees

Sources conflict badly and TRAI publishes no schedule. **Budget ₹5,900 one-time**
(₹5,000 + 18% GST) for entity registration; some operators reportedly charge nothing, and
one 2026 source says Jio has made it an annual renewal. Headers and templates are free on
most portals. Scrubbing costs ~2.5 paise per SMS, passed through by MSG91. Verify at the
portal at signup rather than trusting any published figure.

### Header rules

- **Exactly 6 characters**, case-sensitive
- **Alphabetic** for Service Implicit — e.g. `CVCSYN` or `RWACON`
- Must visibly relate to your registered business name
- Operators auto-append a category suffix at delivery (`-S` for Service). You do not
  register this; recipients see e.g. `AD-CVCSYN-S`

### Template rules — including the big 2026 change

**Typed variable tags replaced the generic `{#var#}` placeholder.** New templates must
declare each variable's data type:

| Tag | Use |
| --- | --- |
| `{#numeric#}` | OTP, amounts |
| `{#alphanumeric#}` | Reference and receipt numbers |
| `{#url#}` | Links |
| `{#cbn#}` | Callback numbers |

Deadlines were 14 January 2026 for new templates with a 60-day migration grace period —
**both are past, so register everything with typed tags from day one.** Several
2026-dated guides still show `{#var#}`; they are stale. Worth a one-line confirmation
with `dlt-support@msg91.com` before you batch-submit, since this requirement has slipped
repeatedly since October 2024.

Other rules that cause rejections:

- **Maximum 2 variables, and they must not be adjacent** — fixed text between them
- **Never start or end a template with a variable**
- **Your brand name must appear in the body**
- **No double spaces**
- **URLs must be pre-whitelisted.** Shorteners like bit.ly are unusable. Put the domain
  in fixed text: `civicsync.in/r/{#alphanumeric#}`
- Each **language and script** needs its own template. Hindi in Devanagari and Hindi in
  Latin are two registrations. Unicode templates get 70 characters per segment, not 160
- Sample messages with realistic values are required at submission

### Two traps worth more than the rest of this section

**Smart quotes.** A word processor silently converts `'` to U+2019 and `-` to an en
dash. That forces Unicode encoding, cutting your segment from 160 to 70 characters — and
breaks the byte-match against the approved template, producing **status code 188** at
send time on a template that is approved. **Draft every template in a plain-text editor.
Never paste from Word or Google Docs.**

**The 160-character cliff.** An approved template is immutable. If your rendered message
lands at 161 characters, every message costs 2 credits forever. **Design to ~145
characters** to leave headroom, remembering each variable is accounted at 30 characters
regardless of its actual value.

### Your OTP template

No special OTP category exists for a non-bank. It goes under Service Implicit — which
delivers 24/7 and bypasses DND, so there is no functional disadvantage. Keep it clean:
`{#numeric#}` for the code, **no links** (RBI-adjacent convention), no promotional
wording anywhere near it.

### MSG91 onboarding

Your account starts in **DEMO** and can only send to demo content until **KYC is
complete** — do that first, it gates everything. Minimum wallet top-up ₹500. MSG91 sells
paid "DLT Premium Support" where an expert runs the registration for you; given this is
not your core work, **ask what it costs — it is probably worth it.**

---

## Part 2 — Meta WhatsApp Business Platform

### Sequence

1. Meta Business Account at business.facebook.com (owner access)
2. **Business verification** — Business Settings → Security Centre
3. WABA creation — via MSG91's Embedded Signup
4. Phone number registration + mandatory two-step PIN
5. Display name approval
6. Template creation and approval
7. Payment method

**The On-Premises API was deprecated in October 2025.** Cloud API only. Ignore any guide
about self-hosting.

**Total: 24–48 hours to live at the 250-user tier; 2–5 business days to a verified
2,000 tier.** Business verification is the long pole — 1–3 days clean, 7–14 if you have
to appeal.

### Verification documents (India)

Meta must confirm your **legal business name** (character-for-character identical to
your Business Manager entry) and your **address or phone**, ideally on one document.

Accepted for a sole proprietorship: **GST certificate**, Shop & Establishment
certificate, or **Udyam/MSME registration**. Address proof can also be a business bank
statement or utility bill in the business name, under 12 months old.

**The #1 rejection cause is a legal-name mismatch** between your Facebook Page, Business
Manager and documents. Trading name versus legal name will fail. Each rejection resets
the review clock.

### Phone number

- Must **not** be active on consumer WhatsApp or the WhatsApp Business app. If it is,
  delete that account first and wait for propagation
- Must receive SMS or a voice call for verification
- **Landlines and virtual numbers work** — but use **voice verification**, since SMS
  will not reach a longcode. MSG91 sells virtual numbers for exactly this
- Two-step PIN is mandatory and required for any later change

**Use a dedicated number.** Do not use your personal number or a number the society uses.

### Templates

Three categories: **Marketing**, **Utility**, **Authentication**.

Everything CivicSync sends — dues reminders, receipts, AGM notices, maintenance alerts —
is legitimately **Utility**. This matters commercially:

| Category | India rate (Jan 2026) |
| --- | --- |
| **Utility**, outside the 24h window | **~₹0.115** |
| **Utility**, inside an open service window | **Free** |
| **Authentication** (OTP) | **~₹0.115**, charged every time even inside the window |
| **Marketing** | **₹0.8631** |
| Service replies inside 24h | Free |

**One promotional sentence in a Utility template flips it to Marketing — a 7.5× cost
increase.** Since April 2025 Meta silently *auto-approves* a mis-categorised Utility
template *as Marketing* rather than rejecting it, with a 60-day appeal window. So the
failure is expensive and quiet. Keep utility templates surgically clean.

Add 18% GST on top of Meta's charges and any MSG91 markup.

**Authentication template body is fixed** and not customisable: `<VERIFICATION_CODE> is
your verification code.` You may add a security disclaimer and an expiry line. No URLs,
no media, no emojis; parameters capped at 15 characters.

**India billing note:** direct INR billing is supported, but a USD-billed account
**cannot be converted** — you must create a new one. Get this right at signup.

### Messaging limits

| Tier | Unique recipients / 24h |
| --- | --- |
| Start | 250 |
| Tier 1 | 2,000 — on business verification |
| Tier 2 | 10,000 |
| Tier 3 | 100,000 |
| Tier 4 | Unlimited |

Escalation above 2,000 is automatic: quality rating Medium or High, *and* you used ≥50%
of your limit in the last 7 days.

**Since October 2025 limits apply at the Business Portfolio level, not per phone
number** — adding numbers does not add capacity. The old workaround is dead.

Quality rating is recalculated over a rolling 7-day window from blocks, spam reports and
engagement. A red rating blocks new template approvals. At 100 societies × ~400 units
you will be sending to tens of thousands of residents who did not choose your product —
**keep everything Utility, never buy or infer opt-in, and make unsubscribe easy.** One
society's angry residents can damage the sending reputation for all of them.

### BSP versus direct Cloud API

Use **MSG91 as your WhatsApp BSP**. Meta's message fees are identical either way; the
difference is that direct Cloud API means building the webhook handler, template
management, retries and media handling yourself — 2–6 weeks of engineering against
24–48 hours.

Crucially, with Embedded Signup the **WABA is registered under your own Meta Business
Portfolio**, not MSG91's. You can migrate to another BSP or to direct Cloud API later
without losing your number, templates or quality history. That makes it the low-regret
choice, and it consolidates KYC, billing and support with the vendor you already need
for SMS.

**Ask MSG91 for their per-message markup on utility and authentication specifically, and
whether there is a platform subscription on top.** Meta's fee is fixed; the markup is
where the variance is, and it is not published.

---

## Action order

Do these in this sequence — the dependencies are real.

| # | Action | Blocks |
| --- | --- | --- |
| 0 | **Udyam/MSME registration** if you have no GST or Shop Act certificate. Free, same day | Everything |
| 1 | **Start Meta business verification.** Longest pole, runs in the background | WhatsApp tier 1 |
| 2 | MSG91 account + **complete KYC**, top up ₹500 | All sending |
| 3 | **PEID on SmartPing**, "Referred by MSG91 (Walkover)" in remarks, paid from your business account | Stages 2–4 |
| 4 | **PE–TM binding** to Walkover Web Solutions `1302157225275643280` | All SMS |
| 5 | Register one **Service Implicit alphabetic header**, 6 letters | Templates |
| 6 | **Draft templates in a plain-text editor**, typed variable tags, ≤2 non-adjacent variables, brand name in body, ~145 characters, whitelisted domain. Batch-submit | Sending |
| 7 | WhatsApp: **dedicated number**, display name identical to your legal/brand name, Utility + Authentication templates with zero promotional language | Sending |
| 8 | Set **INR billing** on Meta at signup — cannot be changed later | Cost |

**Realistic total: 5–10 working days clean; 3–4 weeks if documents bounce once.**

Start now. None of it needs code, and all of it can run while you build Packets 00–03.

---

## What this means for the code

The compliance model shapes the `platform.messaging` design in Packet 03:

- **Every SMS template is a registered artefact with a DLT template ID.** The
  `message_templates` table stores `dlt_template_id`, `dlt_header`, category, the exact
  registered body, and the typed variable list. Sending renders against the stored body
  and **must byte-match** — a mismatch is status 188.
- **A CI check compares rendered output to the registered template body**, so an
  innocent copy edit cannot break sending in production.
- **Templates are org-scoped master data**, because each society may eventually register
  its own header under its own entity. Ours is the default.
- **WhatsApp template category is stored and enforced**, so a Utility template that grows
  a promotional line fails review rather than silently costing 7.5×.
- Channel selection is provider-neutral: `MessageChannel` with MSG91, Meta and SMTP
  adapters, per the anti-corruption layer rule in the architecture document.

---

## Open items — verify before committing

These came back contradictory or unconfirmed. None blocks starting; all are worth a
direct question to MSG91 support.

1. **Current DLT fee schedule.** ₹5,900 is the safest budget, but several sources claim
   entity registration is free on some operators and one says Jio now charges annually.
2. **Whether headers cost ₹590/year.** One source says yes; most say free.
3. **Whether the 14 January 2026 typed-variable enforcement actually landed** or slipped
   again. Confirm with `dlt-support@msg91.com` before batch-registering.
4. **Whether DLT registration truly propagates across operators.** Sources directly
   contradict each other.
5. **MSG91's WhatsApp per-message markup and platform fees.** Not published.
6. **MSG91's stated display-name condition** ("≥1,000 messages/24h and 30 days of
   high-quality campaigns") conflicts with Meta's own docs. Likely applies to a display
   name differing from your legal name — avoid the question by making them identical.
7. **Whether the TRAI/RBI Digital Consent Acquisition platform went live** for non-bank
   entities after its February 2026 pilot target.

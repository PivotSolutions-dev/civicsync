# CivicSync — Payment Collection Strategy

**Status:** Accepted · **Date:** 26 Aug 2026 · **Revision 2**
**Supersedes** the assumption in `COMMERCIAL_STRUCTURE.md` §4 that a payment gateway is
the default collection mechanism. The regulatory conclusion there — money settles to the
society, never to Pivot — is unchanged and applies with more force here.
**Implemented in:** Packets 08–09, with the gateway adapter in Release 1.1.

---

## 1. The decision

**Zero-cost UPI is the default collection method. A payment gateway is optional,
per-society, and deferred to Release 1.1 — but the platform is built to accept one
without redesign.**

Small RWAs will not pay 2% to collect their own members' money, and they are right not
to. A product that requires them to is a product they will decline.

---

## 2. Why zero cost is real, not a workaround

**UPI has no MDR.** Section 10A of the Payment and Settlement Systems Act, 2007 barred
charges on UPI and RuPay debit transactions from 1 January 2020. Money moving from a
resident's bank to the society's bank over UPI costs nothing, to either side.

**The "2%" quoted by payment gateways is their own platform fee**, not a regulatory cost
and not something the rails require. Removing the intermediary removes the fee entirely.
Say this explicitly to a committee — most have been told the 2% is unavoidable.

**The bank is likely selling the wrong product.** A fixed annual charge plus MDR is a
*merchant/POS package*. To receive UPI credits a society needs a **VPA on its existing
current account**, generally free. The instruction to give a treasurer is precise:
*"We want a UPI VPA on our current account to receive payments. We do not want a merchant
or POS package."*

### The August 2026 amendment — watch, do not plan around

On 8 August 2026 the Lok Sabha passed the **Taxation and Other Laws (Amendment) Bill,
2026**, amending the PSS Act to permit fees on UPI and RuPay debit payments. The framing
is explicitly for **large merchants above a turnover threshold** — figures under
discussion are ₹1–1.5 crore — with small merchants exempt.

An RWA collecting ₹4–5 lakh a year is far below any threshold discussed. **Re-check when
the rules are notified**; do not design around a fee that does not apply.

---

## 3. What a gateway actually sells a small RWA

Not the payment rails, which are free. **Reconciliation** — automatically knowing who
paid, how much, against which invoice.

A static QR does not solve that. It produces 370 credits in a bank statement with no
reliable link to a member or an invoice, leaving the treasurer doing by hand exactly the
work software should do.

**The design question is not "how do we collect?" but "how do we reconcile at zero
cost?"**

---

## 4. The mechanism

### 4.1 Dynamic per-invoice UPI

Per intent, CivicSync generates a UPI URI with the **amount locked**:

```
upi://pay
  ?pa=societyvpa@bank          payee VPA, from society settings
  &pn=Mahira%2063A%20WA        payee name
  &am=1000.00                  locked — prevents underpayment
  &cu=INR
  &tn=CS7K2M9A                 our short reference
```

Rendered two ways from the same URI:

- **Mobile** — a "Pay via UPI" button that opens the resident's UPI app directly (GPay,
  PhonePe, Paytm, BHIM). One tap, no card details, no redirect.
- **QR** — for desktop, WhatsApp, a printed notice, the society notice board.

### 4.2 The reported-payment state

```
issued → payment_reported → settled
                          ↘ rejected (mismatch, duplicate, not found)
```

After paying, the resident supplies the **12-digit UTR**. The invoice moves to
`payment_reported` — **not** settled.

> **An invoice is never settled on the resident's assertion alone.** `payment_reported`
> carries a claim, not a payment. Only a matched bank credit produces a receipt and a
> ledger entry. This is what protects the ledger, and it is why ADR-0003 made money
> append-only and derived rather than a status someone sets.

### 4.3 Reconciliation

The treasurer imports a bank statement (CSV or Excel). CivicSync:

1. Parses credits, extracting UTR, amount and value date
2. **Matches on UTR + amount + date.** A reported payment with a matching credit
   auto-settles
3. Surfaces exceptions in a reconciliation console:
   - Credit with no reported payment → treasurer assigns it
   - Reported payment with no credit → flagged, chased, rejected after a grace period
   - Amount mismatch → partial allocation or rejection
   - Duplicate UTR → rejected automatically
4. On settlement: receipt from `number_series`, ledger entry,
   `finance.payment.received` emitted

**Match on UTR, amount and date — never on the transaction note.** Bank narration for UPI
credits varies; some carry the note, some do not. `tn` is a convenience for the payer, not
a key.

### 4.4 Refunds

No automatic refund on this path. A refund is a **manual bank transfer by the society**,
recorded as a reversing ledger entry with the outbound UTR attached. Model it properly —
societies do refund duplicate payments.

### 4.5 Payment intents — the data model

A member can owe two things at once, each needing its own amount. The unit is therefore a
**payment intent**, normally one per invoice, optionally covering several.

```sql
CREATE TABLE payment_intents (
    id              uuid PRIMARY KEY DEFAULT uuidv7(),
    org_id          uuid NOT NULL REFERENCES control.tenants(org_id),
    unit_account_id uuid NOT NULL REFERENCES unit_accounts(id),
    payment_mode_id uuid NOT NULL REFERENCES payment_modes(id),

    token           text NOT NULL,          -- 22-char random; addresses the pay page
    reference       text NOT NULL,          -- short human code, e.g. CS7K2M9A
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    currency_code   char(3) NOT NULL DEFAULT 'INR',
    expires_at      timestamptz NOT NULL,

    status          text NOT NULL DEFAULT 'created'
                      CHECK (status IN ('created','initiated','reported',
                                        'confirmed','settled','expired','cancelled','failed')),

    -- provider fields: NULL for plain UPI, populated by a gateway or bank collect API
    provider            text,
    provider_ref        text,               -- e.g. a Razorpay order id
    provider_payload    jsonb,
    confirmation_source text CHECK (confirmation_source IN
                          ('statement_match','provider_callback','manual')),

    -- spine …
    UNIQUE (org_id, token),
    UNIQUE (org_id, reference)
);

CREATE TABLE payment_intent_lines (
    payment_intent_id uuid NOT NULL REFERENCES payment_intents(id) ON DELETE CASCADE,
    invoice_id        uuid NOT NULL REFERENCES invoices(id),
    amount            numeric(14,2) NOT NULL,
    PRIMARY KEY (payment_intent_id, invoice_id)
);
```

**Note what this table already is: a gateway order.** A Razorpay order id is just another
`provider_ref` on the same row. Adding a gateway later introduces no new concept — it
populates columns that are null today. That is the point of designing it now.

**Two behaviours that matter more than they look:**

**Intents expire.** If dunning escalates an invoice from ₹1,000 to ₹1,150, a QR generated
last month still says ₹1,000. A resident pays the stale amount in good faith and now you
have a partial payment and an annoyed member. Seven-day expiry, regenerated on demand.

**A QR can be scanned twice.** Two credits, two UTRs, one intent — an overpayment. It must
surface as a reconciliation exception and become a refund or an account credit. Not an
edge case; it will happen.

### 4.6 Four identifiers, and only one of them matches

Conflating these is where reconciliation bugs come from.

| Identifier | Generated by | Visible where | Purpose |
| --- | --- | --- | --- |
| `payment_intents.id` | Us | Database only | Internal |
| `token` | Us | The URL | Addresses the payment page. Random, single-purpose, not guessable |
| `reference` (`CS7K2M9A`) | Us | UPI note `tn`, and shown to the resident | Human cross-check |
| **UTR / RRN** (12 digits) | **NPCI** | Resident's UPI app **and** the society's statement | **The matching key** |
| `provider_ref` | Provider | Gateway dashboard | Gateway paths only |

Only the UTR appears on both sides of a UPI payment. Keep `reference` short and
alphanumeric — some PSPs truncate the note field, and matching must never depend on a
field that might arrive clipped.

`receipts.external_ref` stores the UTR for UPI and the provider payment id for a gateway,
uniformly — so downstream code does not branch on method.

---

## 5. Payment modes are master data

Every society configures which modes it accepts.

| Mode | Cost | Confirmation | Notes |
| --- | --- | --- | --- |
| `upi_qr` | **Zero** | Resident reports UTR → statement match | Default |
| `bank_transfer` | Zero | Statement match on reference | NEFT/IMPS, for large payers |
| `cash` | Zero | Treasurer records | Unavoidable. Members will hand over an envelope |
| `cheque` | Zero | Treasurer records, then clears | Needs cleared/bounced states |
| `upi_collect` | Zero MDR | **Provider callback** | Bank collect API — see §6.1 |
| `gateway` | Provider's fee | Provider callback | Release 1.1 |
| `legacy_import` | — | — | Migration only, for the 955 historical receipts |

```sql
payment_modes (id, org_id, code, name, is_system, is_active,
               requires_reconciliation, auto_confirms, provider,
               sort_order, attributes)
```

**Cash and cheque are not an afterthought.** A system that cannot record a cash payment
forces the treasurer into a parallel spreadsheet — at which point your ledger is no longer
the source of truth.

---

## 6. Acknowledgement — the honest position

### 6.1 UPI's rails provide none. Acknowledgement is a service you buy.

The payer's app knows immediately. The society's *bank* knows immediately. A third-party
system learns about it only if someone is contractually obliged to tell it. **That
obligation is what a payment gateway sells** — not the movement of money, which is free.

| Setup | Server-to-server acknowledgement | Cost |
| --- | --- | --- |
| **Plain VPA on a current account** *(Release 1.0)* | **No.** Statement, SMS or app notification only | Zero |
| **UPI merchant with a bank collect API** — ICICI Eazypay, HDFC SmartHub, Axis, Yes Bank | **Yes.** Webhook on success with merchant ref and UTR. Also enables payee-initiated collect requests | **Zero MDR**, but bank onboarding and sometimes an annual fee |
| **Payment gateway** — Razorpay, Cashfree, PhonePe PG | Yes | Platform fee |

The middle row matters: **gateway-grade acknowledgement at zero MDR** is available to any
society willing to onboard as a UPI merchant with its own bank. That is the natural
upgrade for a society that finds statement reconciliation tedious, and under §7 it is an
adapter, not a redesign.

### 6.2 One free improvement, Android only

The UPI Deep Linking specification means an **Android** app launching a UPI intent
receives a response — transaction id, response code, approval reference, status. So in the
Flutter app, an Android resident pays and the UTR is captured automatically.

**iOS returns nothing.** Custom URL schemes have no mechanism to return status, and iOS
cannot even report which UPI app was opened. iOS and web require manual UTR entry.

Even on Android, treat the response as an **assertion, not proof** — it is client-side and
spoofable. It auto-fills the UTR and moves the intent to `reported`; the statement match
still decides. It removes the typing, not the verification.

Release 1.1 benefit, since it needs the native app.

### 6.3 Constraints to accept

| Constraint | Consequence |
| --- | --- |
| **VPA must be on the society's current account** | Not a treasurer's personal account. Governance, audit, and probably the bank's terms |
| **UPI per-transaction limit** (~₹1 lakh) | Irrelevant at ₹1,000–5,000. For a large one-off levy, fall back to `bank_transfer` |
| **Confirmation is not instant** | UI says "payment reported, pending verification". Do not imply instant settlement |
| **Depends on the treasurer** | If nobody imports the statement, nothing settles. Mitigate with a reminder job and an unreconciled count on the dashboard |
| **No chargeback protection** | Irrelevant. A society collecting from its own members has no chargeback exposure |
| **False or reused UTRs** | Validate format, reject duplicates, flag repeat offenders |

---

## 7. Gateway readiness

The goal is that adding Razorpay — or a bank collect API, or PhonePe, or whatever exists
in 2029 — is **one adapter and one configuration row**, touching no domain logic, no
ledger code and no UI.

### 7.1 The port

Per `ARCHITECTURE_DDD.md` §6, the domain owns the interface and the provider's vocabulary
stays in the adapter. Capabilities are separate small interfaces, so an adapter implements
only what it can do — idiomatic Go, and it stops us pretending cash supports refunds.

```go
// domain/finance

type Capabilities struct {
    Initiates         bool // can produce a payable artefact (link, order, QR)
    AutoConfirms      bool // tells us server-to-server
    SupportsRefund    bool
    SupportsMandate   bool // recurring / UPI AutoPay
    RequiresReconcile bool // needs statement matching
}

type CollectionProvider interface {
    Code() string
    Capabilities() Capabilities
}

type PaymentInitiator interface {          // optional
    Initiate(ctx context.Context, in PaymentIntent) (InitiationResult, error)
}

type PaymentConfirmer interface {          // optional
    VerifyCallback(ctx context.Context, raw []byte,
                   headers map[string]string) (ConfirmationResult, error)
}

type PaymentRefunder interface {           // optional
    Refund(ctx context.Context, r Receipt, amt Money, reason string) (RefundResult, error)
}

type StatementSource interface {           // optional — reconciliation-based methods
    FetchCredits(ctx context.Context, from, to time.Time) ([]BankCredit, error)
}
```

Every provider maps into the same domain-level results, so nothing downstream branches on
who processed the payment:

```go
type InitiationResult struct {
    ProviderRef string    // order id, collect request id — empty for plain UPI
    PayURL      string    // upi:// URI, or a hosted checkout URL
    QRPayload   string
    ExpiresAt   time.Time
}

type ConfirmationResult struct {
    ProviderRef string
    ExternalRef string    // UTR for UPI, payment id for a gateway
    Amount      Money
    PaidAt      time.Time
    Status      PaymentStatus
    Fee         Money     // provider fee, if any — see §7.4
    Raw         []byte
}

type BankCredit struct {
    UTR       string
    Amount    Money
    ValueDate time.Time
    Narration string
}
```

The plain-UPI implementation is a `CollectionProvider` + `PaymentInitiator` that builds a
URI string. It implements nothing else. That is the whole adapter.

### 7.2 Build in Release 1.0, even with no gateway

Four things are cheap now and awkward to retrofit. Everything else waits.

| Build now | Why it cannot wait |
| --- | --- |
| **`payment_intents` with nullable provider columns** (§4.5) | Adding provider fields later means backfilling and reworking every query |
| **Generic inbound-callback pipeline** | Signature verification, idempotency and replay protection are the fiddly parts. Building them once, unused, is half a day; retrofitting them under time pressure when a society is waiting is not |
| **Provider fee modelling in the ledger** (§7.4) | If the ledger cannot express "₹1,000 received, ₹20 fee", the books do not balance the day a gateway arrives |
| **Provider conformance test suite** (§7.5) | Writing the contract while there is one implementation is easy; deriving it from two is not |

**Deliberately not built now:** hosted checkout UI, settlement reconciliation, mandates
and AutoPay, multi-currency, split settlement. Adding a gateway is a *reversible* door
(`PLATFORM_ENGINEERING_STANDARDS.md` §16) — pay only for the parts that are genuinely hard
to undo.

### 7.3 The callback pipeline

```sql
CREATE TABLE provider_callbacks (
    id              bigint GENERATED ALWAYS AS IDENTITY,
    org_id          uuid NOT NULL,
    provider        text NOT NULL,
    event_id        text,               -- provider's event id, for idempotency
    payload         jsonb NOT NULL,
    headers         jsonb NOT NULL,
    signature_valid boolean NOT NULL DEFAULT false,
    received_at     timestamptz NOT NULL DEFAULT now(),
    processed_at    timestamptz,
    processing_error text,
    PRIMARY KEY (id, received_at)
) PARTITION BY RANGE (received_at);

CREATE UNIQUE INDEX ON provider_callbacks (org_id, provider, event_id)
    WHERE event_id IS NOT NULL;
```

Endpoint pattern `/webhooks/payments/{provider}`, resolving the adapter from a registry.
Rules, all provider-agnostic:

- **Persist the raw body before doing anything else.** A callback you failed to parse must
  still be replayable.
- **Verify the signature in the adapter**, never in shared code.
- **Idempotent on the provider's event id.** Providers retry; duplicates are normal.
- **Reject stale timestamps** to prevent replay.
- **Process asynchronously** via River. Respond `200` fast; providers time out and retry.

Packet 03 already builds *outbound* webhooks with HMAC signing, retries and a delivery
log. This is the mirror image and shares most of that machinery.

### 7.4 Provider fees in the ledger

A gateway that takes ₹20 on a ₹1,000 payment settles ₹980. If the ledger records ₹980, the
invoice never clears and the books are wrong.

Correct treatment, and it must be possible from Release 1.0:

```
Receipt ₹1,000 against invoice
  ledger: credit  unit_account          ₹1,000
  ledger: debit   bank                    ₹980
  ledger: debit   payment_processing_fee   ₹20
```

Requires only a seeded `payment_processing_fee` charge head and a `fee` field on
`ConfirmationResult`. Both trivial now, both painful to introduce after a year of
receipts exist.

### 7.5 The conformance suite

A shared test suite every adapter must pass. This is what "ready for future integration"
means concretely — not an abstraction, an executable contract.

```
TestProvider_Conformance(t, provider)
  ├── capabilities are self-consistent
  │     (AutoConfirms ⇒ implements PaymentConfirmer, etc.)
  ├── Initiate returns a usable artefact and a future expiry
  ├── Initiate is idempotent for the same intent
  ├── VerifyCallback rejects a tampered signature
  ├── VerifyCallback rejects a replayed event id
  ├── VerifyCallback maps amount and currency exactly (no float drift)
  ├── a confirmed callback produces exactly one receipt
  ├── a duplicate callback produces no second receipt
  ├── Refund produces a reversing entry, never a delete
  └── an unsupported capability returns ErrUnsupported, never a panic
```

The plain-UPI provider runs against this suite in Release 1.0. When the Razorpay adapter
lands, it either passes or it is not finished.

### 7.6 Configuration

```sql
payment_providers (id, org_id, provider_code, display_name, enabled,
                   mode /* test | live */, config jsonb, capabilities_override jsonb)
```

Credentials live in `org_secrets`, envelope-encrypted with the society's own data key
(`PLATFORM_ENGINEERING_STANDARDS.md` §7), and are **never returned by any API** — the
admin UI shows `configured: true` and a "replace" action.

Settlement is always to **the society's own merchant account**, never Pivot's
(`COMMERCIAL_STRUCTURE.md` §4). That constraint does not relax because a gateway is
involved; it is the reason per-org credentials exist.

### 7.7 One thing deliberately left open

**`confirmed` and `settled` are not the same event for a gateway.** A card payment is
confirmed instantly and settles to the society's bank at T+2, net of fees, batched with
other payments. UPI confirms and settles together, so Release 1.0 can treat them as one.

The `status` enum already distinguishes them. **Settlement reconciliation — matching a
provider's payout batch to the individual payments inside it — is not built in Release
1.0.** Note it here so that when a gateway arrives, nobody assumes `confirmed` means the
money is in the bank.

---

## 8. Why this is a commercial advantage

MyGate and comparable platforms push payment gateways because they earn on the flow. You
sell software, so you can afford to save each society 2% — on ₹4.5 lakh that is ~₹9,000 a
year, a meaningful line item for a small RWA and an easy thing to say in a sales meeting.

> *"Collect through UPI at zero cost. We reconcile it for you. And if you ever want a
> gateway, it's a switch."*

That last clause is only credible because of §7. It also aligns with
`COMMERCIAL_STRUCTURE.md` §4: you never touch the money, which removes both the
regulatory exposure of aggregation and the objection that the software vendor takes a cut
of members' funds.

---

## 9. Impact on the build

### Packet 08 — Finance I

- `payment_modes` master table, seeded with the seven modes in §5
- `payment_providers` table; society UPI settings (`finance.upi_vpa`,
  `finance.upi_payee_name`, `finance.upi_enabled`)
- `payment_processing_fee` charge head seeded (§7.4)
- Invoice gains the `payment_reported` state

### Packet 09 — Finance II *(revised: 12 days → ~9)*

| In | Out |
| --- | --- |
| `payment_intents` + lines, with provider columns nullable | ~~Razorpay order creation~~ |
| UPI intent URI and QR generation | ~~Razorpay webhook handling~~ |
| Reported-payment flow, UTR capture and validation | ~~Signature verification for a live provider~~ |
| Bank statement import, per-bank parser profiles | ~~Settlement reconciliation~~ |
| Auto-matching on UTR + amount + date | |
| Reconciliation console, four exception types | |
| Cash and cheque, with cheque clearing states | |
| Manual refunds as reversing entries | |
| **`CollectionProvider` port + plain-UPI implementation** | |
| **`provider_callbacks` pipeline, unused but tested** | |
| **Conformance suite, with plain UPI passing it** | |
| Dunning policies and the escalation job *(unchanged)* | |

Roughly one extra day for the port, pipeline and conformance suite. Worth it.

### Release 1.1

- Razorpay adapter: orders, checkout, webhooks, signature verification, refunds
- Android auto-capture of the UPI response in the Flutter app (§6.2)
- Settlement reconciliation, if a gateway is actually in use

### Statement parsers

Each bank formats statements differently. Build **one parser profile for the pilot
society's bank**, behind an interface, with a mapping UI so a new bank is configuration
rather than code. Do not support twelve banks speculatively.

---

## 10. To confirm before Packet 08

1. **Does the society's bank permit a UPI VPA on their current account without a merchant
   package, at no charge?** The whole design rests on this.
2. **What statement formats does that bank export?** CSV, Excel, PDF-only? PDF-only makes
   auto-matching materially harder and changes the estimate.
3. **Does the UPI credit narration include the UTR?** Confirm with a real ₹1 test
   transaction and a downloaded statement. Also check whether the bank sends an SMS or
   email per credit — a useful interim signal for the treasurer.
4. **Who on the committee will import statements, and how often?** The design assumes a
   treasurer doing this weekly in collection season. If nobody will, the reminder job and
   dashboard prominence matter more than the matching algorithm.

Item 3 is worth doing this week — it costs ₹1 and settles the core mechanism.

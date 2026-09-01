# CivicSync v2 — Architecture & Domain Model

**Status:** Accepted · **Date:** 26 Aug 2026 · **Governs:** package layout, aggregate
boundaries, transaction scope and naming.

## Is this DDD?

Yes — **pragmatic Domain-Driven Design**, deliberately not the full canon.

DDD is two things: *strategic* patterns (bounded contexts, ubiquitous language, context
mapping) and *tactical* patterns (aggregates, entities, value objects, repositories,
domain services, domain events, factories, specifications). Strategic DDD is where
almost all the value is, and it is cheap. Tactical DDD is where projects drown in
ceremony, and a solo developer cannot afford that.

**We adopt in full:** bounded contexts, ubiquitous language, aggregates with enforced
invariants, domain events, repositories, value objects, application services, and
anti-corruption layers around external providers.

**We deliberately reject:** event sourcing, CQRS as a default, dependency-injection
frameworks, abstract factories, the specification pattern, and one-file-per-tiny-class
Java-isms. These solve problems we do not have and cost velocity we cannot spare.

The `DOCS/MODULE_REGISTER.md` you already have *is* the strategic layer — each module is
a bounded context. This document is the tactical layer.

---

## 1. Ubiquitous language

The prototype's vocabulary is the root of several of its modelling problems. "Member"
means, variously, a person, a flat, an account, a login and a role. That ambiguity is
exactly what produced `members.tower + flat_no` as an identity.

v2 uses precise model terms internally, and shows the society's own words in the UI.
**Both are correct in their place** — DDD says use the domain expert's language, and
the domain expert says "member". So the UI label is master data, and the model is exact.

| Society says | Model term | Definition |
| --- | --- | --- |
| Society, association, RWA | **Organization** | The tenant. One society |
| Tower, block, wing | **Block** | A physical building or cluster within a society |
| Flat, unit, shop | **Unit** | An addressable property. Has a type (residential/commercial) |
| Member, resident, owner, tenant | **Party** | A person. Exists independently of any unit |
| Owner, joint owner, co-owner | **Ownership** | Legal title: a Party's share in a Unit over a period. See `REGISTRY_OWNERSHIP_MODEL.md` |
| Resident, occupant, tenant | **Occupancy** | Who physically lives in a Unit over a period. **Independent of ownership** |
| Member (co-op society sense) | **Association Membership** | Standing in the society: voting rights, committee eligibility, share certificate |
| — | *(all three)* | Together these are what "member" actually meant in the prototype — three orthogonal facts collapsed into one row |
| Login | **User** | An authentication identity. Zero or one per Party |
| Office bearer role | **Role** | A named set of permissions, composed per society |
| — | **Unit Account** | The financial account of a Unit. Dues attach here, not to a person |
| Payment advice, bill, demand | **Invoice** | A payable obligation issued against a Unit Account |
| Payment, receipt | **Receipt** | Money actually received. Distinct from the obligation |
| — | **Ledger Entry** | An immutable debit or credit. Balance is derived from these |
| Fine, penalty, late fee | **Dunning Event** + penalty Ledger Entry | The escalation act, and its financial effect |
| Voucher | **Expense Voucher** | Society expenditure requiring approval |
| Notice, circular | **Announcement** | |

**Rule: code uses the model term, never the society term.** A society that calls a
Block a "Wing" changes a label in master data. Nobody renames a Go struct.

The single most important correction above is that **ownership, occupancy and membership are three separate facts**, not one. "Member" conflated a person, their legal title, their
residence and their standing in the association. Separating them is what makes a tenant,
a non-resident landlord, a jointly owned flat, a flat that changed hands and an owner of
two units all expressible — and it is why every future module attaches to a Unit rather
than a person.

`DOCS/REGISTRY_OWNERSHIP_MODEL.md` carries the full model, the temporal constraints, and
the sale and tenancy workflows.

---

## 2. Layers

```
internal/http/{module}/      HTTP handlers. Fiber. Translate wire ↔ domain. No rules.
        ↓
internal/app/{module}/       Application services = use cases. Own transactions.
        ↓                    Orchestrate; do not decide.
internal/domain/{module}/    Entities, value objects, aggregates, domain events.
                             Pure Go. No SQL, no HTTP, no context plumbing.
        ↑
internal/store/{module}/     Repositories. sqlc-generated + hand-written.
                             Implement interfaces declared in domain.
```

**The dependency rule:** `http → app → domain`, and `app → store`. `domain` imports
none of the others. Enforced by `ops/checks/check_layers.sh` in CI.

**Interfaces are declared where they are consumed, not where they are implemented.**
`domain/finance` declares `InvoiceRepository`; `store/finance` implements it. That is
what keeps the dependency arrow pointing inward, and it is idiomatic Go rather than
imported Java.

### What goes where — the test that resolves most arguments

- Can this rule be stated without mentioning a database, an HTTP request, or another
  module? → **domain**
- Does it coordinate several aggregates, a transaction, or an external service? → **app**
- Is it about JSON, status codes, or headers? → **http**
- Is it SQL? → **store**

"An invoice cannot be settled twice" is domain. "Issue invoices for every occupied unit
in this billing run" is app. Getting this wrong in the prototype is how a 2,300-line
repository file happened.

---

## 3. Aggregates

An aggregate is a cluster of objects with one root, one consistency boundary, and one
set of invariants that must hold at every commit.

**The two rules that matter, and that we actually enforce:**

1. **One transaction changes one aggregate.** If a use case must change two, the second
   changes via a domain event, asynchronously.
2. **Aggregates reference each other by ID, never by pointer.** An `Invoice` holds a
   `UnitID`, not a `*Unit`. This is also what stops modules from `JOIN`ing across
   boundaries.

| Aggregate | Root | Contains | Invariants it enforces |
| --- | --- | --- | --- |
| **Unit** | Unit | — | Unit code unique within block; type immutable once transactions exist |
| **Party** | Party | Contacts, identity references | At least one contact; a verified contact cannot be silently edited |
| **UnitTitle** | Unit | The unit's ownership set | Shares sum to 1; exactly one primary owner; no gaps in the timeline; consistent holding type |
| **Occupancy** | Occupancy | Occupants, tenancy reference | No overlapping occupancy for a unit; `tenanted` implies a tenancy; `vacant` implies no occupant |
| **OwnershipTransfer** | OwnershipTransfer | Steps, documents, approvals | Cannot go effective with unsettled dues unless overridden and recorded; the effective step is atomic |
| **AssociationMembership** | AssociationMembership | — | One primary membership per unit at a time; share certificate unique per society |
| **UnitAccount** | UnitAccount | Ledger entries | Balance equals the sum of entries; entries are append-only; never negative without an explicit credit note |
| **Invoice** | Invoice | Invoice lines | Total equals sum of lines; cannot settle twice; cannot cancel once partly settled; lines immutable after issue |
| **Receipt** | Receipt | Allocations | Allocations sum to the receipt amount; cannot allocate to another unit's invoice |
| **BillingRun** | BillingRun | — | Idempotent per (org, period); cannot run twice for one period |
| **ExpenseVoucher** | ExpenseVoucher | Lines, approvals | Cannot pay before approval; approval chain completes in order; only cancelled may be deleted |
| **Document** | Document | Reviews | Cannot verify without a stored object; deleting the last required document triggers a domain event, not a direct edit elsewhere |
| **Announcement** | Announcement | Audiences | Cannot publish without an audience |

### Worked example: what the prototype did versus what DDD requires

*Prototype:* paying a reinstatement advice updated the advice row, updated the member's
status, marked payment attempts failed, and **deleted the linked lapsed row** — four
aggregates mutated in one place, with history destroyed.

*v2:* the `Receipt` aggregate records money received and allocates it. That commits. It
emits `finance.payment.received`. A handler then settles the `Invoice`; another writes
the `UnitAccount` ledger entry; another re-evaluates occupancy standing. Each is one
aggregate, one transaction, each idempotent, nothing deleted.

The cost is eventual consistency measured in milliseconds. What you get is a system
where any state can be explained, and where a failure halfway through leaves a
recoverable position rather than a corrupt one.

---

## 4. Value objects

Small immutable types that carry validation, so an invalid value cannot exist. In Go
these are plain structs with a constructor — no ceremony.

```go
package domain

// Money is an exact amount in a currency. Never a float: binary floating point cannot
// represent 0.10, and society accounts must balance exactly.
type Money struct {
    amount   decimal.Decimal
    currency string
}

func NewMoney(amount decimal.Decimal, currency string) (Money, error) {
    if currency == "" {
        return Money{}, ErrCurrencyRequired
    }
    return Money{amount: amount.Round(2), currency: currency}, nil
}

func (m Money) Add(o Money) (Money, error) {
    if m.currency != o.currency {
        return Money{}, ErrCurrencyMismatch
    }
    return Money{m.amount.Add(o.amount), m.currency}, nil
}
```

Value objects to build, and the bug each prevents:

| Type | Prevents |
| --- | --- |
| `Money` | Float rounding; adding rupees to dollars |
| `PhoneNumber` | The prototype's 361 unvalidated numbers; hardcoded +91 |
| `EmailAddress` | The 358 malformed values |
| `UnitCode` | `flat_no` as free text; `SHOP4` breaking a numeric assumption |
| `FinancialYear` | `'FY 2023-24'` as a parseable string |
| `DateRange` | Occupancy periods that end before they start |
| `Percentage` | Escalation rates stored as ambiguous numbers |

`Money` uses `shopspring/decimal` in Go and `numeric(14,2)` in PostgreSQL, and crosses
the wire as a **string** — a JSON number becomes a float64 in JavaScript and a double in
Dart, and `10725.15` eventually renders as `10725.149999999999` in a resident's app.

---

## 5. Domain events

Already specified as the transactional outbox in the engineering standards; this is what
they mean in the domain.

An aggregate records events; the application service persists them **in the same
transaction** as the state change. A worker publishes them afterwards.

```go
// in domain
func (i *Invoice) Issue(at time.Time) error {
    if i.status != InvoiceDraft {
        return ErrInvoiceAlreadyIssued
    }
    i.status = InvoiceIssued
    i.issuedAt = at
    i.record(InvoiceIssued{InvoiceID: i.id, UnitID: i.unitID, Total: i.total})
    return nil
}
```

Naming is `{module}.{aggregate}.{past-tense-verb}` — `finance.invoice.issued`. Past
tense matters: an event is a fact that happened, not a request. `SendReminder` is a
command; `InvoiceOverdue` is an event. Confusing the two is how event-driven systems
become distributed spaghetti.

Events are the **only** legal way one module reacts to another. `communication` does not
call `finance`; it subscribes to `finance.invoice.overdue`.

---

## 6. Anti-corruption layers

Every external provider is wrapped in an interface owned by our domain, with the
provider's vocabulary confined to the adapter.

```go
// domain/finance — our language
type PaymentGateway interface {
    CreateOrder(ctx context.Context, o OrderRequest) (Order, error)
    VerifyCallback(ctx context.Context, payload []byte, sig string) (PaymentResult, error)
}

// store/finance/razorpay — Razorpay's language, and nowhere else
type razorpayGateway struct{ ... }
```

The prototype leaked Razorpay's field names into handlers and the database, which is why
"support UPI through PhonePe as well" would have been a refactor. Applies equally to
`MessageChannel` (WhatsApp/MSG91/SMTP), `ObjectStore` (R2/MinIO), and `DocumentRenderer`
(Gotenberg).

This is also what makes the modules testable: the domain never touches a network.

---

## 7. Directory layout

```
api/internal/
├── domain/
│   ├── shared/          Money, PhoneNumber, EmailAddress, DateRange, errors
│   ├── registry/        Unit, Party, Occupancy + repository interfaces + events
│   ├── finance/         Invoice, Receipt, UnitAccount, LedgerEntry, PaymentGateway
│   ├── documents/
│   └── expense/
├── app/
│   ├── registry/        UnitService, OccupancyService
│   ├── finance/         BillingService, CollectionService, DunningService
│   └── …
├── store/
│   ├── registry/        sqlc output + repository implementations
│   ├── finance/
│   └── …
├── http/
│   ├── registry/        handlers + generated server interfaces
│   └── …
└── platform/            tenancy, identity, access, files, jobs, messaging, integration
```

One module = one folder in each of the four layers. If a folder appears in `store` but
not in `domain`, something is being built without a model.

---

## 8. Testing, by layer

| Layer | Test style | Needs a database? |
| --- | --- | --- |
| `domain` | Plain table-driven unit tests. Fast, no mocks needed — there is nothing to mock | No |
| `app` | Integration tests against a real PostgreSQL via testcontainers | Yes |
| `store` | Integration tests, including RLS isolation and `EXPLAIN` plan assertions | Yes |
| `http` | Contract tests against the generated server interface | Sometimes |

**Aggregate invariants are tested in `domain` and nowhere else.** "An invoice cannot be
settled twice" is one unit test with no infrastructure. That property — that the most
important rules are the cheapest to test — is the practical payoff of this layering, and
the reason it is worth the extra folders.

---

## 9. What we are not doing, and why

Three rejections deserve more than a table row, because each is a genuinely good idea
that would be a mistake *here*. The question is never "is this pattern good?" — it is
"does this pattern's cost land on the person who has to pay it?" You are one developer.
Every abstraction you adopt, you maintain, debug and explain to your first hire.

### 9.1 Event sourcing — no

**What it is.** Instead of storing current state, you store the ordered sequence of
events that produced it. `InvoiceIssued`, `PaymentReceived`, `PenaltyApplied`. Current
state is a fold over that sequence. The event log is the database.

**Why it is tempting here.** We are already building an append-only ledger, we already
emit domain events, and finance is exactly the domain event sourcing was invented for.
It looks like we are 70% of the way there.

**Why it is a trap.** We are not 70% of the way there; we are 20%. Event sourcing is not
"append-only tables plus events." It brings a set of obligations that arrive together:

- **Projections.** Every read model must be rebuilt from the log. You now maintain
  projection code, projection state, and a rebuild pipeline. "Show me this unit's
  balance" stops being a query.
- **Event versioning.** `PaymentReceived` v1 has no `currency` field. Two years of them
  are in the log, immutable. Every consumer must handle every historical shape, forever.
  This is the cost people underestimate by an order of magnitude.
- **Replay tooling.** When a projection is wrong you replay. That needs infrastructure,
  and it needs to be fast enough to be usable at 100 societies of history.
- **Debugging.** "Why is this balance wrong?" becomes reading a thousand events rather
  than one row. Great for auditors, miserable at 11pm.
- **GDPR/DPDP erasure.** An immutable log versus a legal right to erasure is a genuinely
  hard problem requiring crypto-shredding or rewriting history.

**What we do instead, which gets most of the benefit.** `ledger_entries` is append-only
and the balance is derived from it. Every financial fact is reconstructible. `audit_log`
records who changed what, before and after. The outbox carries domain events for
integration. **We get auditability and explainability — the two things you actually want
from event sourcing — without projections, versioning or replay.**

**When to revisit.** If a regulator or auditor requires full temporal reconstruction of
*non-financial* state, or if you hire someone who has run event-sourced systems in
production. Not before.

### 9.2 CQRS as a default — no

**What it is.** Command Query Responsibility Segregation: separate models for writing
and reading. Commands go through the domain model; queries bypass it entirely and read
a shape optimised for display.

**The version we do adopt.** A modest one, and it is worth naming because it is easy to
mistake for the full pattern: **queries do not go through aggregates.** Listing 500
invoices does not load 500 `Invoice` aggregates; it runs a sqlc query returning a
read-shaped struct. Aggregates exist to enforce invariants on *writes*; using them for
reads is slow and pointless. That is one rule, not an architecture.

**What we reject** is the full apparatus: separate read and write databases, separate
models for every entity, eventual consistency between them, and synchronisation
machinery. The costs:

- **Two models for everything**, drifting apart, each needing tests.
- **Eventual consistency in the UI.** A treasurer records a payment and does not see it
  in the list. You then build read-your-own-writes handling, which is where CQRS
  complexity actually lives.
- **Doubled infrastructure** if the read side is a separate store.

**What we do instead.** One PostgreSQL. Writes go through aggregates; reads are direct
typed queries. Where a query genuinely cannot be served efficiently — consumption
rollups over 1.4 billion meter readings, a dashboard aggregating a year of ledger
entries — we build a **specific, named read model** (`meter_consumption_monthly`) and
keep it current from a job. That is CQRS applied where it earns its keep, one table at a
time, rather than as a project-wide stance.

**When to revisit.** When a specific query is provably too slow with an index and a
materialised view. Then build one read model. Never adopt it globally.

### 9.3 A DI framework — no

**What it is.** `wire`, `fx`, `dig` and similar: tools that construct your object graph
for you, either by code generation or at runtime by reflection.

**Why people reach for it.** Wiring by hand in `main.go` gets long. Twelve modules × four
layers is a lot of constructor calls.

**Why we do not.** Go is not Java, and the pain DI frameworks solve barely exists here:

- **`main.go` being long is not a problem.** It is the one file where the entire system
  is visible in one place. That is a feature — a new developer reads `main.go` and knows
  what the system is made of.
- **Runtime DI (`fx`, `dig`) trades compile-time errors for runtime ones.** A missing
  dependency becomes a panic at startup instead of a compiler error. On a system where
  `go build` currently catches every wiring mistake, that is a straight downgrade.
- **Code-gen DI (`wire`) is safer but adds a build step**, generated files in review,
  and an error language your future hire must learn before fixing a typo.
- **Stack traces get worse.** Frameworks add frames between your code and the failure.
- **It is a dependency on your dependency graph** — the thing least able to tolerate
  breakage.

**What we do instead.** Explicit constructor injection, assembled in `main.go`:

```go
db    := database.Open(...)
store := financestore.New(db)
svc   := financeapp.NewBillingService(store, clock, outbox)
handler := financehttp.NewHandler(svc)
```

Greppable, debuggable, and `go build` verifies it. When `main.go` exceeds a few hundred
lines, split it into per-module `wireFinance(deps) *financeapp.Services` functions.
That is a refactor, not a framework.

**When to revisit.** Honestly: probably never for a Go monolith. If a team of eight is
fighting over `main.go`, revisit — but the fix then is more likely module-level
assembly functions than a framework.

### 9.4 The principle underneath

Each of these patterns solves a real problem, at a real cost, and the cost is paid
continuously while the benefit arrives later — sometimes never. A team of fifteen can
absorb that; a solo founder cannot, and a solo founder who does typically ships a
beautifully architected system with no customers on it.

The rejections are also **reversible in the direction that matters**. Append-only ledger
plus domain events makes event sourcing *easier* to adopt later, not harder. Read models
can be added one query at a time. Explicit wiring can be replaced by `wire` in an
afternoon. **We are not closing doors — we are declining to walk through them before
there is anything on the other side.**

Contrast that with the one-way doors in `PLATFORM_ENGINEERING_STANDARDS.md` §16 —
`org_id`, UUID keys, partitioning, object storage — which we *are* paying for up front
precisely because they cannot be added later. That is the whole trade: spend complexity
where it is unrecoverable, refuse it where it is not.

### 9.5 Everything else we are not doing

| Pattern | Verdict |
| --- | --- |
| **Repository per entity** | No. One repository **per aggregate root**. `InvoiceRepository`, not `InvoiceLineRepository` — a line has no life outside its invoice |
| **Abstract factories / specification pattern** | No. Go has functions and closures |
| **Microservices** | No. A modular monolith with enforced boundaries. Those boundaries are what make extraction possible later, which is the entire point of drawing them now |
| **Generic `BaseEntity` / inheritance** | No. Go has composition; the table spine is a migration convention, not a struct hierarchy |
| **Anaemic domain model** | Rejected in the other direction: rules live on aggregates, not in service classes operating on structs. That is the failure the prototype's repository already demonstrates |

# CivicSync v2 — Module Register

**Status:** Accepted · **Date:** 26 Aug 2026 · **Governs:** module boundaries, naming,
ownership and build sequence.

An ERP is a set of modules with hard boundaries, not a monolith with folders. This
document is the canonical list. Nothing may be built that is not registered here, and
nothing registered here may quietly reach into another module's tables.

## How a module is defined

Every module owns, exclusively:

| Facet | Rule |
| --- | --- |
| **Code** | Lowercase identifier. Appears in permissions, events, API paths, feature flags |
| **Tables** | No other module writes them. Cross-module reads go through the owning module's service, or through an explicitly published view |
| **API namespace** | `/v1/{module}/…` |
| **Permissions** | `{module}.{entity}.{action}` — e.g. `finance.invoice.create` |
| **Events** | `{module}.{aggregate}.{event}` — e.g. `finance.invoice.issued` |
| **Master data** | The configurable lists it owns |
| **Settings** | The `setting_definitions` keys it owns, prefixed `{module}.` |
| **Go package** | `internal/app/{module}` and `internal/store/{module}` |

**The boundary rule:** a module may depend on another module's *events and public
service interface*, never on its tables. `finance` does not `JOIN units`; it holds a
`unit_id` and asks `registry` for what it needs. This is what keeps a module
extractable into its own service later — and what stops the prototype's single
2,300-line repository from reforming under a new name.

## Module enablement — the ERP requirement

Modules are switched on per society, not compiled in.

```sql
CREATE TABLE control.plan_modules (        -- what a commercial plan entitles
    plan_code   text NOT NULL,
    module_code text NOT NULL,
    PRIMARY KEY (plan_code, module_code)
);

CREATE TABLE control.org_modules (         -- what a society actually has on
    org_id      uuid NOT NULL REFERENCES control.tenants(org_id),
    module_code text NOT NULL,
    enabled     boolean NOT NULL DEFAULT false,
    enabled_at  timestamptz,
    enabled_by  uuid,
    PRIMARY KEY (org_id, module_code)
);
```

A disabled module's endpoints return `404`, its permissions cannot be granted, and its
navigation does not render. Enabling a module is an admin action that seeds its master
data defaults. This is how you sell tiers without branching code.

---

# Part 1 — Platform layer

Not product modules. Infrastructure every module consumes. Cannot be disabled.

| Code | Responsibility | Owns | Packet |
| --- | --- | --- | --- |
| `platform.tenancy` | Tenant directory, RLS context, pool routing | `control.tenants`, `control.plan_modules`, `control.org_modules`, `app.current_org_id()` | 00, 01 |
| `platform.masterdata` | The master-table framework, registry, effective dating, import/export | `master_registry`, generic master-table contract | 01 |
| `platform.settings` | Typed configurable parameters | `setting_definitions`, `setting_values` | 01 |
| `platform.audit` | Append-only change log, partitioned | `audit_log` | 01 |
| `platform.identity` | Users, credentials, sessions, refresh tokens, OTP, devices | `users`, `credentials`, `sessions`, `otp_requests`, `devices` | 02 |
| `platform.access` | Permissions, roles, memberships, authorisation middleware | `permissions`, `roles`, `role_permissions`, `memberships` | 02 |
| `platform.files` | Object storage, pre-signed upload/download, checksums, scanning | `documents` (storage layer), `storage_objects` | 03 |
| `platform.jobs` | River worker, schedules, idempotency, advisory locks | River tables, `job_schedules`, `idempotency_keys` | 03 |
| `platform.messaging` | Outbox, channel adapters (WhatsApp/SMS/email/push), delivery receipts, templates | `outbox`, `message_templates`, `notification_deliveries` | 03 |
| `platform.integration` | Org API keys, scopes, outbound webhooks, delivery log | `api_keys`, `webhook_subscriptions`, `webhook_deliveries` | 03 |
| `platform.numbering` | Document number series | `number_series` | 01 |
| `platform.workflow` | Generic approval chains — used by expense, documents, and later gate passes and NOCs | `workflow_definitions`, `workflow_instances`, `workflow_steps` | 10 |

---

# Part 2 — Business modules, v2.0 scope

These ship before pilot go-live. Nothing else does.

## `registry` — Property & People

The foundation every other module hangs off.

| | |
| --- | --- |
| **Responsibility** | Physical property structure and the people related to it over time |
| **Tables** | `blocks`, `unit_types`, `units`, `parties`, `party_contacts`, `occupancies`, `party_identity_refs` |
| **Master data** | Block list, unit types, occupancy relationship types (owner / co-owner / tenant / family / POA), contact types, ID types |
| **Settings** | `registry.unit_code_format`, `registry.require_occupancy_overlap_check`, `registry.default_country_code` |
| **Permissions** | `registry.unit.{read,create,update,deactivate}`, `registry.party.{…}`, `registry.occupancy.{…}` |
| **Emits** | `registry.unit.created`, `registry.occupancy.started`, `registry.occupancy.ended`, `registry.party.contact_verified` |
| **Consumes** | — |
| **Depends on** | platform only |
| **Packet** | 05 |

Note the direction of dependency: everything depends on `registry`; `registry` depends
on nothing. That is why it is built first among business modules.

## `documents` — Document management

| | |
| --- | --- |
| **Responsibility** | Document lifecycle: upload, classification, verification, expiry, retention |
| **Tables** | `document_types`, `documents` (business view), `document_reviews`, `document_retention_policies` |
| **Master data** | Document types (allotment letter, sale deed, PAN, lease agreement…), each with required/optional, expiry rules, who may verify |
| **Settings** | `documents.max_file_size_mb`, `documents.allowed_mime_types`, `documents.retention_default_years` |
| **Permissions** | `documents.document.{read,upload,delete}`, `documents.review.{approve,reject}` |
| **Emits** | `documents.document.uploaded`, `documents.document.verified`, `documents.document.rejected`, `documents.document.expiring` |
| **Consumes** | `registry.occupancy.started` (to require onboarding documents) |
| **Depends on** | `registry`, `platform.files`, `platform.workflow` |
| **Packet** | 06 |

The prototype's "verified allotment letter gates activation" rule becomes a
**configurable document requirement** per occupancy type — not a hardcoded check.

## `finance` — Billing, ledger and collections

The largest module. Built in three packets.

| | |
| --- | --- |
| **Responsibility** | Everything about money owed to and received by the society |
| **Tables** | `charge_heads`, `tax_rates`, `fee_schedules`, `financial_years`, `unit_accounts`, `billing_runs`, `invoices`, `invoice_lines`, `ledger_entries`, `receipts`, `receipt_allocations`, `payment_attempts`, `adjustments`, `dunning_policies`, `dunning_events`, `payment_providers` |
| **Master data** | Charge heads, tax rates, fee schedules, financial years, dunning policies, payment modes, provider config |
| **Settings** | `finance.currency`, `finance.fy_start_month`, `finance.invoice_due_days`, `finance.allow_partial_payment`, `finance.rounding_mode`, `finance.receipt_series` |
| **Permissions** | `finance.invoice.{read,create,cancel}`, `finance.receipt.{read,record,refund}`, `finance.adjustment.{create,approve}`, `finance.billing_run.execute`, `finance.dunning.configure`, `finance.report.read` |
| **Emits** | `finance.invoice.issued`, `finance.payment.received`, `finance.payment.failed`, `finance.invoice.overdue`, `finance.dunning.escalated`, `finance.account.suspended` |
| **Consumes** | `registry.occupancy.started/ended` (who is billable), `metering.consumption.finalised` (later) |
| **Depends on** | `registry`, `platform.jobs`, `platform.numbering`, `platform.messaging` |
| **Packets** | 07 (charges, accounts, ledger, invoices, billing runs) · 08 (receipts, Razorpay + webhooks + reconciliation, dunning job) · 09 (ETL of 955 legacy receipts + reconciliation report) |

## `expense` — Expense vouchers

| | |
| --- | --- |
| **Responsibility** | Society expenditure: vouchers, approval chains, payment, budget tracking |
| **Tables** | `expense_categories`, `vendors`, `expense_vouchers`, `voucher_lines`, `voucher_payments`, `budgets`, `budget_lines` |
| **Master data** | Expense categories, vendors, budget heads, approval chain definitions |
| **Settings** | `expense.require_vendor`, `expense.approval_threshold_amounts`, `expense.voucher_series` |
| **Permissions** | `expense.voucher.{read,create,submit,approve,reject,pay,cancel}`, `expense.budget.{read,manage}` |
| **Emits** | `expense.voucher.submitted`, `expense.voucher.approved`, `expense.voucher.paid` |
| **Consumes** | — |
| **Depends on** | `platform.workflow`, `platform.numbering`, `platform.files` |
| **Packet** | 10 |

Approval routing moves from hardcoded role checks into `platform.workflow`, with
amount-threshold chains a society configures itself.

## `communication` — Announcements & messaging

| | |
| --- | --- |
| **Responsibility** | Society-to-resident communication and its delivery record |
| **Tables** | `announcements`, `announcement_audiences`, `announcement_reads`, `communication_templates` |
| **Master data** | Announcement categories, audience definitions, channel preferences |
| **Settings** | `communication.default_channels`, `communication.quiet_hours`, `communication.whatsapp_enabled` |
| **Permissions** | `communication.announcement.{read,create,publish,delete}`, `communication.template.manage` |
| **Emits** | `communication.announcement.published` |
| **Consumes** | Every module's events, to render notifications |
| **Depends on** | `platform.messaging`, `registry` |
| **Packet** | 11 |

## `reporting` — Reports, statements and dashboards

| | |
| --- | --- |
| **Responsibility** | Server-side generation of operational and statutory reports |
| **Tables** | `report_definitions`, `report_runs`, `saved_views` |
| **Master data** | Report definitions, saved filter views |
| **Settings** | `reporting.export_row_limit`, `reporting.retention_days` |
| **Permissions** | `reporting.report.{read,run,schedule}`, per-report grants |
| **Emits** | `reporting.report.completed` |
| **Consumes** | Reads through each module's published query interface, never its raw tables |
| **Depends on** | all |
| **Packet** | 12 |

Exports are background jobs producing real XLSX/PDF in object storage, returned as
pre-signed URLs. The prototype's browser-memory CSV and `document.write` "PDF" are gone.

---

# Part 3 — Roadmap modules: seams only

**These are not built before pilot go-live.** What exists now is the seam that makes
each addable without touching what is already shipped. Registering them here is how we
prevent a v2.0 decision from accidentally blocking them.

| Code | Responsibility | Seam that must exist in v2.0 |
| --- | --- | --- |
| `helpdesk` | Complaints, service requests, SLA tracking | `units` + `parties` FKs; `platform.workflow`; event subscription |
| `visitors` | Gate passes, visitor log, pre-authorisation, ANPR, delivery handling | `units` FK; `telemetry` schema for gate events; device identity in `platform.integration` |
| `parking` | Zones, slots, permits, visitor parking, violations | `units.parking_slots` attribute; `parking_zones` as master data placeholder; charge head for parking fees |
| `metering` | Meters, readings ingest, consumption calculation, consumption billing | `telemetry` schema (separate pool), partitioned `meter_readings`, rollup tables, `charge_heads` with a usage-based rate type |
| `amenities` | Facility catalogue, booking calendar, usage charges | `charge_heads` supports one-off charges; `platform.workflow` for approvals |
| `staff` | Society staff, attendance, duty rosters, payroll | `parties` already models a person independent of a unit |
| `governance` | AGM notices, agendas, minutes, resolutions, e-voting | `communication` audiences; `occupancies` determines voting eligibility |

The most important seam is `metering`. Per §16 of the engineering standards, telemetry
gets its own schema and connection pool from the first migration — even empty — so that
1.4 billion readings a year can later move to a dedicated store without rewriting the
billing module that consumes them.

---

# Part 4 — Packet map

Each business packet is a **vertical slice**: migrations → API → admin UI → tests. It
ends with something a person can use, not a layer nobody can see. That matters more
when building alone than when building with a team.

| Packet | Scope | Modules | Exit criterion |
| --- | --- | --- | --- |
| **00** | Foundation: monorepo, tenancy, CI guards, ADRs | `platform.tenancy` | `make ci` green; app role has no BYPASSRLS |
| **01** | Table spine, master-data framework, settings, audit, numbering, module enablement | `platform.masterdata`, `.settings`, `.audit`, `.numbering` | Two seeded societies; SQL-level cross-tenant read proven impossible |
| **02** | Identity & access | `platform.identity`, `.access` | Real OTP delivered; permission middleware enforcing; no OTP in any response |
| **03** | Files, jobs, outbox, integration | `platform.files`, `.jobs`, `.messaging`, `.integration` | File round-trips to MinIO via pre-signed URLs; a job runs twice with no effect; a webhook delivers with valid HMAC |
| **04** | Admin console shell + Master Data Console | — | Every master entity gets CRUD, effective dating, import/export from one registry-driven UI |
| **05** | Property & people + **ETL pass 1** | `registry` | 370 members reconciled into units/parties/occupancies; reviewed by you |
| **06** | Documents | `documents` | Configurable doc types; verification workflow; retention job |
| **07** | Finance I: charges, accounts, ledger, invoices, billing runs | `finance` | A billing run produces invoices; balances derive from ledger |
| **08** | Finance II: receipts, Razorpay + webhooks, dunning job | `finance` | ₹1 live payment end to end incl. webhook; dunning proven idempotent |
| **09** | Finance III: **ETL pass 2** + reconciliation | `finance` | ₹10,72,892 reconciles to the paisa |
| **10** | Workflow engine + expense vouchers | `platform.workflow`, `expense` | Configurable approval chain by amount threshold |
| **11** | Communication | `communication` | Announcement delivered over WhatsApp with a delivery receipt recorded |
| **12** | Reporting & dashboards | `reporting` | 20,000-row export as a background job, not a browser tab |
| **13** | Resident app | Flutter client | On TestFlight and Play internal testing |
| **14** | Cutover | — | Three rehearsals; parallel run; go-live |
| **15+** | Roadmap modules | see Part 3 | Only after pilot is live |

## Rules that keep this honest

1. **A packet is not done until its exit criterion is demonstrable.** Not "the code is
   written" — demonstrable.
2. **Module boundaries are checked in CI.** `ops/checks/check_module_boundaries.sh`
   fails the build if `internal/app/finance` imports `internal/store/registry`.
3. **A new table must declare its module** in a migration comment. A table belonging to
   no module fails the spine check.
4. **Roadmap modules get no code.** A seam is a foreign key, a schema, or an event —
   never a half-built feature. Half-built features are how solo projects die.

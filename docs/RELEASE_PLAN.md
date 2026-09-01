# CivicSync — Release Plan and Timeline

**Status:** Accepted · **Revision 3, 26 Aug 2026**
**Supersedes** revision 2 in full. Re-sequenced after the Supreme Court order handing the
project to NBCC changed what the pilot association actually needs, and when.

---

## Naming, settled

| Term | Means |
| --- | --- |
| **Prototype** | What Codex handed over on 25 Aug 2026. Frozen at `prototype-final-2026-08-26`. **Retired, not bridged** |
| **`v2` branch** | The rebuilt codebase. A git branch name, not a product version |
| **Release 0.5** | **Association Core.** Admin-only. Member register, documents, roles, notices, and books that replace the association's Excel ledger |
| **Release 1.0** | Operating society. Billing, collection, penalties, vouchers, reporting, resident portal |
| **Release 1.1** | Flutter resident app |
| **Release 2.0** | Roadmap modules: visitors, parking, metering, amenities, helpdesk, governance |

---

## What changed, and why

The apartments were under dispute with a fraudulent builder. The Supreme Court has
ordered handover to NBCC, which will take time. **The association is not running a
building and will not be for a long while.**

That inverts the priority order in the original plan:

| Less urgent than assumed | More urgent than assumed |
| --- | --- |
| Monthly maintenance billing | The **member register** — legal standing depends on it |
| Payment collection and reconciliation | **Documents, BBA agreements above all** — each member's proof of allotment for the NBCC claim |
| Late-payment penalties and dunning | **Notices** — litigation means constant communication |
| Suspension for long-pending dues | **Books** — they keep accounts in Excel today and want out |
| The resident-facing app | Office-bearer roles and authority |

**Books are not billing.** The association needs to *record* what came in and went out and
produce statements an auditor accepts. It does not need to *collect* anything yet. Those
are different products and they are now in different releases.

### Three decisions taken with this revision

1. **The prototype is retired outright.** No bridge, no hardening. The association is not
   in a hurry and quality matters more. The Neon snapshot becomes the migration source.
2. **No resident-facing UI in Release 0.5 — but the plumbing is built.** The full registry
   model, unit-scopeable role assignments, and the resident API endpoints all exist and
   are tested. Only the UI is absent, which makes the portal and the Flutter app pure
   frontend projects later.
3. **Data migrates early and for real.** The ETL is not a test fixture. When the
   association starts using Release 0.5, the migrated data is production data.

---

## Part 1 — Release 0.5: Association Core

Nine packets. Admin-only. Books, not billing.

| # | Packet | Modules | Days |
| --- | --- | --- | ---: |
| 00 | Foundation — monorepo, tenancy, CI guards, ADRs | `platform.tenancy` | 5 |
| 01 | Platform core — spine, master data, settings, audit, numbering, module enablement, partitioning, outbox | `platform.masterdata/.settings/.audit/.numbering` | 12 |
| 02 | Identity & access — WhatsApp OTP, RBAC, **unit-scopeable role assignments, resident API built** | `platform.identity/.access` | 12 |
| 03 | Files, jobs, messaging — R2, River, WhatsApp and email channels | `platform.files/.jobs/.messaging` | 8 |
| 04 | Admin shell + Master Data Console | — | 10 |
| 05 | Registry — units, parties, title, occupancy, membership + **ETL pass 1** + verification worklist | `registry` | 15 |
| 06 | Documents — configurable types, **BBA mandatory-document gate**, verification | `documents` | 7 |
| 07 | **Books** — chart of accounts, ledger, manual receipts and expenses, **opening balances**, legacy archive, statements, export | `finance` | 16 |
| 08 | Notices | `communication` | 6 |
| | **Release 0.5 total** | | **91** |

### Deliberately excluded from Release 0.5

Fee schedules · invoices and billing runs · payment intents and UPI collection ·
reconciliation · penalties and dunning · expense voucher workflows · ownership transfer
and tenancy workflows · resident portal UI · outbound webhooks and partner API keys ·
reporting beyond the statutory statements.

Every one of these is in Release 1.0. None is needed before handover progresses.

---

## Part 2 — Release 1.0: Operating Society

Seven packets, started when handover progresses and the association begins running a
building.

| # | Packet | Modules | Days |
| --- | --- | --- | ---: |
| 09 | Billing & collection — fee schedules, invoices, billing runs, payment intents, UPI, statement reconciliation, dunning | `finance` | 18 |
| 10 | Workflow engine + ownership transfer + tenancy onboarding | `platform.workflow`, `registry` | 10 |
| 11 | Expense vouchers on the workflow engine | `expense` | 7 |
| 12 | Reporting & dashboards | `reporting` | 8 |
| 13 | Resident portal (web UI over the API built in Packet 02) | — | 8 |
| 14 | Hardening — load test, security, DPDP, backup/restore rehearsal, UAT | — | 10 |
| 15 | General availability | — | 5 |
| | **Release 1.0 total** | | **66** |

## Release 1.1

| # | Packet | Days |
| --- | --- | ---: |
| 16 | Flutter resident app + Razorpay adapter | 20 |

## Release 2.0

Nothing here gets code until Release 1.0 is live. Seams exist so each can be added
without disturbing what shipped.

| Module | Rough size |
| --- | --- |
| `visitors` — gate passes, visitor log, guard app, ANPR | 25–30 days |
| `metering` — meter registry, device ingest, rollups, usage billing | 25–30 days |
| `governance` — AGM, minutes, resolutions, **e-voting weighted by membership and share** | 15–20 days |
| `parking` · `amenities` · `helpdesk` | 12–15 days each |
| `staff` — attendance, rosters, payroll | 15–20 days |

**Suggested order: `visitors` first** — most-demanded, clearest competitive comparison,
and it exercises the telemetry schema and device identity that `metering` and `parking`
reuse. `governance` is the sleeper: e-voting eligibility is already computable from the
membership model, so it is unusually cheap for its perceived value.

---

## Part 3 — Timeline

Capacity **4 days/week**. A focused day is 5–6 hours of actual building; sales calls,
association meetings and admin do not count.

| | Days | +15% | Weeks @ 4/day | Calendar |
| --- | ---: | ---: | ---: | --- |
| Release 0.5 | 91 | 105 | 26 | **~6 months** |
| Release 1.0 | 66 | 76 | 19 | +4.5 months |
| Release 1.1 | 20 | 23 | 6 | +1.5 months |

### Milestone schedule

Assuming Packet 00 starts **1 September 2026**. Working weeks, no holidays subtracted —
treat every date as **±1 month** and expect Diwali to cost a fortnight.

| Packet | The association gets | Cum. weeks | Target |
| --- | --- | ---: | --- |
| 00 | — foundation, CI green | 1.5 | mid Sep 2026 |
| 01 | — tenant isolation proven | 5 | early Oct 2026 |
| 02 | — login works, real WhatsApp OTP | 8.5 | late Oct 2026 |
| 03 | — files, jobs, messaging | 11 | mid Nov 2026 |
| 04 | — admin shell, Master Data Console | 14 | early Dec 2026 |
| **05** | **HANDS ON — member register, ownership and membership records, verification worklist** | **18** | **early Jan 2027** |
| 06 | **Document vault, BBA gate** | 20 | mid Jan 2027 |
| **07** | **BOOKS READY — parallel run begins** | **24.5** | **late Feb 2027** |
| 08 | Notices | 26 | early Mar 2027 |
| | **← RELEASE 0.5** | | |
| — | **BOOKS GO LIVE — Excel retired, FY 2027-28 opens in CivicSync** | — | **1 Apr 2027** |
| 09 | Billing and collection | 31 | mid Apr 2027 |
| 10 | Transfer and tenancy workflows | 34 | early May 2027 |
| 11 | Expense vouchers | 36 | late May 2027 |
| 12 | Reporting | 38 | early Jun 2027 |
| 13 | Resident portal | 41 | late Jun 2027 |
| 14 | Hardening, UAT | 44 | mid Jul 2027 |
| 15 | **← RELEASE 1.0** | 45 | **late Jul 2027** |
| 16 | **← RELEASE 1.1, Flutter app** | 51 | **early Sep 2027** |

Release 1.0 lands at roughly the same date as under revision 2. **What changed is that
the association gets real, usable software from January rather than July.**

### The two milestones that matter

**Early Jan 2027 — hands on.** The first time anyone outside you touches the system. It
also opens the registry verification worklist, which starts the longest society-driven
dependency in the project.

**1 April 2027 — books go live, Excel retired.** FY 2027-28 opens in CivicSync. This is
the moment it becomes the association's system of record rather than a thing they are
evaluating.

**This is the project's first hard date**, because a financial year boundary does not
move. Packet 07 is deliberately built before Packet 08 (Notices) to buy five weeks of
parallel run rather than three. If it slips, the fallback is 1 July 2027 — workable, but
it leaves a stub period that makes the first audit awkward. See `CUTOVER_PLAN.md`.

Everything before January is invisible to them. **That is the single biggest risk in this
plan** — see below.

### Parallel tracks — calendar, not developer-days

| Item | Start | Duration |
| --- | --- | --- |
| Udyam ✅ · Meta WABA ✅ | Done | — |
| WhatsApp template approvals | Oct 2026, before Packet 03 | Days |
| CA conversation — `COMMERCIAL_STRUCTURE.md` §7 | Now | One meeting |
| **Association's Excel books obtained and understood** | **Nov 2026, before Packet 07 design** | Weeks |
| **Committee approvals, parallel run, cut-over certificate** | Nov 2026 onward — see `CUTOVER_PLAN.md` | Ongoing |
| Registry verification by the committee | Jan 2027, at Packet 05 | Weeks |
| Society bank UPI/VPA confirmation | Mar 2027, before Packet 09 | Days |
| DLT registration | Only if WhatsApp proves insufficient | 1–4 weeks |

**Getting their Excel workbook early matters.** Packet 08's chart of accounts, opening
balances and statement formats are designed *from* it. Ask for a copy in November, not in
February.

### Honest risk assessment

| Risk | Likelihood | Effect | Mitigation |
| --- | --- | --- | --- |
| **Four months with nothing to show the association** | **High** | Relationship drift; a competitor gets in | Demo the admin shell at Packet 04 in December even though it is empty. Show progress monthly regardless |
| Capacity below 4 days/week | **High** | Slips months | Milestone commitments, never dates |
| Scope creep from committee requests | **High** | Slips months | The Module Register is the contract. New asks go to a later release |
| Their Excel is messier than expected | Medium | Packet 08 grows | Get the workbook in November |
| Registry verification stalls | Medium | Data stays "assumed" | Opens Jan 2027 with a progress bar |
| Burnout over eleven months | **Medium-high** | Project stops | Every packet ships something demonstrable |

### If capacity slips below 4 days

Cut in this order — least damage first:

1. **Master Data Console (Packet 04)** → bespoke screens for the six entities Release 0.5
   actually needs. *−5 days.* Costs you later, when every module needs config screens
2. **Notices (Packet 08)** → the association keeps using its WhatsApp group. *−6 days*.
   Already sequenced last for exactly this reason
3. **Statements (Packet 07)** → ledger and export only; they build the three statements in
   Excel from the export for one more audit cycle. *−4 days*

**Do not cut:** the registry model, the ETL reconciliation, tenant isolation, or
hardening. Those are the one-way doors.

### What to say to the association

*"You'll have the member register and document vault in January, the books ready to test
in late February, and FY 2027-28 opening in CivicSync on 1 April."*

Milestones, not dates. And show them the admin shell in December even though it is empty —
four silent months is how a first customer quietly becomes someone else's first customer.

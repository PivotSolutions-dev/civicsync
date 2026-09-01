# CivicSync — Cut-Over Plan

**Pivot Solutions → Buyer Welfare Association**
**Target go-live: 1 April 2027, opening FY 2027-28**
**Owner:** Sidhant, Pivot Solutions · **Status:** Active · **Date:** 26 Aug 2026

This is the engagement plan, not the build plan. It covers what Pivot does *with the
association* — the meetings, the approvals, the sign-offs and the day itself.
`DEVELOPMENT_PLANNER.md` covers what gets built.

---

## 1. Why cut over on 1 April

FY 2027-28 opens that day. Opening books at a financial-year boundary means the
association's first CivicSync year is complete and self-contained; a mid-year opening
leaves a stub period that complicates the first audit and every year-on-year comparison
after it.

**This is the project's only hard date.** Everything else is a milestone. A financial year
does not move.

**Fallback: 1 July 2027.** Workable, and better than rushing. There is no case for opening
mid-quarter.

---

## 2. What makes this cut-over unusually low-risk

Worth understanding before you walk the committee through it, because it lets you make a
confident promise.

- **No transaction history is migrated.** The books open with certified balances. There is
  no reconciliation of years of records to get wrong.
- **The legacy receipts are read-only reference**, outside the ledger entirely. They cannot
  corrupt anything.
- **Rollback is trivial.** If the association wants to abandon CivicSync on 15 April, they
  resume in Excel from the same opening balances. Nothing has been destroyed and nothing
  has to be unwound. Say this out loud in the Go/No-Go meeting — it is the single most
  reassuring thing you can tell a nervous treasurer.

The risk in this engagement is not technical. It is **committee confidence and committee
attention**, and this plan is mostly about managing those.

---

## 3. Engagement timeline

| # | When | Meeting | Outcome required |
| --- | --- | --- | --- |
| 1 | **Nov 2026** | Proposal, disclosure and engagement | Minuted in-principle approval; agreement + DPA signed; **related-party disclosure recorded** |
| 2 | **Nov 2026** | Requirements walkthrough | Excel workbook handed over; office bearers and roles listed; mandatory document list agreed |
| 3 | **Jan 2027** | Register handover + training | Committee begins registry verification |
| 4 | **Jan–Feb 2027** | BBA document drive | Members' documents collected and verified |
| 5 | **Feb 2027** | Chart of accounts + opening-balance workshop | Account heads approved; cut-off policy agreed; certifier named |
| 6 | **Mar 2027** | Parallel run review | Treasurer confirms one month reproduces exactly |
| 7 | **Late Mar 2027** | **Go / No-Go** | Formal resolution to adopt; **cut-over certificate signed** |
| 8 | **1 Apr 2027** | Go-live | Books opened |
| 9 | **Apr–May 2027** | Hypercare, then 30-day review | Issues closed; adoption confirmed |
| 10 | **Jul 2027** | First quarter close | Q1 statements produced from CivicSync |

---

## 4. The meetings, in detail

### Meeting 1 — Proposal, disclosure and engagement · November 2026

The most important meeting in this plan, and the one most likely to be done casually
because you know everyone in the room.

**Agenda**

1. What CivicSync is, and what Release 0.5 will and will not do
2. **Related-party disclosure** — see §5. Do this before the pitch, not after
3. Commercial terms: pilot pricing, what happens after, what the association owns
4. Data protection: the association is Data Fiduciary, Pivot is Data Processor
5. Exit and portability commitment — see §8
6. Timeline and the 1 April target

**Leave with, minuted:**

- [ ] Resolution to proceed with CivicSync on a pilot basis
- [ ] Related-party interest recorded, and approval given by office bearers **who are not
      related to you**
- [ ] Signed engagement agreement and Data Processing Agreement
- [ ] Named single point of contact on the committee
- [ ] Agreement that the association will notify members about the platform

> Get the resolution recorded as an **association decision**, not a favour. Committees
> rotate — see §7.

### Meeting 2 — Requirements walkthrough · November 2026

**Leave with:**

- [ ] The Excel workbook, all sheets, all years
- [ ] The bank statement format they can export (CSV / Excel / PDF-only)
- [ ] List of office bearers, their positions, and what each should be able to do
- [ ] The mandatory document list for a complete member record — **BBA above all**
- [ ] Their current membership fee structure and any legal-levy history
- [ ] Confirmation of who the treasurer is and who will certify balances

### Meeting 3 — Register handover and training · January 2027

The association's first hands-on session. Two hours, in person, with laptops open.

- Walk through the migrated register — 370 members, units, ownership records
- Explain **`source_confidence = 'assumed'`**: every migrated row is a best guess from the
  old system and needs a human to confirm it
- Demonstrate the verification worklist and assign it
- Set a target: verified members per week, visible as a progress bar
- Show the document upload flow before the BBA drive begins

**Leave with:** at least ten units verified during the session itself. People adopt what
they have already used once.

### Meeting 4 — BBA document drive · January–February 2027

Not a meeting — a campaign, and the association's most valuable near-term use of the
platform. Each member's Builder Buyer Agreement is their proof of allotment for the NBCC
claim process.

- Committee announces the drive with a deadline
- Members submit; office bearers verify against the master list
- Weekly completion report to the committee
- **Position it as NBCC preparation**, not as software onboarding. That is what it is, and
  it is what will make members respond

### Meeting 5 — Chart of accounts and opening balances · February 2027

The most technical committee meeting. Prepare a draft chart of accounts beforehand; do
not design it live in the room.

**Decide and minute:**

- [ ] Income heads (membership fee, legal levy, interest, other)
- [ ] Expense heads (legal and professional, printing, meeting expenses, bank charges,
      administrative, other)
- [ ] Cut-off date: **31 March 2027**
- [ ] Who certifies the closing balances — normally the treasurer
- [ ] **Policy on member balances.** If the committee cannot state who owes what, the
      resolution is: *"Member balances are opened at nil as at 1 April 2027. Any prior
      dues, if identified subsequently, will be raised as adjusting entries with reasons
      recorded."* Better an honest nil than numbers nobody can defend
- [ ] Confirmation that **FY 2026-27 is closed in Excel** by the association. CivicSync
      does not do this, and nobody should discover that in March

### Meeting 6 — Parallel run review · March 2027

Books are ready from late February. Five weeks of overlap.

- Treasurer enters **one full month** of real transactions into both Excel and CivicSync
- Side-by-side comparison of totals, member balances and the three statements
- Every difference investigated and explained — not waved past
- Treasurer states plainly whether they trust the numbers

**This is the real go-live gate.** If the treasurer does not trust it, do not proceed on
1 April. Move to 1 July and fix what is wrong. A treasurer who was pushed into a system
they distrust will quietly keep the Excel running, and then you have two sets of books —
which is worse than either alone.

### Meeting 7 — Go / No-Go · late March 2027

Formal. Minuted. Half an hour if the preparation is done.

**Go criteria — all must be true:**

| # | Criterion | Evidence |
| --- | --- | --- |
| 1 | Member register verified | ≥ 90% of live units confirmed by the committee |
| 2 | Roles assigned and tested | Every office bearer has logged in and performed their function |
| 3 | Chart of accounts approved | Minuted at Meeting 5 |
| 4 | Opening balances certified | Signed by the treasurer, agreeing to the bank statement |
| 5 | Parallel run passed | One month reproduced, differences explained |
| 6 | **Cut-over certificate prepared** | §6 |
| 7 | Backup and restore rehearsed | Pivot demonstrates it |
| 8 | Support channel agreed | Named contact, response expectation, escalation path |
| 9 | Member communication sent | Privacy notice issued by the association |

**Resolutions to pass:**

- [ ] Adopt CivicSync as the association's system of record for accounts from 1 April 2027
- [ ] Approve the opening statement of affairs as at 31 March 2027
- [ ] Approve the chart of accounts and the roles/permissions matrix
- [ ] Authorise the treasurer to sign the cut-over certificate
- [ ] Record that Excel bookkeeping ceases on 31 March 2027

### Meeting 8 — Go-live · 1 April 2027

See §6.

### Meeting 9 — Hypercare and 30-day review · April–May 2027

- **Daily** check-in for the first week, at least by message
- **Weekly** for the following three
- Log every issue, however small. Early friction is your best product feedback and it
  will never be this honest again
- **30-day review:** what is working, what is not, what the committee wants next

### Meeting 10 — First quarter close · July 2027

Produce Q1 FY 2027-28 statements entirely from CivicSync. The first proof that the
system does the year, not just the day.

---

## 5. Related-party governance

Your wife and father are unit owners **and** office bearers. That is a real advantage —
access, patience, honest feedback, and a customer nobody can poach. It is also a related-
party transaction in an association currently in litigation, which is precisely the
environment where governance gets challenged.

**Handle it once, properly, and it stops being a risk.**

- [ ] **Disclose in writing** before Meeting 1, addressed to the committee: who you are
      related to, what Pivot Solutions is, what you are proposing, and what you will be
      paid
- [ ] **Related office bearers recuse themselves** from the approval vote and it is
      minuted that they did
- [ ] **Approval given by unrelated office bearers**
- [ ] **Arm's-length pricing** — the same rate card you would offer any society, written
      down. Free or discounted is fine; undocumented is not
- [ ] **Minutes reference the disclosure** explicitly

This costs one evening. It protects your family more than it protects you: they are the
ones who would face the allegation, and "the treasurer's son-in-law's company" is an easy
line for a disgruntled member to write.

---

## 6. The cut-over itself

### The week before

| | Task |
| --- | --- |
| Mon | Freeze scope. No changes to CivicSync until after go-live except defects |
| Tue | Final register verification sweep; chase outstanding confirmations |
| Wed | Full backup taken and **restore rehearsed**, checksum recorded in `DATA_PROVENANCE.md` |
| Thu | Dry run of the opening entry on a copy, using estimated balances |
| Fri | Committee reminder: **no Excel entries after 31 March** |

### 31 March 2027 — cut-off

- [ ] Association downloads the **bank statement** as at 31 March
- [ ] Treasurer **counts and certifies cash in hand**
- [ ] Treasurer lists **unpaid vendor bills** and **advances received**
- [ ] Excel is closed for the year and a copy archived, unedited, in the document vault
- [ ] Pivot takes a final snapshot before any opening entry is posted

### 1 April 2027 — go-live

1. Post the opening entry:
   `Dr Bank, Dr Cash, Dr Receivables · Cr Payables, Cr Advances, Cr General Fund`
2. Verify the General Fund is **derived**, not typed
3. Generate the **cut-over certificate** (§6.1)
4. Treasurer signs; upload the signed copy to the document vault
5. Enable transaction entry for the treasurer
6. Confirm the three statements produce from a single opening entry
7. Notify the committee that the books are open

**Elapsed time: under two hours.** This is a short day precisely because history is not
being migrated.

### 6.1 The cut-over certificate

A one-page PDF, generated by CivicSync, signed by the treasurer and countersigned by the
President or General Secretary.

```
BUYER WELFARE ASSOCIATION
Statement of Affairs as at 31 March 2027
Prepared for the opening of accounts in CivicSync, FY 2027-28

ASSETS
  Bank — <bank>, A/c ****<nnnn>        ₹ ..........   per statement dated 31.03.2027
  Cash in hand                         ₹ ..........   certified by the Treasurer
  Receivable from members              ₹ ..........
  Other assets                         ₹ ..........
                                       -----------
                                       ₹ ..........

LIABILITIES
  Payable to vendors                   ₹ ..........
  Advances received from members       ₹ ..........
                                       -----------
                                       ₹ ..........

GENERAL FUND (derived)                 ₹ ..........

Member balances are opened at nil as at 01.04.2027 by resolution of the
Executive Committee dated ........... . Prior dues, if identified subsequently,
will be raised as adjusting entries with reasons recorded.

Payment records prior to 01.04.2027 are retained in CivicSync as a read-only
historical archive (955 records, ₹10,72,892.00) and do not form part of these
accounts.

Certified:  Treasurer ____________    Countersigned: President ____________
```

**This is the document that justifies every number in the system from that day forward.**
It is what turns a future auditor's first question into a short conversation. Store it in
the document vault and give the association a signed copy.

---

## 7. Risks specific to this engagement

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| **Committee rotates and the new one does not honour the decision** | **High** — RWA committees change annually | Get it minuted as an association resolution with a signed agreement. Brief incoming office bearers within a month of any change. Never rely on your family being on the committee |
| **Committee attention is on NBCC, not software** | **High** | Keep meetings short and scheduled well ahead. Position documents as NBCC preparation. Never need more than 30 minutes of their agenda |
| **Treasurer resists losing the Excel** | Medium | Involve them from Meeting 2. The parallel run is theirs, not yours. Never override their judgement on trust |
| **Excel is messier than expected** | **High — already known** | Balances only, never history. Nil member balances by resolution |
| **Members object to their data being on a third-party platform** | Medium | Privacy notice from the association before go-live; DPDP consent captured; portability commitment (§8) |
| **1 April slips** | Medium | Books built before notices to buy five weeks. Fallback 1 July. Decide by mid-March, not late March |
| **You are the sole support** | Certain | Set response expectations honestly at Meeting 1. Do not promise 24×7 |

---

## 8. Pivot's commitments

Put these in the engagement agreement. They cost little and they are what makes a
volunteer committee comfortable handing over their records.

- **Data portability** — the association can export its complete data, in open formats, at
  any time, for any reason, without charge. On exit, Pivot provides a full export within
  30 days and deletes its copies on confirmation
- **The association's data belongs to the association.** Pivot processes, never owns
- **No money passes through Pivot.** Collections settle to the association's own account
  (`COMMERCIAL_STRUCTURE.md` §4)
- **Backups** — daily, with restore rehearsed before go-live and annually thereafter
- **Breach notification** to the association within 48 hours of becoming aware
- **Support** — named contact, stated response expectation, honest about being one person
- **No feature removal** without notice and agreement

---

## 9. After go-live

| When | What |
| --- | --- |
| Week 1 | Daily check-in. Every issue logged |
| Weeks 2–4 | Weekly check-in |
| Day 30 | Formal review with the committee. Minute the outcome |
| Quarterly | Q1 close from CivicSync — the first real proof |
| Before Aug 2027 | **Find a second, unrelated society.** A friendly first customer cannot tell you what a neutral buyer will object to on price or on trust |
| Annually | Brief any incoming committee; re-rehearse restore |

---

## 10. Checklist — the artefacts this plan must produce

- [ ] Written related-party disclosure to the committee
- [ ] Minutes: in-principle approval, with related office bearers recused
- [ ] Signed engagement agreement
- [ ] Signed Data Processing Agreement
- [ ] The association's Excel workbook, archived unedited
- [ ] Minutes: chart of accounts and cut-off policy approved
- [ ] Minutes: member balances opened at nil (or the stated alternative)
- [ ] Treasurer's parallel-run confirmation, in writing
- [ ] Minutes: Go/No-Go resolution
- [ ] **Signed cut-over certificate**
- [ ] Bank statement as at 31 March 2027, archived
- [ ] Privacy notice issued by the association to members
- [ ] Backup checksum recorded in `DATA_PROVENANCE.md`
- [ ] Minutes: 30-day review

Every one of these lives in the association's document vault in CivicSync. The system
holds the evidence of its own adoption, which is a quietly good demonstration of what it
is for.

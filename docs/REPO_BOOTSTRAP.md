# CivicSync — Repository Bootstrap

**Status:** Action required · **Date:** 26 Aug 2026 · **Replaces** Step 1 of Build
Packet 00.

A clean repository, with the prototype preserved and still runnable until cutover.

---

## One correction before you start

> **Do not archive the prototype repository yet.**

GitHub's "Archive repository" makes it **read-only**. The prototype is live software
serving a real society, and it will need a bug fix at some point in the next eleven
months. An archived repo means you cannot commit that fix, cannot merge it, and cannot
redeploy from it.

**Freeze it now, archive it after cutover.** Freezing means: rename it, mark it clearly,
protect `main`, and adopt a rule that only bug fixes land there. That gets you the clean
break you want without removing your ability to keep the society running.

---

## What carries over, and what does not

**Carries over — the planning corpus.** This is eleven documents of decisions and
analysis. It is the most valuable thing in the old repo and it is why the new one starts
informed rather than empty.

| From `DOCS/` | To | Notes |
| --- | --- | --- |
| `PRODUCTION_PLAN.md` | `docs/` | |
| `PLATFORM_ENGINEERING_STANDARDS.md` | `docs/` | |
| `ARCHITECTURE_DDD.md` | `docs/` | |
| `MODULE_REGISTER.md` | `docs/` | |
| `REGISTRY_OWNERSHIP_MODEL.md` | `docs/` | |
| `TECH_STACK.md` | `docs/` | |
| `RELEASE_PLAN.md` | `docs/` | |
| `DEVELOPMENT_PLANNER.md` | `docs/` | Living document |
| `INDEX.md` | `docs/` | The map. Update it in the same commit as any new doc |
| `CUTOVER_PLAN.md` | `docs/` | Living document |
| `COMMERCIAL_STRUCTURE.md` | `docs/` | |
| `COLLECTION_STRATEGY.md` | `docs/` | |
| `CHANNEL_STRATEGY.md` | `docs/` | |
| `MESSAGING_COMPLIANCE.md` | `docs/` | Reference — DLT deferred, retained for when it is needed |
| `DATA_PROVENANCE.md` | `docs/` | **Living document.** Snapshot checksums must not be lost |
| `REPO_BOOTSTRAP.md` | `docs/` | This document |
| `BUILD_PACKET_00.md` | `docs/packets/` | |
| `V1_DATA_FINDINGS.md` | `docs/legacy/` | The ETL is written against this |
| `OLD/FUNCTIONAL_REFERENCE.md` | `docs/legacy/` | **The acceptance-test specification.** The most useful thing the prototype produced |
| `OLD/Civic Sync Logo.png` | `assets/brand/` | |

| From elsewhere | To | Notes |
| --- | --- | --- |
| `scripts/v1_discover.sql` | `ops/migration/legacy/` | |
| `scripts/v1_inventory.sql` | `ops/migration/legacy/` | |
| `scripts/v1_followup.sql` | `ops/migration/legacy/` | |
| `NeonDB_data-*.csv` | `docs/legacy/inventory-2026-08-26.csv` | Rename to something meaningful |

**18 documents, 3 SQL scripts, 1 CSV, 1 logo.** The copy script in Phase B step 3 carries
exactly this set — if you add a document to the prototype after reading this, add it there
too.

**Does not carry over.** All Go source, all React source, all 29 migrations, `repair.go`,
`bwa-frontend/`, `graphify-out/`, `project-memory/`, `AI_HANDOFF.md`, the Vercel
screenshots, every `.env`. They stay in the prototype repo, which stays readable.

The old code remains one `git clone` away for the whole build. You are not burning it —
you are declining to inherit it.

**Never carries over:** `.env` files, database dumps, anything with a credential in it.

---

## Phase A — Freeze the prototype

```bash
cd "/Users/hola/Development Workspace/BWA Management System/civicsync"

# 1. Commit everything outstanding, including migration 029 and the planning docs
git add -A
git commit -m "Final prototype state: WIP, migration 029, and the v2 planning corpus"

# 2. Tag it. Note the name: NOT v1 — that belongs to the first real release.
git tag -a prototype-final-2026-08-26 \
        -m "CivicSync prototype as handed over from Codex. Frozen; bug fixes only."
git push origin main --tags
```

Then on GitHub:

1. **Rename** `PivotSolutions-dev/CivicSync` → **`CivicSync-prototype`**.
   GitHub redirects the old URL, so nothing breaks. This also frees the name `civicsync`
   for the new repo — you cannot have two repos in one org differing only by case.
2. Add a banner at the top of its `README.md`:

   ```markdown
   > **FROZEN — prototype.** Superseded by
   > [PivotSolutions-dev/civicsync](https://github.com/PivotSolutions-dev/civicsync).
   > This repository runs the live pilot society until cutover (target mid-2027).
   > **Bug fixes only. No new features.** Archive after cutover.
   ```

3. Settings → Branches → protect `main`: require a pull request, block force pushes.
   Enough friction to stop a reflex commit.
4. **Do not archive.** Put a calendar reminder for after cutover.

---

## Phase B — Create the new repository

### 1. On GitHub

Create **`PivotSolutions-dev/civicsync`** — **private**, no README, no .gitignore, no
licence. An empty repo, so the first commit is yours.

Then Settings:

| Setting | Value | Why |
| --- | --- | --- |
| Default branch | `main` | |
| Merge button | **Squash only** — disable merge commits and rebase | One packet, one commit on `main`. The history reads as the build log |
| Auto-delete head branches | On | |
| Branch protection on `main` | Require a PR · require status checks (`build`) · block force push · no bypass | The CI guards only mean something if they can block a merge |
| Issues | On | Your backlog and the Release 2.0 parking lot |
| Wiki, Projects, Discussions | Off | Docs live in `docs/` |
| Secret scanning + push protection | **On** | Blocks a committed key at push time. Free on private repos under GitHub Advanced Security's free tier; if unavailable, `gitleaks` in CI covers it |
| Dependabot alerts + security updates | On | |

**Branch protection with "no bypass" means you cannot push to `main` directly, including
yourself.** That is the intent. Every packet becomes a PR, CI runs, and it is a natural
review checkpoint for us — which fits how we agreed to work.

### 2. Locally

**Clone to a new folder.** Do not reuse or rename the prototype's folder — you want both
on disk during the build.

```bash
cd "/Users/hola/Development Workspace/BWA Management System"
git clone git@github.com:PivotSolutions-dev/civicsync.git civicsync-app
cd civicsync-app
```

> **Tell me when you have done this.** This session is connected to
> `…/BWA Management System/civicsync`. Add the new folder in the Claude desktop app
> ("Add folder") so I can read and write in it — otherwise I am reviewing a repo I
> cannot see.

### 3. Skeleton and carry-over

```bash
OLD="../civicsync"          # change if you have already renamed it to civicsync-prototype

mkdir -p contracts db/{migrations,queries,seeds} api admin mobile \
         ops/{checks,compose,migration/legacy} \
         docs/{adr,packets,legacy} assets/brand

# --- the planning corpus: 16 documents ---
for f in PRODUCTION_PLAN PLATFORM_ENGINEERING_STANDARDS ARCHITECTURE_DDD \
         MODULE_REGISTER REGISTRY_OWNERSHIP_MODEL TECH_STACK RELEASE_PLAN \
         DEVELOPMENT_PLANNER INDEX CUTOVER_PLAN COMMERCIAL_STRUCTURE \
         COLLECTION_STRATEGY CHANNEL_STRATEGY MESSAGING_COMPLIANCE \
         DATA_PROVENANCE REPO_BOOTSTRAP; do
  cp "$OLD/DOCS/$f.md" docs/ || echo "MISSING: $f.md"
done

# --- build packets ---
cp "$OLD/DOCS/BUILD_PACKET_00.md" docs/packets/

# --- legacy reference: the ETL and acceptance tests are written against these ---
cp "$OLD/DOCS/V1_DATA_FINDINGS.md"         docs/legacy/
cp "$OLD/DOCS/OLD/FUNCTIONAL_REFERENCE.md" docs/legacy/
cp "$OLD"/NeonDB_data-*.csv                docs/legacy/inventory-2026-08-26.csv

# --- migration tooling ---
cp "$OLD"/scripts/v1_*.sql ops/migration/legacy/

# --- brand ---
cp "$OLD/DOCS/OLD/Civic Sync Logo.png" assets/brand/civicsync-logo.png

# --- verify: expect 16, 1, 3, 3 ---
echo "docs/          $(ls docs/*.md | wc -l)   (expect 16)"
echo "docs/packets/  $(ls docs/packets/*.md | wc -l)   (expect 1)"
echo "docs/legacy/   $(ls docs/legacy/* | wc -l)   (expect 3)"
echo "ops/migration/legacy/ $(ls ops/migration/legacy/*.sql | wc -l)   (expect 3)"
```

Any `MISSING:` line means a document did not copy — stop and find out why before
committing.

Then create `.gitignore`, `.editorconfig`, `docker-compose.yml` and `.env.example` from
**Build Packet 00 Step 2** — and note that `.gitignore` must exist *before* the first
commit, so no `.env` or `.dump` is ever in the history.

### 4. Root `README.md`

```markdown
# CivicSync

Multi-tenant operations platform for residential welfare associations.
Admin console (web) · Resident app (Flutter) · Go API on PostgreSQL.

**Status:** pre-release. Release 1.0 target mid-2027.
Supersedes the prototype at
[CivicSync-prototype](https://github.com/PivotSolutions-dev/CivicSync-prototype),
which runs the live pilot society until cutover.

## Start here

| Document | What it settles |
| --- | --- |
| [docs/PRODUCTION_PLAN.md](docs/PRODUCTION_PLAN.md) | Scope, tenancy, migration strategy |
| [docs/PLATFORM_ENGINEERING_STANDARDS.md](docs/PLATFORM_ENGINEERING_STANDARDS.md) | Mechanism-level rules and the CI checks that enforce them |
| [docs/ARCHITECTURE_DDD.md](docs/ARCHITECTURE_DDD.md) | Layering, aggregates, what we deliberately do not do |
| [docs/MODULE_REGISTER.md](docs/MODULE_REGISTER.md) | Module boundaries, ownership, packet map |
| [docs/REGISTRY_OWNERSHIP_MODEL.md](docs/REGISTRY_OWNERSHIP_MODEL.md) | Title, occupancy and membership |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | Every technology choice, and the rejected ones |
| [docs/RELEASE_PLAN.md](docs/RELEASE_PLAN.md) | 17 packets, capacity, milestone dates |
| [docs/adr/](docs/adr/) | Architecture decision records |

## Local development

    cp .env.example .env
    make up
    make migrate-up
    make run

See `docs/packets/BUILD_PACKET_00.md`.

## Non-negotiables

1. Every tenant table carries `org_id`, `FORCE ROW LEVEL SECURITY`, and a policy.
2. File content lives in object storage. Never in PostgreSQL.
3. Money is an append-only ledger. Nothing is hard-deleted.
4. No enums, lists, rates or permissions hardcoded. They are master data.
5. Migrations are the only schema authority.

CI enforces 1, 2, 4 and 5 mechanically. Do not bypass a failing check.

## Licence

Proprietary. © Pivot Solutions.
```

### 5. First commit — straight to `main`, before protection is enabled

```bash
git add -A
git commit -m "Initial commit: planning corpus, repo skeleton, legacy reference"
git push -u origin main
```

**Now** turn on branch protection. Everything after this is a pull request.

---

## Phase C — Branch strategy

You asked to "start with a V1 branch." I would not, and here is why.

In a fresh repository there is nothing to branch *from* — a long-lived `v1` branch would
be a parallel trunk with no counterpart, which is all the cost of a branching model and
none of the benefit. And `v1` as a name collides with Release 1.0, so "merge v1" becomes
ambiguous the moment Release 1.1 exists.

**Use this instead:**

```
main                          always green, always deployable
 ├── packet/00-foundation     short-lived, one per packet
 ├── packet/01-platform-core
 └── fix/receipt-rounding     short-lived, for bugs
```

- **`main` is trunk.** Protected. Every change arrives by squash-merged PR.
- **One branch per packet**, deleted on merge. A packet is 1–4 weeks — short enough not
  to rot.
- **Releases are tags, not branches:** `v1.0.0` at cutover, `v1.1.0` for the resident
  app, `v2.0.0` for the roadmap modules.
- **A release branch appears only when you need one** — the first time you must patch
  production while `main` has moved on. That is `release/1.0`, cut from the `v1.0.0` tag,
  at go-live. Not before.

This gives you what you actually want from branching — a green trunk, a review gate, a
readable history — without maintaining a second line of development for a product that
has not shipped.

```bash
git checkout -b packet/00-foundation
# … build Packet 00 …
git push -u origin packet/00-foundation
gh pr create --title "Packet 00: foundation" --body "Exit criteria: …"
```

### Commit convention

Conventional Commits, so the history is greppable and can generate a changelog later:

```
feat(registry): add ownership transfer workflow
fix(finance): correct rounding on partial receipt allocation
chore(ci): add BYTEA guard
docs(adr): ADR-0004 title and occupancy model
refactor(store): extract invoice queries to sqlc
```

Scope is the **module code** from the Module Register. That way `git log --grep finance`
tells you the story of one module.

---

## Checklist

- [ ] Commit and tag `prototype-final-2026-08-26` in the old repo
- [ ] Rename `CivicSync` → `CivicSync-prototype`; add the frozen banner; protect `main`
- [ ] **Do not archive** — calendar reminder for after cutover
- [ ] Create private `PivotSolutions-dev/civicsync`, empty
- [ ] Clone to `…/BWA Management System/civicsync-app`
- [ ] **Add the new folder in the Claude desktop app**
- [ ] Create the skeleton and copy the carry-over files
- [ ] Write `.gitignore` **before** the first commit
- [ ] Write `README.md`
- [ ] First commit and push to `main`
- [ ] Enable branch protection, squash-only merges, secret scanning, Dependabot
- [ ] `git checkout -b packet/00-foundation` and start Build Packet 00 at **Step 2**

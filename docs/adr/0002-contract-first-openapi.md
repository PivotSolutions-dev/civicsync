# ADR-0002: Contract-first OpenAPI

- Status: Accepted
- Date: 2026-08-26

## Context

Three surfaces: Go API, TypeScript admin, Dart/Flutter resident app. Dart and TypeScript
share no type system. The prototype's API models were `unknown`/`any`, producing an
avoidable class of integration bugs.

## Decision

`contracts/openapi.yaml` is the source of truth, hand-written and reviewed. Code is
generated from it: `oapi-codegen` (`fiber-v3-server`, strict mode) for Go, `orval` for the
TypeScript client and TanStack Query hooks, `openapi-generator` (`dart-dio`) for Flutter.
CI fails if generated code differs from the committed spec.

## Consequences

- Schema changes appear in review as spec diffs.
- A field renamed in Go cannot silently break the mobile app.
- The spec must be updated before implementation — deliberate friction.
- Release 0.5 builds the resident API endpoints even though no resident UI ships, so the
  portal and the Flutter app are later pure frontend work.

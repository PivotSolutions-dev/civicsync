// Package domain holds pure business types and rules.
//
// It imports nothing from internal/app, internal/store, internal/http, or
// internal/platform — enforced by ops/checks/check_layers.sh in CI.
//
// If you want a database handle or an HTTP request in here, the logic belongs in
// internal/app instead.
package domain

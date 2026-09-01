// Package reqctx carries request-scoped identity on a real context.Context.
//
// Fiber runs on fasthttp, which pools and recycles the request context once the
// handler returns. Two consequences shape this package:
//
//  1. fiber.Ctx.Context() returns context.Background() unless something has called
//     SetContext. Middleware() derives a context from c.RequestCtx() instead, so a
//     client disconnect cancels in-flight database work.
//
//  2. Anything outliving the request — a River job, a goroutine — must NOT hold the
//     request context. Detach() copies the identity into a fresh context instead.
package reqctx

import (
	"context"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/requestid"
	"github.com/google/uuid"
)

type key int

const (
	keyRequestID key = iota
	keyOrgID
	keyUserID
)

// Middleware attaches a cancellable, identity-bearing context to the Fiber Ctx.
// Register it AFTER requestid.New().
func Middleware() fiber.Handler {
	return func(c fiber.Ctx) error {
		ctx := context.WithValue(c.RequestCtx(), keyRequestID, requestid.FromContext(c))
		c.SetContext(ctx)
		return c.Next()
	}
}

func WithOrg(ctx context.Context, orgID uuid.UUID) context.Context {
	return context.WithValue(ctx, keyOrgID, orgID)
}

func WithUser(ctx context.Context, userID uuid.UUID) context.Context {
	return context.WithValue(ctx, keyUserID, userID)
}

func RequestID(ctx context.Context) string {
	v, _ := ctx.Value(keyRequestID).(string)
	return v
}

func OrgID(ctx context.Context) (uuid.UUID, bool) {
	v, ok := ctx.Value(keyOrgID).(uuid.UUID)
	return v, ok
}

func UserID(ctx context.Context) (uuid.UUID, bool) {
	v, ok := ctx.Value(keyUserID).(uuid.UUID)
	return v, ok
}

// Detach returns a background context carrying only the copied request identity.
//
// Use this for anything that outlives the request. Passing the request context to a
// background job is the classic fasthttp bug: the context is recycled underneath you
// and you read another request's values.
func Detach(ctx context.Context) context.Context {
	out := context.Background()
	if v := RequestID(ctx); v != "" {
		out = context.WithValue(out, keyRequestID, v)
	}
	if v, ok := OrgID(ctx); ok {
		out = context.WithValue(out, keyOrgID, v)
	}
	if v, ok := UserID(ctx); ok {
		out = context.WithValue(out, keyUserID, v)
	}
	return out
}

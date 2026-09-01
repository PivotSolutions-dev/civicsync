package http

import (
	"errors"
	"fmt"

	"github.com/gofiber/fiber/v3"

	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/reqctx"
)

const problemJSON = "application/problem+json"

// errorHandler renders every error as RFC 9457 problem+json, so clients can branch on
// a stable `type` instead of parsing prose.
func errorHandler(c fiber.Ctx, err error) error {
	status := fiber.StatusInternalServerError
	title := "Internal Server Error"

	var fe *fiber.Error
	if errors.As(err, &fe) {
		status = fe.Code
		title = fe.Message
	}

	body := fiber.Map{
		"type":       fmt.Sprintf("https://civicsync.app/problems/%d", status),
		"title":      title,
		"status":     status,
		"request_id": reqctx.RequestID(c.Context()),
	}

	return c.Status(status).JSON(body, problemJSON)
}

package http

import (
	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/logger"
	recoverer "github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/requestid"

	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/database"
	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/reqctx"
)

func NewApp(db *database.DB) *fiber.App {
	app := fiber.New(fiber.Config{
		AppName:      "civicsync-api",
		ErrorHandler: errorHandler,
	})

	app.Use(requestid.New())
	app.Use(recoverer.New())
	app.Use(logger.New())
	app.Use(reqctx.Middleware()) // must come after requestid.New()

	app.Get("/health", func(c fiber.Ctx) error {
		if err := db.Pool.Ping(c.Context()); err != nil {
			return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
				"status": "degraded",
				"detail": "database unreachable",
			})
		}
		return c.JSON(fiber.Map{"status": "ok"})
	})

	return app
}

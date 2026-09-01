package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/config"
	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/database"
	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/logging"

	apihttp "github.com/PivotSolutions-dev/civicsync/api/internal/http"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	log := logging.New(cfg.Env)

	ctx, stop := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := database.Open(ctx, cfg.AppDatabaseURL)
	if err != nil {
		return err
	}
	defer db.Close()

	app := apihttp.NewApp(db)
	addr := net.JoinHostPort("", fmt.Sprint(cfg.Port))

	errCh := make(chan error, 1)
	go func() {
		log.Info("api listening", "port", cfg.Port, "env", cfg.Env)
		if err := app.Listen(addr); err != nil {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		log.Info("shutting down")
	}

	shutdownCtx, cancel := context.WithTimeout(
		context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	return app.ShutdownWithContext(shutdownCtx)
}

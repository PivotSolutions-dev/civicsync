SHELL := /bin/bash

# Load .env so every target sees the same configuration the app does.
# `-include` (not `include`) so a missing .env is not fatal — CI supplies env vars directly.
-include .env
export

DB_URL ?= $(DATABASE_URL)

.PHONY: init up down logs migrate-up migrate-down migrate-redo \
        check-rls check-blobs check-layers lint test build run verify ci

# Run once after cloning. Points git at the versioned hooks in .githooks/
init:
	git config core.hooksPath .githooks
	@echo "git hooks enabled"

up:
	docker compose up -d
	@printf "waiting for postgres"
	@until docker compose exec -T postgres pg_isready -U civicsync >/dev/null 2>&1; \
	  do printf "."; sleep 1; done; echo " ready"

down:
	docker compose down

logs:
	docker compose logs -f

migrate-up:
	migrate -path db/migrations -database "$(DB_URL)" up

migrate-down:
	migrate -path db/migrations -database "$(DB_URL)" down 1

# Proves every migration is reversible. Run before committing a new migration.
migrate-redo:
	migrate -path db/migrations -database "$(DB_URL)" down -all
	migrate -path db/migrations -database "$(DB_URL)" up

# Run through the container so the psql client always matches the server.
check-rls:
	docker compose exec -T postgres psql -U civicsync -d civicsync \
	  -v ON_ERROR_STOP=1 -f /checks/check_rls.sql

check-blobs:
	docker compose exec -T postgres psql -U civicsync -d civicsync \
	  -v ON_ERROR_STOP=1 -f /checks/check_no_blobs.sql

check-layers:
	./ops/checks/check_layers.sh

lint:
	cd api && go vet ./... && golangci-lint run

test:
	cd api && go test ./...

build:
	cd api && go build -o bin/api ./cmd/api

# Leading `-` ignores the exit status: Ctrl-C makes `go run` exit non-zero even
# after a clean graceful shutdown, and the resulting "Error 1" is pure noise.
run:
	-cd api && go run ./cmd/api

# Fast checks — no Docker, no database. This is what the pre-push hook runs.
verify: check-layers lint test build

# Everything, including the database checks. This is what CI runs.
ci: migrate-redo check-rls check-blobs check-layers lint test build

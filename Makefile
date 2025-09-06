.PHONY: help build up down logs clean test backend-shell redis-cli

# Default target
help:
	@echo "Available commands:"
	@echo "  make build         - Build Docker images"
	@echo "  make up            - Start all services"
	@echo "  make up-dev        - Start services in development mode"
	@echo "  make down          - Stop all services"
	@echo "  make logs          - View logs from all services"
	@echo "  make logs-api      - View API logs"
	@echo "  make clean         - Remove containers and volumes"
	@echo "  make test          - Run tests"
	@echo "  make backend-shell - Open shell in backend container"
	@echo "  make redis-cli     - Open Redis CLI"

# Build Docker images
build:
	docker-compose build

# Start services
up:
	docker-compose up -d

# Start services in development mode
up-dev:
	docker-compose -f docker-compose.dev.yml up

# Stop services
down:
	docker-compose down

# View logs
logs:
	docker-compose logs -f

logs-api:
	docker-compose logs -f api

logs-redis:
	docker-compose logs -f redis

# Clean up
clean:
	docker-compose down -v
	docker system prune -f

# Run tests
test:
	docker-compose exec api pytest

# Shell access
backend-shell:
	docker-compose exec api /bin/bash

# Redis CLI
redis-cli:
	docker-compose exec redis redis-cli

# Health check
health:
	curl http://localhost:5000/health | jq

# Test synthesis
test-synthesis:
	@echo "Testing text synthesis..."
	curl -X POST http://localhost:5000/synthesize \
		-H "Content-Type: application/json" \
		-d '{"text": "こんにちは、これはテストです", "voice": "ja-JP-Standard-A"}' \
		--output test_output.wav
	@echo "Audio saved to test_output.wav"
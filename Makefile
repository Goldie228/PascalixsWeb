.PHONY: setup dev infra stop logs restart status clean help test test-all test-auth test-web test-minecraft test-mailer test-coverage test-parallel test-parallel-auth test-parallel-web test-parallel-minecraft test-parallel-mailer frontend frontend-dev frontend-build parallel-setup

# Первоначальная настройка окружения
setup:
	@echo "🔧 Настройка окружения..."
	@bin/setup

# Запуск всех сервисов
dev: infra
	@echo "🚀 Запуск всех сервисов..."
	@foreman start

# Запуск только инфраструктуры (Redis, Kafka, ClickHouse)
infra:
	@echo "🏗️  Запуск инфраструктуры..."
	@docker compose up -d
	@echo "⏳ Ожидание готовности сервисов..."
	@sleep 5
	@docker compose ps

# Остановка всех сервисов
stop:
	@echo "🛑 Остановка всех сервисов..."
	@docker compose down

# Просмотр логов
logs:
	@docker compose logs -f

# Перезапуск всех сервисов
restart: stop dev

# Статус процессов
status:
	@docker ps

# Очистка (остановка + удаление контейнеров)
clean:
	@echo "🧹 Очистка..."
	@docker compose down -v

# ── Последовательный запуск тестов ──────────────────────────────────
# Запуск всех тестов (последовательно по всем сервисам)
test: test-auth test-web test-minecraft test-mailer
	@echo "✅ Все тесты завершены"

# Алиас для test — запуск всех тестов последовательно
test-all: test

# Тесты identity-service (последовательно)
test-auth:
	@echo "🧪 Запуск тестов identity-service..."
	@cd identity-service && bundle exec rspec --format documentation || (echo "❌ Тесты identity-service провалены" && exit 1)
	@echo "✅ Тесты identity-service пройдены"

# Тесты web-portal
test-web:
	@echo "🧪 Запуск тестов web-portal..."
	@cd web-portal && bundle exec rspec --format documentation || (echo "❌ Тесты web-portal провалены" && exit 1)
	@echo "✅ Тесты web-portal пройдены"

# Тесты game-service
test-minecraft:
	@echo "🧪 Запуск тестов game-service..."
	@cd game-service && bundle exec rspec --format documentation || (echo "❌ Тесты game-service провалены" && exit 1)
	@echo "✅ Тесты game-service пройдены"

# Тесты notification-service
test-mailer:
	@echo "🧪 Запуск тестов notification-service..."
	@cd notification-service && bundle exec rspec --format documentation || (echo "❌ Тесты notification-service провалены" && exit 1)
	@echo "✅ Тесты notification-service пройдены"

# ── Параллельный запуск тестов ──────────────────────────────────────
# Настройка parallel-баз (identity-service)
parallel-setup:
	@echo "🔧 Настройка parallel test баз..."
	@cd identity-service && bash bin/parallel_setup.sh 4

# Все тесты параллельно (4 процесса на каждый сервис, сервисы последовательно)
test-parallel: test-parallel-auth test-parallel-web test-parallel-minecraft test-parallel-mailer
	@echo "✅ Все тесты завершены (параллельно)"

# Identity service — параллельно (4 процесса)
test-parallel-auth:
	@echo "🧪 Запуск тестов identity-service (параллельно, 4 процесса)..."
	@cd identity-service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты identity-service провалены" && exit 1)
	@echo "✅ Тесты identity-service пройдены"

# Web portal — параллельно (4 процесса)
test-parallel-web:
	@echo "🧪 Запуск тестов web-portal (параллельно, 4 процесса)..."
	@cd web-portal && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты web-portal провалены" && exit 1)
	@echo "✅ Тесты web-portal пройдены"

# Game service — параллельно (4 процесса)
test-parallel-minecraft:
	@echo "🧪 Запуск тестов game-service (параллельно, 4 процесса)..."
	@cd game-service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты game-service провалены" && exit 1)
	@echo "✅ Тесты game-service пройдены"

# Notification service — параллельно (4 процесса)
test-parallel-mailer:
	@echo "🧪 Запуск тестов notification-service (параллельно, 4 процесса)..."
	@cd notification-service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты notification-service провалены" && exit 1)
	@echo "✅ Тесты notification-service пройдены"

# ── Frontend ────────────────────────────────────────────────────────
frontend:
	@echo "🚀 Запуск frontend..."
	@cd frontend && npm install && npm run dev

frontend-dev:
	@echo "🚀 Запуск frontend (dev mode)..."
	@cd frontend && npm run dev

frontend-build:
	@echo "🔨 Сборка frontend..."
	@cd frontend && npm run build

frontend-lint:
	@echo "🔍 Линтинг frontend..."
	@cd frontend && npm run lint

# Тесты с отчётом о покрытии (требуется simplecov)
test-coverage:
	@echo "🧪 Запуск тестов с покрытием..."
	@COVERAGE=true bundle exec rspec --format documentation || (echo "❌ Тесты с покрытием провалены" && exit 1)
	@echo "✅ Тесты с покрытием завершены"

# Помощь
help:
	@echo "Доступные команды:"
	@echo "  make setup    - Первоначальная настройка окружения"
	@echo "  make dev      - Запуск всех сервисов"
	@echo "  make infra    - Запуск только инфраструктуры"
	@echo "  make stop     - Остановка всех сервисов"
	@echo "  make logs     - Просмотр логов"
	@echo "  make restart  - Перезапуск всех сервисов"
	@echo "  make status   - Статус процессов"
	@echo "  make clean    - Остановка + удаление данных"
	@echo ""
	@echo "🧪 Тесты (последовательно):"
	@echo "  make test           - Все тесты"
	@echo "  make test-auth      - Тесты identity-service"
	@echo "  make test-web       - Тесты web-portal"
	@echo "  make test-minecraft - Тесты game-service"
	@echo "  make test-mailer    - Тесты notification-service"
	@echo "  make test-coverage  - Тесты с отчётом о покрытии"
	@echo ""
	@echo "⚡ Тесты (параллельно — БЫСТРЕЕ!):"
	@echo "  make parallel-setup          - Настройка parallel-баз"
	@echo "  make test-parallel           - Все тесты параллельно"
	@echo "  make test-parallel-auth      - Identity параллельно"
	@echo "  make test-parallel-web       - Web-portal параллельно"
	@echo "  make test-parallel-minecraft - Game параллельно"
	@echo "  make test-parallel-mailer    - Notification параллельно"
	@echo ""
	@echo "🖥️  Frontend:"
	@echo "  make frontend       - Запуск frontend"
	@echo "  make frontend-dev   - Frontend dev mode"
	@echo "  make frontend-build - Сборка frontend"
	@echo "  make frontend-lint  - Линтинг frontend"
	@echo "  make help           - Показать эту справку"

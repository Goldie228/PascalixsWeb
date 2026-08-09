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

# Тесты auth_service (последовательно)
test-auth:
	@echo "🧪 Запуск тестов auth_service..."
	@cd auth_service && bundle exec rspec --format documentation || (echo "❌ Тесты auth_service провалены" && exit 1)
	@echo "✅ Тесты auth_service пройдены"

# Тесты web_service
test-web:
	@echo "🧪 Запуск тестов web_service..."
	@cd web_service && bundle exec rspec --format documentation || (echo "❌ Тесты web_service провалены" && exit 1)
	@echo "✅ Тесты web_service пройдены"

# Тесты minecraft_service
test-minecraft:
	@echo "🧪 Запуск тестов minecraft_service..."
	@cd minecraft_service && bundle exec rspec --format documentation || (echo "❌ Тесты minecraft_service провалены" && exit 1)
	@echo "✅ Тесты minecraft_service пройдены"

# Тесты mailer_service
test-mailer:
	@echo "🧪 Запуск тестов mailer_service..."
	@cd mailer_service && bundle exec rspec --format documentation || (echo "❌ Тесты mailer_service провалены" && exit 1)
	@echo "✅ Тесты mailer_service пройдены"

# ── Параллельный запуск тестов ──────────────────────────────────────
# Настройка parallel-баз (auth_service)
parallel-setup:
	@echo "🔧 Настройка parallel test баз..."
	@cd auth_service && bash bin/parallel_setup.sh 4

# Все тесты параллельно (4 процесса на каждый сервис, сервисы последовательно)
test-parallel: test-parallel-auth test-parallel-web test-parallel-minecraft test-parallel-mailer
	@echo "✅ Все тесты завершены (параллельно)"

# Auth service — параллельно (4 процесса)
test-parallel-auth:
	@echo "🧪 Запуск тестов auth_service (параллельно, 4 процесса)..."
	@cd auth_service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты auth_service провалены" && exit 1)
	@echo "✅ Тесты auth_service пройдены"

# Web service — параллельно (4 процесса)
test-parallel-web:
	@echo "🧪 Запуск тестов web_service (параллельно, 4 процесса)..."
	@cd web_service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты web_service провалены" && exit 1)
	@echo "✅ Тесты web_service пройдены"

# Minecraft service — параллельно (4 процесса)
test-parallel-minecraft:
	@echo "🧪 Запуск тестов minecraft_service (параллельно, 4 процесса)..."
	@cd minecraft_service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты minecraft_service провалены" && exit 1)
	@echo "✅ Тесты minecraft_service пройдены"

# Mailer service — параллельно (4 процесса)
test-parallel-mailer:
	@echo "🧪 Запуск тестов mailer_service (параллельно, 4 процесса)..."
	@cd mailer_service && bundle exec parallel_rspec -n 4 --format documentation || (echo "❌ Тесты mailer_service провалены" && exit 1)
	@echo "✅ Тесты mailer_service пройдены"

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
	@echo "  make test-auth      - Тесты auth_service"
	@echo "  make test-web       - Тесты web_service"
	@echo "  make test-minecraft - Тесты minecraft_service"
	@echo "  make test-mailer    - Тесты mailer_service"
	@echo "  make test-coverage  - Тесты с отчётом о покрытии"
	@echo ""
	@echo "⚡ Тесты (параллельно — БЫСТРЕЕ!):"
	@echo "  make parallel-setup          - Настройка parallel-баз"
	@echo "  make test-parallel           - Все тесты параллельно"
	@echo "  make test-parallel-auth      - Auth параллельно"
	@echo "  make test-parallel-web       - Web параллельно"
	@echo "  make test-parallel-minecraft - Minecraft параллельно"
	@echo "  make test-parallel-mailer    - Mailer параллельно"
	@echo ""
	@echo "🖥️  Frontend:"
	@echo "  make frontend       - Запуск frontend"
	@echo "  make frontend-dev   - Frontend dev mode"
	@echo "  make frontend-build - Сборка frontend"
	@echo "  make frontend-lint  - Линтинг frontend"
	@echo "  make help           - Показать эту справку"

# PascalixsWeb

Веб-платформа игрового сообщества (Minecraft-сервер): профили игроков, аутентификация через Discord, Google/YouTube, Twitch и TikTok, донаты, двухфакторная защита, уведомления и админ-панель.

Монорепо: 4 Rails-микросервиса + React SPA + инфраструктура (Redis, Kafka, ClickHouse, MySQL).

## Архитектура

Браузер общается только с **web-portal** (`:3000`) — он выполняет роль гейтвея: агрегирует данные и проксирует запросы в доменные сервисы (identity-service, game-service, notification-service). Всё «несрочное» (почта, push, синхронизация данных) — асинхронные события Kafka.

Диаграмма, роли сервисов, межсервисная аутентификация и статус миграции UI — в [ARCHITECTURE.md](./ARCHITECTURE.md).

## Возможности

- Регистрация и вход: email/пароль + OAuth (Discord, Google/YouTube, Twitch, TikTok)
- Привязка Minecraft-аккаунта, синхронизация с сервером (AuthMe / LuckPerms)
- Двухфакторная аутентификация (OTP-коды)
- Профили: личный, публичный (по nickname), список игроков
- Донаты: товары, покупки, цены разбана/размьюта, спонсоры
- Наказания и апелляции (с ответами администраторов)
- Админ-панель: пользователи, наказания, апелляции, жалобы, покупки, товары, аватары, галерея, статистика
- Уведомления: email (SMTP), push (FCM), в-приложении
- Галерея, PWA, реалтайм-обновления (ActionCable)
- Локализация: ru + en

## Стек технологий

| Слой | Технологии |
|---|---|
| Backend | Ruby 3.4.10, Rails 8.1.3, Karafka (Kafka), Sidekiq, RSpec |
| Frontend | React 19, Vite 6, TypeScript 5.6, Tailwind CSS 4 + DaisyUI 5 |
| SPA-библиотеки | react-router 7, @tanstack/react-query 5, zustand 5, i18next, axios, react-hook-form + zod |
| Данные | MySQL 8 (`identity_service`, `game_service`), ClickHouse 23.8 (аналитика), Redis 7 (сессии, кэш, очереди) |
| Инфраструктура | Docker Compose, Kafka (Confluent 7.5) + ZooKeeper, foreman, mise |

## Требования

- Docker + Docker Compose
- Ruby 3.4.10 + Bundler (версии зафиксированы в `.mise.toml` и `.ruby-version` — проще всего ставить через `mise`)
- Node.js 20+ (mise: 24) + npm
- `foreman` — для запуска сервисов на хосте: `gem install foreman`
- Опционально: `cloudflared` (туннель)

## Быстрый старт

Все команды — через `make` (полный список: `make help`).

```bash
make setup    # bin/setup: mise install (Ruby/Node), gem install bundler,
              # bundle install в 4 сервисах, npm install (web-portal),
              # создаёт .env из .env.example (если его нет)
make infra    # docker compose up -d: инфраструктура + контейнеры сервисов
make dev      # make infra + foreman start: сервисы на хосте (Procfile)
make frontend # cd frontend && npm install && npm run dev (Vite, :5173)
make logs     # docker compose logs -f
make stop     # docker compose down
```

После `make setup` заполните `.env` (шаблон — `.env.example`): минимум — `INTER_SERVICE_API_KEY`, OAuth-ключи провайдеров, SMTP для отправки почты.

Точки входа:

- Фронтенд: http://localhost:5173
- web-portal: http://localhost:3000

Полезно:

```bash
make restart   # stop + dev
make status    # docker ps
make clean     # docker compose down -v (остановка + удаление данных)
```

> **Два режима запуска.** `make infra` поднимает **всё** из `docker-compose.yml` (инфраструктура + 4 Rails-контейнера + nginx-фронтенд). `make dev` дополнительно запускает процессы **на хосте** через foreman: identity (`:3002`), game (`:3004`), notification (`:3003`), vite-фронтенд (`:5173`) — web-portal в Procfile отсутствует и в host-режиме запускается отдельно: `cd web-portal && bin/dev`. Порты host-процессов задаются в `.env` (`AUTH_SERVICE_PORT`, `MINECRAFT_SERVICE_PORT`, `MAILER_SERVICE_PORT`); переменные `*_SERVICE_URL` должны указывать на те же порты. Не запускайте контейнеры и host-процессы одновременно — они конфликтуют на портах 3003/3004.

## Запуск фронтенда

```bash
make frontend        # npm install + npm run dev (Vite, :5173, hot-reload)
make frontend-dev    # только npm run dev (если зависимости уже установлены)
make frontend-build  # production-сборка: tsc -b && vite build
make frontend-lint   # ESLint
```

Vite-сервер проксирует `/api/v1/*` на `VITE_API_BASE_URL` (по умолчанию `http://localhost:3000`, т.е. web-portal) — см. `frontend/vite.config.ts`. Поэтому SPA «видит» один адрес API.

## Тесты

```bash
make test              # все 4 сервиса последовательно (RSpec)
make test-auth         # identity-service
make test-web          # web-portal
make test-minecraft    # game-service
make test-mailer       # notification-service

make parallel-setup    # один раз: создаёт parallel-тестовые БД
make test-parallel     # все сервисы по 4 процесса (parallel_rspec) — быстрее
make test-coverage     # тесты с отчётом о покрытии (COVERAGE=true)
```

Фронтенд (Vitest + Testing Library):

```bash
cd frontend
npm run test:run       # один прогон
npm run test           # watch-режим
```

## Сервисы

| Сервис | Порт (хост) | Роль |
|---|---|---|
| `frontend` | 5173 | React SPA (локально — Vite; в Docker — nginx) |
| `web-portal` | 3000 | Гейтвей, SSR-страницы, админка, ActionCable |
| `identity-service` | 3001 | Аутентификация, пользователи, OAuth, 2FA, донаты, апелляции |
| `game-service` | 3003 | Minecraft-сервер: игроки, наказания, синхронизация |
| `notification-service` | 3004 | Уведомления: email (SMTP), push (FCM) |
| `redis` | 6380 | Сессии, кэш, очереди (db 0–3: по одной на сервис) |
| `kafka` + `zookeeper` | 29093 / 9093 (zk: 2181) | Асинхронные события |
| `clickhouse` | 8124 (native: 9001) | Аналитика, статистика |
| `mysql` | 3307 | БД `identity_service` и `game_service` |

## Структура репозитория

```
├── frontend/               # React SPA (Vite + TypeScript)
├── web-portal/             # Rails: гейтвей, SSR-страницы, админка
├── identity-service/       # Rails: auth, пользователи, донаты, апелляции
├── game-service/           # Rails: Minecraft-интеграция
├── notification-service/   # Rails: email/push-уведомления
├── bin/setup               # скрипт первоначальной настройки
├── Makefile                # команды dev/infra/test
├── Procfile                # процессы foreman для host-разработки
├── docker-compose.yml      # инфраструктура и контейнеры сервисов
├── .env.example            # шаблон переменных окружения
└── .opencode/context/      # знаниебаза проекта (архитектура, паттерны, стандарты)
```

## Локализация

UI поддерживает **ru** и **en** (i18next + browser-languagedetector; детекция: querystring → localStorage → navigator, fallback — `en`). Ключи — в `frontend/src/i18n/locales/ru.json` и `en.json`. Бэкенд локализован через `I18n` с локалью в URL (`/:locale` — см. `web-portal/config/routes.rb`).

## Документация

- [ARCHITECTURE.md](./ARCHITECTURE.md) — архитектура, межсервисное взаимодействие, статус миграции
- [CONTRIBUTING.md](./CONTRIBUTING.md) — как вносить изменения
- README сервисов: [web-portal](./web-portal/README.md) · [identity-service](./identity-service/README.md) · [game-service](./game-service/README.md) · [notification-service](./notification-service/README.md)
- Стандарты документации: `.opencode/context/core/standards/documentation.md`

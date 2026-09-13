# Архитектура — PascalixsWeb

Документ отвечает на вопросы «как устроено и почему». Быстрый старт и команды — в [README.md](./README.md), правила для контрибьюторов — в [CONTRIBUTING.md](./CONTRIBUTING.md).

## Обзор системы

PascalixsWeb — микросервисная веб-платформа игрового сообщества. Браузер видит один адрес — **web-portal** (`:3000`), который выполняет роль **гейтвея**: агрегирует данные и проксирует запросы в доменные сервисы. Всё, что не требует синхронного ответа (почта, push, синхронизация данных между сервисами), — события **Kafka**.

```
┌──────────────────────────────────────────────────────────┐
│  Браузер: React SPA (Vite :5173 / nginx в Docker)        │
└────────────────────────────┬─────────────────────────────┘
                             │ HTTP/JSON, /api/v1/*
                             ▼
┌──────────────────────────────────────────────────────────┐
│ web-portal :3000 — гейтвей                               │
│  • SSR-страницы (пока идёт миграция на React)            │
│  • /api/v1/proxy/:service/:path → доменные сервисы       │
│  • /api/v1/minecraft/{status,sync} → game-service        │
│  • ActionCable (реалтайм), /health                       │
└──────┬────────────────────┬────────────────────┬─────────┘
       │ HTTP + API key     │ HTTP + API key     │ Kafka
       ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────────┐  ┌─────────────────────┐
│ identity-     │   │ game-service      │  │ notification-       │
│ service :3001 │   │ :3003             │  │ service :3004       │
│ auth, users,  │   │ Minecraft:        │  │ email (SMTP),       │
│ OAuth, 2FA,   │   │ players,          │  │ push (FCM)          │
│ donations     │   │ punishments, sync │  │ (stateless)         │
└───────┬───────┘   └────────┬──────────┘  └─────────────────────┘
        ▼                    ▼
 MySQL: identity_service  MySQL: game_service

 Инфраструктура:
 • Redis :6380    — сессии, кэш, очереди (db 0–3: по DB на сервис)
 • Kafka :29093   — события identity.* / game.* / notification.* / portal.*
 • ClickHouse     — аналитика и статистика (db pascalixs)
```

Почему так:

- **Отдельная БД на домен** — сервисы не ходят в чужие таблицы; данные обмениваются только через HTTP API и Kafka.
- **Один гейтвей для клиента** — SPA не знает адресов сервисов (dev-прокси Vite указывает на web-portal, см. `frontend/vite.config.ts`).
- **Kafka для «несрочного»** — отправка почты/push не блокирует ответ API; события дублируются с ретраями, порядок доставки не критичен.

Историческая справка: сервисы изначально назывались `web_service` / `auth_service` / `minecraft_service` / `mailer_service` (порты 3001/3002/3004/3003, PostgreSQL). В коммите `refactor: rename all services to domain-based names` они переименованы в текущие доменные имена; имена процессов в корневом `Procfile` (`auth`, `minecraft`, `mailer`) сохранены для совместимости.

## Микросервисы

### web-portal (`:3000`)

- **Ответственность**: входная точка для браузера; гейтвей/агрегатор; SSR-страницы (пока идёт миграция); ActionCable-каналы (логин, реалтайм-статус игроков, флеш-сообщения); health check.
- **Данные**: собственной БД в `docker-compose.yml` нет (`DATABASE_URL` сервису не передаётся) — данные о пользователях берёт из identity-service, кэш — Redis db 1.
- **Коммуникации**:
  - HTTP → identity-service (`IDENTITY_SERVICE_URL`), game-service (`GAME_SERVICE_URL`), notification-service (`NOTIFICATION_SERVICE_URL`);
  - Kafka: продюсер событий (проверьте `spec/producers/*`); consumer-группы в `karafka.rb` на момент написания не объявлены;
  - OAuth-редиректы: `/auth/discord`, `/integrations/{youtube,twitch,tiktok}` прокидываются в identity-service (см. `config/routes.rb`).

### identity-service (`:3001`)

- **Ответственность**: аутентификация и пользователи — email/пароль, OAuth (Discord, Google/YouTube, Twitch, TikTok), 2FA (OTP), привязка Minecraft-аккаунтов, донаты (товары и покупки), наказания и апелляции, жалобы, галерея, Discord-аватары.
- **Данные**: MySQL `identity_service` (пользователи, OAuth-аккаунты, наказания, апелляции, товары/покупки, …); ClickHouse для аналитики.
- **Коммуникации**:
  - HTTP ↔ web-portal и game-service (`WEB_PORTAL_URL`, `GAME_SERVICE_URL`, `NOTIFICATION_SERVICE_URL`);
  - Kafka: основной продюсер событий `identity.*` и консьюмер (полный список топиков — в `karafka.rb`);
  - корневые маршруты редиректит на web-portal.

### game-service (`:3003`)

- **Ответственность**: Minecraft-домен — данные об игроках, проверка пароля (AuthMe), синхронизация аккаунтов, статусы сервера (см. `.env.example`: `MC_SERVER_IP`, `AUTHME_API_KEY`, `LUCKPERMS_API_KEY`).
- **Данные**: MySQL `game_service`; Redis db 2; фоновые задачи — Sidekiq (процесс `minecraft_sidekiq` в `Procfile`).
- **Коммуникации**:
  - HTTP → identity-service (`IDENTITY_SERVICE_URL`);
  - Kafka: консьюмер `game.player.roles_requested` (`RolesConsumer`, см. `karafka.rb`);
  - корень редиректит на web-portal.

### notification-service (`:3004`)

- **Ответственность**: доставка уведомлений — email (SMTP) и push (Firebase Cloud Messaging, опционально: `FCM_SERVER_KEY`).
- **Данные**: stateless — собственной БД нет (в compose только Redis db 3 и Kafka).
- **Коммуникации**: потребляет Kafka-топики `notification.*` (см. `karafka.rb`); HTTP → identity-service для данных адресатов.

## web-portal как гейтвей

web-portal — единственная точка входа для SPA и браузерных редиректов. Он реализует паттерн **агрегатор/прокси**:

- `GET/POST/PUT/PATCH/DELETE /api/v1/proxy/:service/:path` — проксирование любого запроса к доменному сервису (`GatewayController` + `GatewayService::SERVICE_URLS`; см. `web-portal/app/controllers/gateway_controller.rb`);
- `GET /api/v1/minecraft/status`, `POST /api/v1/minecraft/sync` — готовые прокси-эндпоинты к game-service;
- `POST /api/v1/callbacks/auth_event` — колбэк событий аутентификации.

При этом web-portal **пока всё ещё отдаёт серверно-рендеренные страницы** (`app/views/`): миграция UI на React SPA идёт параллельно. По планам — довести SPA до feature parity и оставить в web-portal только гейтвей и API. Статус — в разделе [Текущий статус миграции](#текущий-статус-миграции).

## Межсервисная аутентификация

- Общий секрет **`INTER_SERVICE_API_KEY`** — одинаковый на всех 4 сервисах, передаётся в заголовках запроса (`Authorization` / `X-Api-Key`). Это «доверие по ключу»: сервисы обращаются друг к другу внутри сети и не имеют отдельных учётных записей.
- **`AUTH_VERSION`** (по умолчанию `v1`) — сегмент версии в межсервисных маршрутах: `/api/v1/...`. Позволяет в будущем развести версии API, не ломая текущие вызовы.
- На клиенте (SPA) используется отдельный механизм: Bearer-токен + refresh (см. `frontend/src/services/api.ts` и `auth-refresh.ts`).

## Асинхронность: Kafka

Все сервисы работают с Kafka через **Karafka** (concurrency 2; продюсер настроен на идемпотентность: `acks=all`, `enable.idempotence`). Топики имеют префикс сервиса — это защищает от конфликтов имён при добавлении новых сервисов (коммит `refactor: rename all Kafka topics with service prefixes`).

| Топик(и) | Потребитель | Назначение |
|---|---|---|
| `identity.user.*` (`logged_in`, `registered`, `profile_updated`, `password_changed`, `email_changed`, `deleted`, `restored`, `sync`) | identity-service | жизненный цикл пользователя |
| `identity.punishment.*` (`added`, `cancelled`, `status_updated`, `issued`, `resolved`, `appeal.created`, `appeal.dropped`) | identity-service | наказания и апелляции; `issued`/`resolved` — уведомления игроку |
| `identity.two_factor.code_sent` | identity-service | отправка OTP-кода |
| `identity.social.unbind.{tiktok,twitch,youtube}` | identity-service (`UnifiedSocialUnbindConsumer`) | отвязка соц. аккаунтов |
| `identity.user.data_requested`, `identity.user.punishments_requested` (+ варианты `.web`) | identity-service | запрос данных/наказаний пользователя (в т.ч. от web) |
| `game.player.roles_requested` | game-service (`RolesConsumer`), identity-service (`MinecraftRegistrationConsumer`) | роли и регистрация Minecraft-игрока |
| `portal.user.data_updated`, `portal.web_events` | identity-service | события с web-фронтенда |
| `notification.email`, `notification.push`, `notification.template` | notification-service | единый конвейер уведомлений |
| `notification.email.sent`, `notification.email.verified`, `notification.password_reset.sent` | notification-service | legacy-топики (ещё на месте) |

Продюсеры: identity-service (список событий — в `identity-service/README.md`) и web-portal (`spec/producers/*` — auth/user/web events). Точный состав топиков всегда сверяйте с `karafka.rb` каждого сервиса.

## Фронтенд (React SPA)

- **Entry** — `frontend/src/main.tsx`: `QueryClientProvider` (react-query: `staleTime` 5 мин, `retry: 1`) → `ErrorBoundary` → `ToastProvider` → `BrowserRouter`.
- **Роутинг** — react-router 7, маршруты в `src/App.tsx`. Все страницы ленивые (`React.lazy` + общий `Suspense`-фолбэк) — code splitting по маршруту.
- **Данные** — @tanstack/react-query (hooks в `src/hooks/`) поверх API-слоя `src/services/api.ts` (axios, `baseURL: /api/v1`):
  - request-интерцептор подставляет `Authorization: Bearer <token>` из `localStorage`;
  - ответ **401** → попытка обновления токена (`services/auth-refresh.ts`); если refresh не удался — разлогин;
  - ответ **429** → повтор до 3 раз с линейным бэкоффом (1с, 2с, 3с) — защита от глобального rate limiting бэкенда;
  - ошибки нормализуются в `ApiError { status, details, errors }`.
- **Состояние аутентификации** — zustand (`src/store/auth.ts`): `user`, `token`, `isAuthenticated`; токены лежат в `localStorage`.
- **i18n** — i18next + react-i18next; языки `ru`/`en`; детекция: querystring → localStorage → navigator, fallback `en`; ключи в `src/i18n/locales/*.json`.
- **Dev-прокси** — Vite перенаправляет `/api/v1/*` на `VITE_API_BASE_URL` (по умолчанию `http://localhost:3000` → web-portal). SPA «видит» один API и не знает, какой сервис отвечает.
- **Production** — Docker: сборка на `node:20-alpine` → отдача через nginx (порт 80; в compose маппится на 5173).

## Паттерны и принципы

- **Микросервисы с раздельными данными** — отдельная БД на домен (identity, game), stateless-сервис (notification); обмен только через API/события.
- **Event-driven** — Kafka-события для всего несрочного; префиксы топиков по сервисам; идемпотентные продюсеры.
- **Gateway/агрегатор** — web-portal скрывает топологию сервисов от клиента (см. выше).
- **Service objects (DI)** — бизнес-логика вынесена из контроллеров в сервисы (`app/services/`; примеры — `ServiceClient` в game-service, сервисы identity-service — см. `spec/services/`).
- **Единый базовый класс Karafka-консьюмеров** — 24 консьюмера identity-service унифицированы (коммит `refactor(auth): unify 24 Karafka consumers with shared base class`).
- **Rate limiting** — глобальный middleware на всех сервисах; фронтенд обрабатывает 429 ретраями.
- **Межсервисная аутентификация** — общий `INTER_SERVICE_API_KEY` + версионирование путей `AUTH_VERSION`.

## Текущий статус миграции

Целевой UI — React SPA. Сейчас он работает **параллельно** с SSR-страницами web-portal:

- **Уже есть в React** (`frontend/src/App.tsx`): главная, логин, регистрация, дашборд, личный профиль, настройки, галерея, покупки, донат, аккаунт (смена email, сброс пароля, 2FA), админ-панель (overview, пользователи, наказания, апелляции, статистика).
- **В web-portal остались SSR-представления** — `app/views/{admin,auth,pages,pwa,sessions,two_factor_authentications,user}`.
- **Ещё не покрыто в React**: список игроков (`/players`), публичный профиль (`/players/:nickname`), привязка соц. аккаунтов (интерфейс integrations), регистрация Minecraft-аккаунта (`register_minecraft`), email-логин (поток `email_login`), страница `goodbye`, спонсоры, жалобы; в админке — жалобы (complaints), товары, аватары, галерея, удалённые игроки, причины наказаний.

План: довести SPA до feature parity → затем сократить web-portal до API-only (гейтвей + API + ActionCable), убрав SSR-представления.

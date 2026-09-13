# Вклад в PascalixsWeb

Гид для тех, кто вносит изменения в код. Архитектура — в [ARCHITECTURE.md](./ARCHITECTURE.md), быстрый старт — в [README.md](./README.md).

## Настройка окружения

```bash
make setup    # = bin/setup
```

Что делает `bin/setup`:

1. Проверяет `mise` (ставит Ruby 3.4.10 и Node.js 24 по `.mise.toml`);
2. `gem install bundler`;
3. `bundle install` в 4 Rails-сервисах;
4. `npm install` в web-portal;
5. Проверяет Docker и foreman (установка: `gem install foreman`);
6. Создаёт `.env` из `.env.example`, если его нет.

Обязательно заполните `.env` (шаблон — `.env.example`): минимум `INTER_SERVICE_API_KEY`, OAuth-ключи, SMTP. Файл `.env` git-ignored — **никогда не коммитьте реальные секреты**.

## Запуск в dev

| Команда | Что делает |
|---|---|
| `make infra` | `docker compose up -d`: инфраструктура + контейнеры сервисов |
| `make dev` | `make infra` + `foreman start`: сервисы на хосте (identity `:3002`, game `:3004`, notification `:3003`, vite `:5173`); web-portal запускайте отдельно: `cd web-portal && bin/dev` |
| `make frontend` | `cd frontend && npm install && npm run dev` |
| `make logs` | `docker compose logs -f` |
| `make stop` / `make restart` / `make status` | Остановка / перезапуск / `docker ps` |
| `make help` | Полная справка по целям |

## Как добавить новую страницу (frontend)

1. **Компонент страницы** — создайте `frontend/src/pages/<Name>.tsx`.
2. **Ленивый маршрут** — в `frontend/src/App.tsx` (паттерн как у существующих страниц):

   ```tsx
   const MyPage = lazy(() => import('@/pages/MyPage'))

   // внутри <Route path="/" element={<Layout />}>:
   <Route path="my-page" element={<PageLoader><MyPage /></PageLoader>} />
   ```

3. **i18n-ключи** — добавьте в **оба** файла: `frontend/src/i18n/locales/en.json` **и** `frontend/src/i18n/locales/ru.json` (одинаковая структура ключей):

   ```json
   "myPage": {
     "title": "My page",
     "actions": { "refresh": "Refresh" }
   }
   ```

   В компоненте: `const { t } = useTranslation(); t('myPage.title')`.
4. **API-слой** (если страница ходит в бэкенд) — добавьте методы в `frontend/src/services/` (например, новый экспортированный объект в `api.ts` или отдельный файл, как `userApi.ts` / `adminApi.ts`):

   ```ts
   export const myApi = {
     list: () => api.get<MyItem[]>('/my-items'),
     create: (data: MyItemInput) => api.post('/my-items', data),
   }
   ```

5. **Тест** — `frontend/src/__tests__/<name>.test.tsx` (Vitest + Testing Library; паттерн моков роутера/i18n/store — в `__tests__/auth.test.tsx`).
6. **Проверка**:

   ```bash
   cd frontend
   npx tsc --noEmit   # типы
   npm run lint       # ESLint
   npm run build      # tsc -b && vite build
   npm run test:run   # Vitest
   ```

## Как добавить новый API endpoint (Rails-сервис)

1. **Маршрут** — в `<service>/config/routes.rb`, внутри `namespace :api do namespace :v1 do` (примеры — `identity-service/config/routes.rb`, `game-service/config/routes.rb`).
2. **Контроллер** — `app/controllers/api/v1/...` (пример — `game-service/app/controllers/api/v1/player_controller.rb`).
3. **Модель/миграция** (если нужна) + фабрика в `spec/factories/`.
4. **Спек** — request-спека в `spec/requests/api/v1/<name>_spec.rb` (паттерн — существующие request-спеки сервиса).
5. **Запуск**:

   ```bash
   make test-<service>   # или точечно:
   cd <service> && bundle exec rspec spec/requests/api/v1/<name>_spec.rb
   ```

6. **Новые переменные окружения** — добавьте в корневой `.env.example` **и** в `docker-compose.yml` (в секцию соответствующего сервиса).

## Тестирование

**Rails (RSpec):**

```bash
make test                # все 4 сервиса последовательно
make test-auth           # identity-service
make test-web            # web-portal
make test-minecraft      # game-service
make test-mailer         # notification-service
make parallel-setup      # один раз: parallel-тестовые БД
make test-parallel       # parallel_rspec -n 4 на сервис — быстрее
make test-coverage       # с отчётом о покрытии (COVERAGE=true)
```

Структура спеков: `spec/requests/` (API и страницы), `spec/consumers/` (Kafka; хелперы — `spec/support/karafka_test_helpers.rb`), `spec/models/`, `spec/services/`, `spec/jobs/`, фабрики — `spec/factories/`.

**Frontend (Vitest + Testing Library):**

```bash
cd frontend
npm run test:run         # один прогон
npm run test             # watch-режим
```

Настройки — `src/test/setup.ts`, примеры — `src/__tests__/`.

## Стиль кода

- **Frontend**: `cd frontend && npm run lint` (ESLint 9, flat config) или `make frontend-lint`. Типы: `npx tsc --noEmit`.
- **Rails**: `cd <service> && bundle exec rubocop` — в каждом сервисе свой `.rubocop.yml`.

## Коммиты

Используем **Conventional Commits** (это уже есть в истории репозитория):

```
feat(frontend): add gallery page
fix(auth): secure service-to-service auth
refactor(web-portal): remove inline JS
docs: update fixes log
test(web): update request specs
db: add foreign key constraints
```

Типы: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `db`. Скоупы — имя сервиса/слоя: `frontend`, `web-portal`, `identity-service`, `game-service`, `notification-service` (также встречаются `auth`, `web`, `docker`).

## Ветки

- `main` — стабильная ветка;
- работа ведётся в feature-ветках (текущая рабочая — `refactor-and-tests`);
- название ветки — по задаче, например `feat/admin-complaints-page`.

## Проверка перед PR

- [ ] `npx tsc --noEmit` — без ошибок типов (frontend)
- [ ] `npm run build` — сборка проходит (frontend)
- [ ] `npm run test:run` — тесты frontend проходят
- [ ] `npm run lint` — ESLint чистый
- [ ] `make test` (или `make test-<service>` для затронутых сервисов) — RSpec проходит
- [ ] `bundle exec rubocop` — без замечаний (затронутые сервисы)
- [ ] В `.env` нет реальных секретов (файл git-ignored); новые переменные окружения добавлены в `.env.example`

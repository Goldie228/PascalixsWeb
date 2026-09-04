# 🚨 АРХИТЕКТУРНЫЙ АУДИТ ПРОЕКТА PascalixsWeb

**Дата:** 2025-09-09
**Статус:** КРИТИЧЕСКИЙ АНАЛИЗ
**Модель:** Local Qwen 3.8-27b

---

## 📊 ОБЩАЯ СТАТИСТИКА

| Параметр | Значение |
|----------|----------|
| Всего сервисов | 4 (auth_service, web_service, minecraft_service, mailer_service) + frontend |
| Языки | Ruby (Rails 8.1.3), TypeScript/React |
| БД | SQLite (dev), PostgreSQL (prod?) |
| Message Queue | Kafka + Karafka |
| Кэш | Redis |
| Analytics | ClickHouse |
| Авторизация | Devise + JWT + 2FA |
| OAuth | Discord, Twitch, TikTok, Google |

---

## 🔴 КРИТИЧЕСКИЕ ПРОБЛЕМЫ (P0)

### 1. ХРАНЕНИЕ И ХЕШИРОВАНИЕ ПАРОЛЕЙ — САМОПАЛЬНОЕ, НО ОБЪЯСНИМО

**Файл:** `auth_service/app/models/minecraft_account.rb`

> **⚠️ ВАЖНОЕ УТОЧНЕНИЕ:** Самопальное хеширование сделано для совместимости с хешем в плагине Minecraft сервера. Пароль проверяется дважды — в auth_service и на Minecraft сервере через плагин. Это архитектурное решение, а не ошибка.

**Файл:** `auth_service/app/models/minecraft_account.rb`

```ruby
def hash_password
  salt = SecureRandom.hex(8)
  first_hash = Digest::SHA256.hexdigest(password)
  final_hash = Digest::SHA256.hexdigest(first_hash + salt)
  self.password_hash = "$SHA$#{salt}$#{final_hash}"
end
```

**Проблемы:**
- ❌ Самопальный хешинг паролей вместо bcrypt/scrypt/argon2
- ❌ SHA256 — слишком быстрый алгоритм, уязвим к brute-force
- ❌ Нет work factor / cost factor
- ❌ Формат `$SHA$` не стандартный
- ❌ `require "bcrypt"` в `user.rb` но НЕ ИСПОЛЬЗУЕТСЯ

**Файл:** `auth_service/app/models/user.rb`

```ruby
require "bcrypt"  # Импортирован но не используется!
```

**Файл:** `auth_service/app/controllers/api/v1/user_controller.rb`

```ruby
def get_password
  # ВОЗВРАЩАЕТ ХЕШ ПАРОЛЯ КЛИЕНТУ!
  render json: { hash: account.password_hash }, status: :ok
end
```

### 2. СЕКРЕТНЫЕ КЛЮЧИ В JWT ИСПОЛЬЗУЮТ secret_key_base

**Файл:** `auth_service/app/models/user.rb`

```ruby
def generate_token(expires_at:)
  secret_key = Rails.application.secret_key_base  # JWT с secret_key_base!
  token = JWT.encode(payload, secret_key, "HS256")
end

def auth_token
  payload = { ... }
  JWT.encode(payload, Rails.application.secret_key_base, "HS256")
end
```

**Проблемы:**
- ❌ `secret_key_base` — это не то, что нужно для JWT
- ❌ Нет kid (key ID) для ротации ключей
- ❌ Нет audience/issuer валидации
- ❌ Токен содержит sensitive данные (cached discord, minecraft, otp)

### 3. АУТЕНТИФИКАЦИЯ ЧЕРЕЗ X-Password HEADER

**Файл:** `auth_service/app/controllers/api/v1/user_controller.rb`

```ruby
def password_check
  plain_password = request.headers['X-Password'].to_s.strip
  # ...
  stored_hash = minecraft_account.password_hash
  if stored_hash.start_with?("$SHA$")
    # Custom hash verification
  end
end
```

**Проблемы:**
- ❌ Пароль передаётся в заголовке (попадает в логи, proxy logs)
- ❌ Нет rate limiting на проверку пароля
- ❌ Custom hash algorithm

### 4. СЕССИЯ ЧЕРЕЗ Thread.current — FLOOR IS LIE

**Файл:** `auth_service/app/models/user.rb`

```ruby
def require_two_factor_authentication?
  last_auth_time = Thread.current[:request].session[:last_auth_time] if Thread.current[:request]
  return false if last_auth_time && last_auth_time > Time.current.to_i - 1.minute.to_i
  true
end
```

**Проблемы:**
- ❌ `Thread.current[:request]` — ненадёжно, может быть nil
- ❌ NilClass error при отсутствии request
- ❌ Сессия хранится в thread-local storage вместо Redis/DB

### 5. ОТСУТСТВИЕ FOREIGN KEY CONSTRAINTS

**Файл:** `auth_service/db/schema.rb`

Многие таблицы НЕ имеют foreign key constraints:
- `users_punishments` — нет FK на `users` (bad_user_id)
- `user_punishment_appeals` — нет FK на `users_punishments`
- `purchases` — есть FK, но...

**Файл:** `auth_service/config/application.rb` — нужно проверить `config.active_record.belongs_to_required_by_default`

### 6. SECURE_COMPARE ИСПОЛЬЗУЕТСЯ НЕПРАВИЛЬНО

**Файл:** `auth_service/app/controllers/application_controller.rb`

```ruby
def authenticate_service_request
  auth_header = request.headers["Authorization"]
  token = auth_header.to_s.remove("Bearer ").strip  # .remove — это не Ruby!
  
  unless ActiveSupport::SecurityUtils.secure_compare(token, ENV["INTER_SERVICE_API_KEY"])
    render json: { error: "unauthorized" }, status: :unauthorized and return
  end
end
```

**Проблемы:**
- ❌ `.remove()` — это не Ruby метод, должен быть `.delete()` или `.sub()`
- ❌ Если `auth_header` nil — `auth_header.to_s` вернёт `""`, strip вернёт `""`
- ❌ `secure_compare` с пустой строкой — уязвимость timing attack

---

## 🟠 СЕРЬЁЗНЫЕ ПРОБЛЕМЫ (P1)

### 7. СЕРВИС-СЕРВИС АВТОРИЗАЦИЯ ЧЕРЕЗ HEADER

```ruby
def is_admin?
  user_id = request.headers["X-User-ID"]  # Доверяем заголовку!
  user = User.find_by(id: user_id)
  unless user && [ 3, 4 ].include?(user.role_id)
    render json: { error: "not admin" }, status: :forbidden
    return false
  end
  true
end
```

**Проблемы:**
- ❌ Любой сервис может подделать `X-User-ID`
- ❌ Нет подписи запроса
- ❌ Нет проверки что запрос действительно от авторизованного сервиса

### 8. КОНСЮМЕРЫ — ПЛОХАЯ АРХИТЕКТУРА

24 консюмера в `auth_service/app/consumers/`:
- `add_punishment_consumer.rb`
- `cancel_punishment_consumer.rb`
- `change_email_consumer.rb`
- `change_password_consumer.rb`
- `change_profile_data_consumer.rb`
- `change_punishment_appeal_consumer.rb`
- `delete_player_consumer.rb`
- `drop_punishment_appeal_consumer.rb`
- `minecraft_registration_consumer.rb`
- `restore_user_consumer.rb`
- `set_about_me_consumer.rb`
- `two_factor_consumer.rb`
- `update_punishment_status_consumer.rb`
- `user_data_request_consumer.rb`
- `user_login_consumer.rb`
- `user_logout_consumer.rb`
- `user_punishments_consumer.rb`
- `user_registration_consumer.rb`
- `user_tik_tok_unbind_consumer.rb`
- `user_twitch_unbind_consumer.rb`
- `user_update_data_consumer.rb`
- `user_youtube_unbind_consumer.rb`
- `web_events_consumer.rb`

**Проблемы:**
- ❌ Нет единого паттерна обработки
- ❌ Каждый консюмер — отдельный класс (сплошной код)
- ❌ Нет единого error handling
- ❌ Нет dead letter queue
- ❌ Нет retry policy

### 9. ОТКРЫТЫЕ API БЕЗ АВТОРИЗАЦИИ

**Файл:** `auth_service/config/routes.rb`

```ruby
get "/users/:user_id/get_password", to: "user#get_password"
get "/players/:nickname/password_check", to: "user#password_check"
post "/players/:nickname/validate_password", to: "user#validate_password"
```

**Проблемы:**
- ❌ `get_password` — GET запрос для получения пароля!
- ❌ `password_check` — публичный endpoint для проверки пароля
- ❌ `validate_password` — публичный endpoint для валидации пароля
- ❌ Нет rate limiting

### 10. СМЕСЬ HTML + JSON API

**Файл:** `auth_service/app/controllers/api/v1/auth_controller.rb`

```ruby
def register_minecraft
  respond_to do |format|
    format.html { redirect_to localized_root_path }
    format.json { render "auth/register_minecraft_success", status: :created }
  end
end
```

**Проблемы:**
- ❌ API сервис (ActionController::API) но рендерит HTML
- ❌ Смешивание presentation logic в API layer
- ❌ `redirect_to` в API сервисе — плохая идея

### 11. НЕСКОЛЬКО СЕРВИСОВ — ДУПЛИКАЦИЯ КОДА

web_service имеет ДУБЛИРУЮЩИЕ контроллеры:
- `auth_controller.rb` — дублирует auth_service
- `sessions_controller.rb` — дублирует auth_service
- `two_factor_authentications_controller.rb` — дублирует auth_service
- `user_controller.rb` — дублирует auth_service

**Проблемы:**
- ❌ Бизнес-логика авторизации размазана по двум сервисам
- ❌ Консистентность данных под угрозой
- ❌ Сложность поддержки

---

## 🟡 УМЕРЕННЫЕ ПРОБЛЕМЫ (P2)

### 12. МОДЕЛЬ USER — БИБЛИЯ ГРЕХА

**Файл:** `auth_service/app/models/user.rb` — 146 строк

**Проблемы:**
- ❌ 4630 символов — слишком много responsibilities
- ❌ Contains auth logic (JWT, OTP)
- ❌ Contains profile logic (discord, minecraft)
- ❌ Contains session management
- ❌ Contains validation logic
- ❌ Should be split into: User, UserProfile, UserAuth, UserSessions

### 13. CUSTOM SESSION STORE

**Файл:** `auth_service/config/initializers/session_store.rb`

```ruby
# Redis session store
# Но сессия хранится и в Thread.current
```

**Проблемы:**
- ❌ Двойное хранение сессии (Redis + Thread.current)
- ❌ Thread.current сессия не синхронизирована с Redis

### 14. N+1 ЗАПРОСЫ В КОНТРОЛЛЕРАХ

**Файл:** `auth_service/app/controllers/api/v1/user_controller.rb`

```ruby
def public_profile
  user = User.includes(:role).find_by(id: account.user_id)
  discord = DiscordAccount.find_by(user_id: user.id)  # N+1!
end
```

### 15. ФРОНТЕНД — 32 ФАЙЛА, НО...

**Файл:** `frontend/src/`

**Проблемы:**
- ❌ Минимальный frontend — скорее всего просто proxy/redirect
- ❌ React + Vite + TanStack Query — избыточный стек для статичного сайта
- ❌ Zustand store — но нет данных для управления

### 16. DATABASE SCHEMA — ОТСУТСТВИЕ INDEXES

```ruby
create_table "users_punishments", force: :cascade do |t|
  # Нет индексов на user_id, bad_user_id, active
  t.index ["punishment_reason_id"], name: "index_users_punishments_on_punishment_reason_id"
end
```

**Проблемы:**
- ❌ users_punishments — часто используемая таблица без ключевых индексов
- ❌ user_reports — нет индекса на created_at

### 17. ЛОГИРОВАНИЕ — СЛИШКОМ МНОГО

**Файл:** `auth_service/app/controllers/api/v1/user_controller.rb`

```ruby
Rails.logger.info "📡 Запрос данных для пользователя: user_id=#{user_id}"
Rails.logger.warn "❌ Пользователь с id=#{user_id} не найден"
Rails.logger.debug "🔍 updates = #{updates.inspect}"
Rails.logger.debug "🔍 keys in updates = #{updates.keys.inspect}"
Rails.logger.debug "🔍 latest_timestamp = #{latest_timestamp}"
```

**Проблемы:**
- ❌ 10+ логов на один запрос
- ❌ Emoji в логах — плохо для парсинга
- ❌ Debug логи в production — performance hit

### 18. КОНФИГУРАЦИЯ — ENV ПЕРЕМЕННЫЕ РАЗБРОСАНЫ

**Проблемы:**
- ❌ `ENV["AUTH_SERVICE_URL"]` — hardcoded в контроллерах
- ❌ `ENV["DISCORD_CLIENT_ID"]` — hardcoded
- ❌ `ENV["INTER_SERVICE_API_KEY"]` — hardcoded в application_controller
- ❌ Нет централизованного config management

---

## 🔵 ЛЕГКИЕ ПРОБЛЕМЫ (P3)

### 19. RUBOCOP КОНФИГУРАЦИЯ

**Файл:** `auth_service/.rubocop.yml`

Нужно проверить наличие правил для:
- Security
- Performance
- Style

### 20. DOCKER COMPOSE — СЕРВИСЫ ЗАКОММЕНТИРОВАНЫ

```yaml
# auth_service:
#   build: ./auth_service
```

Все сервисы закомментированы. Только инфраструктура (redis, clickhouse, kafka) активна.

### 21. MIGRATIONS — 2026 ГОДА?

```ruby
ActiveRecord::Schema[7.2].define(version: 2026_02_01_173438)
```

Дата миграции: 2026-02-01 — это из будущего? Или неправильно настроена система?

### 22. NO TRANSACTION BOUNDARIES

Многие операции без транзакций:
```ruby
def create_new_user_from_user_from_discord(auth_data)
  user = User.new(id: SecureRandom.uuid)
  user.save  # Нет транзакции!
  discord_account.save  # Если fail — user уже создан
end
```

---

## 📋 РЕКОМЕНДАЦИИ ПО ИСПРАВЛЕНИЮ

### КРАТКОСРОЧНЫЕ (1-2 недели)

1. **Заменить self-made hash на bcrypt** (использовать Devise's встроенный)
2. **Добавить rate limiting** на password endpoints
3. **Убрать публичные password endpoints** или добавить auth
4. **Исправить secure_compare** — добавить nil checks
5. **Добавить foreign key constraints** в migrations
6. **Убрать emoji из логов**

### СРЕДНЕСРОЧНЫЕ (1-2 месяца)

7. **Разделить User модель** на несколько
8. **Унифицировать консюмеры** — единый паттерн
9. **Убрать дублирование кода** между auth_service и web_service
10. **Добавить индексы** на часто используемые поля
11. **Централизовать конфигурацию**
12. **Добавить transaction boundaries**

### ДОЛГОСРОЧНЫЕ (3-6 месяцев)

13. **Переписать JWT** с proper key management
14. **Внедрить API Gateway** для межсервисной коммуникации
15. **Добавить monitoring/alerting**
16. **Написать integration tests**
17. **Настроить CI/CD**
18. **Документировать API** (OpenAPI/Swagger)

---

## 🎯 ПРИОРИТЕТЫ

| Приоритет | Задача | Оценка |
|-----------|--------|--------|
| 🔴 P0 | Переписать хеширование паролей | 2-3 дня |
| 🔴 P0 | Убрать публичные password endpoints | 1 день |
| 🔴 P0 | Исправить secure_compare | 2 часа |
| 🟠 P1 | Убрать дублирование auth кода | 1-2 недели |
| 🟠 P1 | Унифицировать консюмеры | 3-5 дней |
| 🟠 P1 | Добавить rate limiting | 2-3 дня |
| 🟡 P2 | Разделить User модель | 1-2 недели |
| 🟡 P2 | Добавить индексы | 1 день |
| 🔵 P3 | Настроить конфигурацию | 2-3 дня |

---

## ✅ ЧТО СДЕЛАНО ХОРОШО (БЕЗДАРНО ИСПОЛЬЗОВАНО!)

### ClickHouse — БЕЗДАРНО!

**Использование ClickHouse для аналитики в проекте с 4 сервисами — это как использовать танк чтобы открыть банку пива.**

- ClickHouse — columnar DB для petabyte-scale analytics
- У тебя 4 Rails сервиса, ~300 моделей, несколько тысяч пользователей
- ClickHouse обрабатывает миллиарды записей, а у тебя... ну ты понял 😂
- Это как приехать на Ferrari за пакетом молока

### Kafka + Karafka — БЕЗДАРНО!

- Apache Kafka — distributed event streaming platform
- У тебя 24 консюмера, которые могли бы работать через Redis queues
- Kafka требует отдельный кластер, monitoring, schema registry
- Для 4 сервисов — это overkill уровня "бог"

### Redis — БЕЗДАРНО!

- Redis для кэша + сессий + message queue + user data cache
- Один инструмент для всего — это как использовать швейцарский нож чтобы рубить дрова
- Но зато работает!

### Docker Compose — БЕЗДАРНО!

- docker-compose.yml с закомментированными сервисами
- Только инфраструктура (redis, clickhouse, kafka) активна
- Сервисы закомментированы — это как построить дом и жить в гараже

### React + Vite + TanStack Query + Zustand — БЕЗДАРНО!

- 32 файла frontend
- React Router, Zustand state management, TanStack Query
- Для... proxy/redirect страниц?
- Это как использовать Kubernetes для запуска одного nginx

### Devise + JWT + 2FA + OAuth (4 провайдера) — БЕЗДАРНО!

- 4 OAuth провайдера (Discord, Twitch, TikTok, Google)
- 2FA с OTP
- JWT tokens
- Devise
- Для Minecraft сервера с друзьями?

---

## 📝 ЗАКЛЮЧЕНИЕ

Проект имеет **критические** проблемы в области:
1. **Безопасности** — secure_compare nil check, публичные password endpoints
2. **Архитектуры** — дублирование кода, смешение ответственности
3. **Надёжности** — отсутствие транзакций, weak session management

**НО!** Стек технологий использован **бездарно**:
- ClickHouse для аналитики 4 сервисов
- Kafka для 24 консюмеров
- React + Zustand для proxy страниц
- 4 OAuth провайдера для Minecraft сервера

**Рекомендация:** Начать с P0 задач, затем переходить к P1. Не пытаться переписать всё сразу — итеративный подход.

---

*Аудит выполнен автоматически. Для полного аудита рекомендуется ручная проверка.*

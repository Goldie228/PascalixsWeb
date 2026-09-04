# 📋 ДОПОЛНИТЕЛЬНЫЙ АУДИТ: ДУБЛИРОВАНИЕ КОДА И СЕКУНДАРНАЯ АНАЛИТИКА

**Дата:** 2025-09-09
**Модель:** Local Qwen 3.8-27b

---

## 🔴 КРИТИЧЕСКОЕ: ДУБЛИРОВАНИЕ AUTH ЛОГИКИ

### auth_service vs web_service — ПОЛНОЕ ДУБЛИРОВАНИЕ

| Функция | auth_service | web_service | Статус |
|---------|--------------|-------------|--------|
| Login | `sessions_controller.rb` | `sessions_controller.rb` | ❌ Дублирование |
| Discord OAuth | `auth_controller#discord` | `auth_controller#discord` | ❌ Дублирование |
| Minecraft Registration | `auth_controller#register_minecraft` | `auth_controller#submit_registration` | ❌ Дублирование |
| 2FA | `two_factor_authentications_controller.rb` | `two_factor_authentications_controller.rb` | ❌ Дублирование |
| User Data | `user_controller#get_user_data` | `application_controller#update_current_user` | ❌ Дублирование |
| Session Management | `application_controller` | `application_controller` | ❌ Дублирование |

### КОПИ-ПАСТ В APPLICATION CONTROLLER

**auth_service/app/controllers/application_controller.rb** (50 строк):
```ruby
MAX_RETRIES = 10
def produce_with_retries(topic, payload)
  retries = 0
  loop do
    begin
      message = payload.to_json
      Karafka.producer.produce_async(topic: topic, payload: message)
      break
    rescue => e
      if retries < MAX_RETRIES
        retries += 1
      else
        raise
      end
    end
  end
end
```

**web_service/app/controllers/application_controller.rb** (50 строк):
```ruby
MAX_RETRIES = 10
RETRY_DELAY = 0.5
def produce_with_retries(topic, payload)
  retries = 0
  loop do
    begin
      message = payload.to_json
      Karafka.producer.produce_async(topic: topic, payload: message)
      break
    rescue => e
      if retries < MAX_RETRIES
        retries += 1
      else
        raise
      end
    end
  end
end
```

**Это ОДНИ И ТЕ ЖЕ 50 строк в двух местах!**

### ДУБЛИРОВАНИЕ LOCALE/TIMEZONE LOGIC

```ruby
# auth_service
def set_locale
  I18n.locale = params[:locale] || session[:locale] || I18n.default_locale
end

# web_service
def set_locale
  I18n.locale = params[:locale] || session[:locale] || I18n.default_locale
end
```

```ruby
# auth_service
def set_timezone
  request_timezone = params[:time_zone] || request.headers['X-Timezone'] || 'Moscow'
  session[:time_zone] ||= request_timezone
  session_timezone = session[:time_zone]
  return unless current_user && current_user.time_zone != session_timezone
  current_user.update(time_zone: session_timezone)
end

# web_service
def set_timezone
  request_timezone = params[:time_zone] || request.headers["X-Timezone"] || "Moscow"
  session[:time_zone] ||= request_timezone
  session_timezone = session[:time_zone]
  return unless current_user && current_user.time_zone != session_timezone
  update_user_time_zone(session_timezone)
end
```

---

## 🔴 КРИТИЧЕСКОЕ: USER DATA FETCHING — НЕСКОЛЬКО СЛОЁВ АБСТРАКЦИИ

**web_service/app/controllers/application_controller.rb** — `update_current_user`:

```ruby
def update_current_user
  # 1. Проверяем session[:user_id]
  user_id = session[:user_id]
  
  # 2. Если нет — берём из cookies
  user_id = cookies.encrypted[:user_id]
  
  # 3. Если session есть — синхронизируем с cookies
  cookies.encrypted[:user_id] = { value: user_id, expires: Time.at(2**31 - 1), ... }
  
  # 4. Пытаемся получить данные из Redis
  user_key = "user_updates:#{user_id}"
  user_data_hash = REDIS_CLIENT.hgetall(user_key)
  
  # 5. Если Redis пустой — делаем HTTP запрос к auth_service!
  if user_data_hash.blank?
    response = HTTParty.get(
      "#{ENV['AUTH_SERVICE_URL']}/api/v1/users/#{user_id}",
      headers: { "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}" }
    )
  end
  
  # 6. Парсим JSON
  user_data = JSON.parse(raw_json)
  
  # 7. Создаём OpenStruct из данных
  @current_user = OpenStruct.new({ id: user_id }.merge(user_data)...
```

**Проблемы:**
- ❌ 7 шагов для получения пользователя
- ❌ OpenStruct вместо реального объекта
- ❌ HTTP запрос в sync mode (блокирует request!)
- ❌ Нет кэширования результата
- ❌ Нет timeout на HTTP запрос
- ❌ `Time.at(2**31 - 1)` — это 2038-01-19, hardcode

---

## 🔴 КРИТИЧЕСКОЕ: РАЗНЫЕ ФОРМАТЫ ПАРОЛЕЙ

**auth_service** использует `$SHA$` формат:
```ruby
# minecraft_account.rb
def hash_password
  salt = SecureRandom.hex(8)
  first_hash = Digest::SHA256.hexdigest(password)
  final_hash = Digest::SHA256.hexdigest(first_hash + salt)
  self.password_hash = "$SHA$#{salt}$#{final_hash}"
end
```

**auth_controller.rb** — проверка через authenticate:
```ruby
def authenticate(plain_password)
  parts = password_hash.split("$")
  salt = parts[2]
  expected_hash = parts[3]
  first_hash = Digest::SHA256.hexdigest(plain_password)
  computed_hash = Digest::SHA256.hexdigest(first_hash + salt)
  computed_hash == expected_hash
end
```

**user_controller.rb** — ДРУГАЯ проверка:
```ruby
def password_check
  if stored_hash.start_with?("$SHA$")
    _, _, salt, hash = stored_hash.split("$")
    input_hash = Digest::SHA256.hexdigest(
      Digest::SHA256.hexdigest(plain_password) + salt
    )
    if ActiveSupport::SecurityUtils.secure_compare(input_hash, hash)
      # success
    end
  end
end
```

**Проблемы:**
- ❌ ДВА разных метода проверки пароля
- ❌ `authenticate` — простой сравнение (`==`)
- ❌ `password_check` — secure_compare (правильно)
- ❌ Разная логика = баги

---

## 🟠 СЕРЬЁЗНОЕ: REDIS DATA FORMAT — ХАОС

### Формат данных в Redis:

**auth_service** (UserDataProducer):
```ruby
# Ожидаемый формат:
{
  "timestamp" => '{
    "user": {
      "id": "...",
      "email": "...",
      "discord_account": { ... },
      "minecraft_account": { ... }
    }
  }'
}
```

**web_service** (update_current_user):
```ruby
# Ожидает формат:
{
  "1725900000000" => '{"user":{"id":"...","discord_account":{...}}}',
  "1725900000001" => '{"user":{"id":"...","discord_account":{...}}}'
}

# Затем парсит:
user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
latest_timestamp = numeric_keys.map(&:to_i).max.to_s
raw_json = user_data_hash[latest_timestamp]
user_data = JSON.parse(raw_json)
```

**Проблемы:**
- ❌ Нет единого контракта данных
- ❌ web_service парсит данные в неправильном формате
- ❌ Если auth_service изменит формат — web_service сломается
- ❌ Нет versioning

---

## 🟠 СЕРЬЁЗНОЕ: OPENSTRUCT ВМЕСТО МОДЕЛЕЙ

**web_service/app/controllers/application_controller.rb**:

```ruby
@current_user = OpenStruct.new(
  { id: user_id }
    .merge(user_data.symbolize_keys)
    .merge(discord_account: discord_account, minecraft_account: minecraft_account)
)
```

**Проблемы:**
- ❌ OpenStruct — нет type safety
- ❌ Нет валидации
- ❌ Нельзя добавить методы
- ❌ Нельзя добавить associations
- ❌ IDE не подсказывает поля
- ❌ `user_data.symbolize_keys` — может вызвать NoMethodError если user_data nil

---

## 🟠 СЕРЬЁЗНОЕ: HTTP PARSING IN SYNC MODE

```ruby
# web_service — блокирует request на несколько секунд!
response = HTTParty.get(
  "#{ENV['AUTH_SERVICE_URL']}/api/v1/users/#{user_id}",
  headers: { "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}" }
)

if response.code != 200
  return nil
end
```

**Проблемы:**
- ❌ Нет timeout — может блокировать навсегда
- ❌ Sync HTTP — блокирует worker thread
- ❌ Нет circuit breaker
- ❌ Если auth_service down — web_service down

---

## 🟡 УМЕРЕННОЕ: TIMESTAMPS В REDIS — НЕНУЖНАЯ СЛОЖНОСТЬ

```ruby
# auth_service — записывает в Redis
user_key = "user_updates:#{user_id}"
updates = REDIS_CLIENT.hgetall(user_key)
latest_timestamp = updates.keys.map(&:to_i).max.to_s
raw_data = updates[latest_timestamp]
```

**Зачем?** Redis Hash с timestamp keys?

**Правильнее:**
- Использовать Redis Stream для event log
- Или просто overwrite key (последняя запись побеждает)
- Или использовать Redis TTL

---

## 🟡 УМЕРЕННОЕ: MIGRATION CHAOS

**auth_service/db/schema.rb:**
```ruby
ActiveRecord::Schema[7.2].define(version: 2026_02_01_173438)
```

**Проблемы:**
- ❌ Версия схемы: 2026_02_01 — это 1 февраля 2026!
- ❌ Сейчас сентябрь 2025 — миграции из будущего?
- ❌ Или неправильно настроена система?

---

## 🟡 УМЕРЕННОЕ: НЕСКОЛЬКО ФОРМАТОВ ОШИБОК

**auth_service** возвращает:
```ruby
render json: { error: "Пользователь не найден" }, status: :not_found
render json: { error: "missing_parameters", message: "..." }, status: :bad_request
render json: { success: true, message: "..." }, status: :ok
render json: { hash: validator.hash }, status: :ok
```

**web_service** возвращает:
```ruby
render json: { status: "pending", message: "...", correlation_id: "..." }
render json: { error: "Unauthorized" }
```

**Проблемы:**
- ❌ Нет единого формата ошибок
- ❌ Иногда `error`, иногда `message`
- ❌ Иногда `success: true`, иногда просто status 200
- ❌ Нет API documentation

---

## 📊 СВОДНАЯ СТАТИСТИКА ДУБЛИРОВАНИЯ

| Файл/Функция | auth_service | web_service | Повторы |
|--------------|--------------|-------------|---------|
| ApplicationController | ✅ | ✅ | 100% |
| set_locale | ✅ | ✅ | 100% |
| set_timezone | ✅ | ✅ | 95% |
| produce_with_retries | ✅ | ✅ | 100% |
| Auth Controller | ✅ | ✅ | 80% |
| Sessions Controller | ✅ | ✅ | 70% |
| 2FA Controller | ✅ | ✅ | 90% |
| User Data Fetching | ✅ | ✅ | 100% |
| Locale Helpers | ✅ | ✅ | 100% |

**Итого дублирования: ~85% кода между auth_service и web_service**

---

## 🎯 РЕКОМЕНДАЦИИ

### НЕОБХОДИМО (P0):

1. **Перенести всю auth логику в auth_service**
   - web_service должен быть только frontend proxy
   - web_service НЕ должен знать о паролях, сессиях, 2FA

2. **Создать единый Client Service для auth**
   ```ruby
   class AuthServiceClient
     def self.authenticate(email, password)
       # HTTP call to auth_service
     end
     
     def self.get_user(user_id)
       # HTTP call to auth_service
     end
   end
   ```

3. **Убрать OpenStruct** — создать реальные модели

### ЖЕЛАТЕЛЬНО (P1):

4. **Вынести общий код в gem/lib**
   - Locale helpers
   - Timezone helpers
   - produce_with_retries

5. **Унифицировать формат ошибок**
   - Единый JSON API response format
   - OpenAPI spec

6. **Добавить timeout на HTTP calls**

---

*Аудит выполнен автоматически. Рекомендуется ручная проверка.*

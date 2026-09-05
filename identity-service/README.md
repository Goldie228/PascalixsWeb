# Identity Service

Identity Service - микросервис для управления аутентификацией и авторизацией пользователей.

## Возможности

- Регистрация и аутентификация пользователей через почту/пароль
- Аутентификация через Discord
- Привязка Minecraft аккаунтов
- Двухфакторная аутентификация (OTP)
- API для проверки токенов и работы с пользователями

## Интеграция с Kafka

Микросервис использует Kafka для отправки событий аутентификации и пользовательских событий.

### Продюсеры

Микросервис отправляет следующие события:

#### Auth Events Producer

- `authentication_successful` - успешная аутентификация пользователя
- `authentication_failed` - неудачная попытка аутентификации
- `user_registered` - регистрация нового пользователя
- `user_logged_in` - вход пользователя в систему
- `user_logged_out` - выход пользователя из системы
- `token_refreshed` - обновление токена
- `token_revoked` - отзыв токена
- `password_reset_requested` - запрос на сброс пароля
- `password_changed` - изменение пароля

#### User Events Producer

- `profile_updated` - обновление профиля пользователя
- `two_factor_enabled` - включение двухфакторной аутентификации
- `two_factor_disabled` - отключение двухфакторной аутентификации
- `discord_account_linked` - привязка Discord аккаунта
- `minecraft_account_linked` - привязка Minecraft аккаунта

### Консьюмеры

Микросервис обрабатывает следующие события:

#### Web Events Consumer

Обрабатывает события от web-portal:
- `page_viewed` - просмотр страницы
- `user_action` - действие пользователя
- `error_occurred` - ошибка во фронтенде
- `performance_metric` - метрика производительности

## API Endpoints

- `POST /api/v1/register` - регистрация пользователя
- `POST /api/v1/login` - вход пользователя
- `DELETE /api/v1/logout` - выход пользователя
- `GET /api/v1/me` - получение информации о текущем пользователе

## Запуск

```bash
bundle install
bundle exec rails db:migrate
bundle exec rails server -p 3000
```

## Переменные окружения

Требуемые переменные окружения указаны в файле `.env.example`:

- `KAFKA_BROKERS` - адреса брокеров Kafka
- `INTER_SERVICE_API_KEY` - ключ для межсервисной аутентификации

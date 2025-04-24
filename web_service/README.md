# Web Service

Веб-сервис для проекта Pascalixs. Отвечает за отображение интерфейса пользователя, перенаправление запросов авторизации в auth_service и обработку событий от других микросервисов через Kafka.

## Зависимости

- Ruby 3.2.0
- Rails 7.2.2
- Karafka 2.4.0+ (для работы с Kafka)
- Kafka
- Tailwind CSS 4.1.4
- DaisyUI 5.0.27

## Настройка

1. Установите все зависимости:

```bash
bundle install
yarn install
```

2. Создайте файл `.env` с нужными переменными окружения (по образцу `.env.example`):

```
# URL сервиса авторизации
AUTH_SERVICE_URL=http://localhost:3001

# Настройки Kafka
KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:9092
KAFKA_CLIENT_ID=web_service
KAFKA_GROUP_ID=web_service_development

# Общие настройки приложения
APP_HOST=localhost
APP_PORT=3000

# Ключи для безопасного соединения между сервисами
INTER_SERVICE_API_KEY=your_secure_api_key_here
```

3. Настройте ассеты и скомпилируйте Tailwind CSS:

```bash
# Самый простой способ - исправить все права и переустановить ассеты
bin/clean-refresh

# Или можно выполнить эти шаги по отдельности:
# Исправить права доступа для директорий ассетов
bin/fix-assets-permissions

# Скомпилировать ассеты с повышенными правами
bin/refresh-assets
```

## Управление ассетами

В проекте есть несколько скриптов для управления ассетами:

- `bin/clean-refresh` - Простой скрипт, который выполняет полную очистку и установку ассетов (рекомендуется)
- `bin/fix-assets-permissions` - Исправляет права доступа для всех директорий, связанных с ассетами
- `bin/refresh-assets` - Удаляет старые ассеты и компилирует новые с повышенными правами доступа
- `bin/rails tailwind:compile` - Только компилирует Tailwind CSS

При проблемах с правами доступа выполните:

```bash
sudo chown -R $USER:$USER /home/goldie/Documents/Ruby\ Projects/My_learn_projects_2025/microservices/web_service
```

## Запуск

1. Запустите сервер Rails:

```bash
bin/rails server
# или
bin/dev (запускает сервер и watcher для CSS)
```

2. Запустите Karafka (для работы с Kafka):

```bash
bundle exec karafka server
```

## Структура проекта

- `/app/controllers` - Контроллеры для обработки запросов
- `/app/consumers` - Потребители Kafka для обработки событий
- `/app/views` - Представления для отображения пользовательского интерфейса
- `/app/assets/tailwind` - Исходные CSS файлы для Tailwind
- `/app/assets/stylesheets` - Компилированные CSS файлы
- `/app/assets/builds` - Финальные CSS файлы для подключения в приложении
- `/config/locales` - Файлы локализации

## Взаимодействие с auth_service

Web Service взаимодействует с auth_service через:

1. Перенаправление запросов авторизации
2. Получение событий от Kafka (login, registration, etc.)
3. API-запросы для получения данных о пользователях

## API-запросы

Web Service предоставляет API для других сервисов:

- `/api/v1/callbacks/auth_event` - Для получения уведомлений об авторизации

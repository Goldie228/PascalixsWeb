# Pascalixs Frontend

React + Vite + TypeScript фронтенд для Minecraft сервера Pascalixs.

## Стек

- **React 18** — UI библиотека
- **TypeScript** — типизация
- **Vite** — сборщик
- **Tailwind CSS + DaisyUI** — стилизация
- **TanStack Query** — работа с API
- **Zustand** — управление состоянием
- **React Router** — роутинг
- **Axios** — HTTP клиент

## Быстрый старт

```bash
# Установка зависимостей
npm install

# Запуск dev-сервера
npm run dev

# Сборка для production
npm run build

# Линтинг
npm run lint
```

## Структура

```
src/
├── components/    # React компоненты
├── pages/        # Страницы приложения
├── hooks/        # Кастомные хуки
├── services/     # API сервисы
├── store/        # Zustand store
├── types/        # TypeScript типы
├── utils/        # Утилиты
└── assets/       # Статические файлы
```

## API

Фронтенд работает с auth_service API:
- `/api/auth/*` — аутентификация
- `/api/servers/stats` — статус сервера
- `/api/news` — новости
- `/api/votes` — голосования

## Docker

```bash
# Сборка и запуск
docker compose up frontend

# Или отдельно
cd frontend
npm run build
```

# Pascalixs Frontend

Modern React frontend for the Pascalixs Minecraft server — a feature-rich web application with authentication, admin panel, i18n, and responsive design.

## Stack

| Category | Technology |
|----------|-----------|
| **Framework** | React 19 + TypeScript |
| **Build** | Vite 6 |
| **Styling** | Tailwind CSS 4 + DaisyUI 5 |
| **Animation** | Framer Motion |
| **State** | Zustand (client) + TanStack Query (server) |
| **Routing** | React Router DOM v7 |
| **Forms** | React Hook Form + Zod validation |
| **HTTP** | Axios with interceptors |
| **i18n** | i18next + react-i18next (EN/RU) |
| **Testing** | Vitest + Testing Library |

## Quick Start

```bash
# Install dependencies
npm install

# Start development server (with HMR)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Run tests
npm test            # watch mode
npm run test:run    # single run

# Linting
npm run lint
```

## Project Structure

```
src/
├── __tests__/          # Vitest test files
├── assets/             # Static assets (images, fonts)
├── components/         # Reusable UI components
│   ├── ui/             # Base UI primitives (Button, Card, Modal, etc.)
│   ├── admin/          # Admin-specific layout components
│   ├── Layout.tsx      # Main app layout with navigation
│   ├── Hero.tsx        # Landing page hero section
│   ├── ServerStats.tsx # Server status widget
│   ├── NewsList.tsx    # News feed component
│   └── Notification*.tsx # Notification system
├── hooks/              # Custom React hooks (useAuth, useUsers, etc.)
├── i18n/               # Internationalization
│   ├── index.ts        # i18n configuration
│   └── locales/        # Translation files (en.json, ru.json)
├── pages/              # Page components (route-level)
│   ├── admin/          # Admin panel pages
│   ├── Home.tsx        # Landing page
│   ├── Login.tsx       # Authentication
│   ├── Register.tsx    # User registration
│   ├── Dashboard.tsx   # User dashboard
│   ├── Profile.tsx     # User profile
│   └── ...             # All other pages
├── services/           # API clients and HTTP layer
│   ├── api.ts          # Axios instance with interceptors
│   ├── auth-refresh.ts # Token refresh logic
│   └── notificationApi.ts
├── store/              # Zustand stores (auth, theme)
├── test/               # Test utilities and setup
├── types/              # TypeScript type definitions
├── utils/              # Helper functions
├── App.tsx             # Root app with lazy-loaded routes
└── main.tsx            # Entry point
```

## Internationalization (i18n)

The app supports **English** and **Russian** with a language switcher in the header.

### Usage

```tsx
import { useTranslation } from 'react-i18next'

function MyComponent() {
  const { t, i18n } = useTranslation()

  // Translate text
  return <h1>{t('hero.title')}</h1>

  // Change language programmatically
  const toggle = () => i18n.changeLanguage(i18n.language === 'en' ? 'ru' : 'en')
}
```

### Translation Keys

All translation keys follow the format `section.key`. Major sections:

- **nav** — Navigation items (home, dashboard, login, register, etc.)
- **common** — Shared UI text (save, cancel, delete, loading, etc.)
- **auth** — Authentication forms and messages
- **admin** — Admin panel labels and messages
- **hero** — Landing page content
- **server** — Server status labels
- **news** — News feed labels
- **notification** — Notification system labels
- **profile** — Profile page labels
- **settings** — Settings page labels

### Adding Translations

Edit `src/i18n/locales/en.json` and `src/i18n/locales/ru.json` with matching keys.

## Authentication

Auth state is managed via Zustand store (`useAuthStore`).

- **JWT tokens** stored in localStorage
- **Automatic token refresh** on 401 responses
- **Protected routes** check `isAuthenticated` before rendering
- **Role-based access** — admin routes gated by `role === 'admin'`

### Auth Flow

1. User logs in → token stored in localStorage
2. API requests include `Authorization: Bearer <token>`
3. On 401 → automatic refresh via `/auth/refresh`
4. On refresh failure → user logged out, redirected to login

## API Layer

Axios instance in `src/services/api.ts` with:

- **Request interceptor** — attaches JWT token
- **Response interceptor** — handles 401 refresh, 429 rate limit retries
- **Error transformation** — consistent error format with status, message, and details
- **Dev logging** — request/response logging in development mode

### API Clients

- `authApi` — login, register, logout, me
- `serverApi` — stats, news, votes
- `gameApi` — player info, server info
- `notificationApi` — notifications CRUD

## Admin Panel

Protected routes under `/admin/*`:

| Route | Page | Description |
|-------|------|-------------|
| `/admin` | Overview | Dashboard with key metrics |
| `/admin/users` | Users | User management (view, edit, delete) |
| `/admin/punishments` | Punishments | View and create punishments |
| `/admin/appeals` | Appeals | Review and resolve player appeals |
| `/admin/stats` | Stats | Detailed statistics and analytics |

Access requires `role === 'admin'`. Admin nav link appears in header for admin users.

## Code Splitting

All routes use `React.lazy()` with `Suspense` for automatic code splitting. Each page is loaded on demand, reducing initial bundle size.

```tsx
// App.tsx
const Login = lazy(() => import('@/pages/Login'))
```

## Testing

Vitest + Testing Library for unit and integration tests.

```bash
npm test              # Run tests in watch mode
npm run test:run      # Run tests once
```

### Test Structure

```
src/
├── __tests__/          # Test files co-located with features
│   └── auth.test.tsx   # Auth page tests
└── test/
    └── setup.ts        # Test environment setup (jsdom mocks)
```

### Writing Tests

```tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'

describe('MyComponent', () => {
  it('renders correctly', () => {
    render(<MyComponent />)
    expect(screen.getByText('expected text')).toBeInTheDocument()
  })
})
```

## Docker

```bash
# Build and run via docker-compose
docker compose up frontend

# Or build standalone
cd frontend
npm run build
```

The built output is served by Nginx in production.

## Environment Variables

Create a `.env` file in the `frontend/` directory:

```env
# API base URL (defaults to /api/v1 for proxied requests)
VITE_API_BASE_URL=/api/v1

# Feature flags
VITE_ENABLE_DEBUG_LOGS=true
```

## Build Optimization

- **Tree shaking** — unused components are excluded from production builds
- **Code splitting** — each route is a separate chunk
- **Asset optimization** — images and fonts are hashed and compressed
- **Minification** — Terser for JS, CSS purging via Tailwind

## Contributing

1. Follow TypeScript strict mode — no `any` types
2. Use `useTranslation()` for all UI text
3. Keep Zod validation messages in English (in schemas)
4. Use `useToast()` for API feedback
5. Write tests for new features
6. Run `npm run lint` before committing

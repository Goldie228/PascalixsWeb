import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import Login from '@/pages/Login'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { ToastProvider } from '@/components/ui/Toast'

// Mock react-router-dom
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom')
  return {
    ...actual,
    useNavigate: vi.fn(),
  }
})

// Mock auth store
const mockLogin = vi.fn()
const mockIsLoading = vi.fn()
vi.mock('@/store/auth', () => ({
  useAuthStore: vi.fn((selector: (state: any) => any) => {
    const mockState = {
      login: mockLogin,
      isLoading: mockIsLoading(),
      error: null,
      isAuthenticated: false,
      user: null,
      token: null,
      register: vi.fn(),
      logout: vi.fn(),
      fetchUser: vi.fn(),
    }
    return selector(mockState)
  }),
}))

// Mock i18n - returns keys as-is for testing
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    i18n: { changeLanguage: vi.fn() },
  }),
  initReactI18next: {
    type: '3rdParty',
    init: vi.fn(),
  },
}))

// Mock react-hook-form
vi.mock('react-hook-form', async () => {
  const actual = await vi.importActual('react-hook-form')
  return {
    ...actual,
    useForm: vi.fn(() => ({
      register: vi.fn((name: string) => ({ name })),
      handleSubmit: vi.fn((fn: Function) => fn),
      formState: { errors: {}, isSubmitting: false },
      reset: vi.fn(),
    })),
  }
})

// Mock zod
vi.mock('@hookform/resolvers/zod', () => ({
  zodResolver: vi.fn(() => () => ({ value: true })),
}))

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <ToastProvider>{children}</ToastProvider>
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('Login Page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockLogin.mockReturnValue(undefined)
    mockIsLoading.mockReturnValue(false)
  })

  it('renders login form with title and fields', () => {
    render(<Login />, { wrapper: createWrapper() })

    // i18n mock returns keys as-is
    expect(screen.getByText('auth.login_title')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('auth.login_placeholder_username')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('auth.login_placeholder_password')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'auth.login_button' })).toBeInTheDocument()
  })

  it('renders register link', () => {
    render(<Login />, { wrapper: createWrapper() })

    expect(screen.getByText('auth.login_no_account')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'auth.login_register_link' })).toBeInTheDocument()
  })

  it('calls login function when form is submitted', async () => {
    render(<Login />, { wrapper: createWrapper() })

    const submitButton = screen.getByRole('button', { name: 'auth.login_button' })
    fireEvent.click(submitButton)

    // Form should attempt to submit
    expect(mockLogin).toHaveBeenCalled()
  })

  it('renders with proper accessibility attributes', () => {
    render(<Login />, { wrapper: createWrapper() })

    // Inputs should have proper autocomplete attributes
    const inputs = screen.getAllByRole('textbox')
    expect(inputs[0]).toHaveAttribute('autocomplete', 'username')
    
    const passwordInput = screen.getByPlaceholderText('auth.login_placeholder_password') as HTMLInputElement
    expect(passwordInput).toHaveAttribute('autocomplete', 'current-password')
    expect(passwordInput).toHaveAttribute('type', 'password')
  })
})

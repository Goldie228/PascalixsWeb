export default function Login() {
  return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="card w-full max-w-md bg-base-200 shadow-xl">
        <div className="card-body">
          <h2 className="card-title justify-center text-2xl text-primary">
            Вход
          </h2>
          <form className="space-y-4">
            <div className="form-control">
              <label className="label">
                <span className="label-text">Имя пользователя</span>
              </label>
              <input
                type="text"
                placeholder="username"
                className="input input-bordered bg-base-300"
              />
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Пароль</span>
              </label>
              <input
                type="password"
                placeholder="••••••••"
                className="input input-bordered bg-base-300"
              />
            </div>
            <button type="submit" className="btn btn-primary w-full">
              Войти
            </button>
          </form>
          <p className="text-center text-sm">
            Нет аккаунта?{' '}
            <a href="/register" className="text-primary hover:underline">
              Зарегистрироваться
            </a>
          </p>
        </div>
      </div>
    </div>
  )
}

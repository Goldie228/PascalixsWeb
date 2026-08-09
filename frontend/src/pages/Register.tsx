export default function Register() {
  return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="card w-full max-w-md bg-base-200 shadow-xl">
        <div className="card-body">
          <h2 className="card-title justify-center text-2xl text-primary">
            Регистрация
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
                <span className="label-text">Email</span>
              </label>
              <input
                type="email"
                placeholder="email@example.com"
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
            <div className="form-control">
              <label className="label">
                <span className="label-text">Подтвердите пароль</span>
              </label>
              <input
                type="password"
                placeholder="••••••••"
                className="input input-bordered bg-base-300"
              />
            </div>
            <button type="submit" className="btn btn-primary w-full">
              Зарегистрироваться
            </button>
          </form>
          <p className="text-center text-sm">
            Уже есть аккаунт?{' '}
            <a href="/login" className="text-primary hover:underline">
              Войти
            </a>
          </p>
        </div>
      </div>
    </div>
  )
}

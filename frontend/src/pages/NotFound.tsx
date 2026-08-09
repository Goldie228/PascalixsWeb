import { Link } from 'react-router-dom'

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[50vh]">
      <h1 className="text-6xl font-bold text-primary">404</h1>
      <p className="text-xl text-base-content/70 mt-4">
        Страница не найдена
      </p>
      <Link to="/" className="btn btn-primary mt-6">
        На главную
      </Link>
    </div>
  )
}

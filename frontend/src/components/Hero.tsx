import { Link } from 'react-router-dom'

export default function Hero() {
  return (
    <div className="hero min-h-[60vh] bg-base-200">
      <div className="hero-content text-center">
        <div className="max-w-2xl">
          <h1 className="text-5xl font-bold text-primary">Pascalixs</h1>
          <p className="py-6 text-xl text-base-content/70">
            Уникальный Minecraft сервер с кастомными механиками, дружелюбным
            комьюнити и регулярными ивентами. Присоединяйся к нам!
          </p>
          <div className="flex gap-4 justify-center">
            <Link to="/register" className="btn btn-primary btn-lg">
              Начать игру
            </Link>
            <Link to="/dashboard" className="btn btn-outline btn-lg">
              Dashboard
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}

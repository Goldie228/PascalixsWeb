export default function Dashboard() {
  return (
    <div>
      <h1 className="text-3xl font-bold mb-6 text-primary">Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div className="card bg-base-200">
          <div className="card-body">
            <h2 className="card-title">Статистика</h2>
            <p className="text-base-content/70">
              Информация о вашем прогрессе на сервере
            </p>
          </div>
        </div>
        <div className="card bg-base-200">
          <div className="card-body">
            <h2 className="card-title">Инвентарь</h2>
            <p className="text-base-content/70">
              Ваши предметы и ресурсы
            </p>
          </div>
        </div>
        <div className="card bg-base-200">
          <div className="card-body">
            <h2 className="card-title">Достижения</h2>
            <p className="text-base-content/70">
              Ваши награды и прогресс
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

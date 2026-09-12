import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'

export default function Hero() {
  const { t } = useTranslation()

  return (
    <div className="hero min-h-[60vh] bg-base-200">
      <div className="hero-content text-center">
        <div className="max-w-2xl">
          <h1 className="text-5xl font-bold text-primary">Pascalixs</h1>
          <p className="py-6 text-xl text-base-content/70">
            {t('hero.subtitle')}
          </p>
          <div className="flex gap-4 justify-center">
            <Link to="/register" className="btn btn-primary btn-lg">
              {t('hero.start_button')}
            </Link>
            <Link to="/dashboard" className="btn btn-outline btn-lg">
              {t('nav.dashboard')}
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}

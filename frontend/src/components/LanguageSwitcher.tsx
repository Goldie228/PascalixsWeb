import { useTranslation } from 'react-i18next'

export function LanguageSwitcher() {
  const { i18n } = useTranslation()

  const languages = [
    { code: 'en', label: 'EN' },
    { code: 'ru', label: 'RU' },
  ]

  return (
    <div className="flex items-center gap-1">
      {languages.map((lang) => (
        <button
          key={lang.code}
          onClick={() => i18n.changeLanguage(lang.code)}
          className={`px-2 py-1 rounded text-xs font-medium transition-colors ${
            i18n.language === lang.code
              ? 'bg-blue-600 text-white'
              : 'text-gray-400 hover:text-white hover:bg-gray-700'
          }`}
        >
          {lang.label}
        </button>
      ))}
    </div>
  )
}

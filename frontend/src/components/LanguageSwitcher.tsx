import { useTranslation } from 'react-i18next'
import { cn } from '@/lib/utils'

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
          className={cn(
            'px-2.5 py-1 rounded-md text-xs font-medium transition-all duration-200',
            'hover:bg-[#1a1a1a] active:scale-95',
            i18n.language === lang.code
              ? 'bg-[#FFD700] text-[#0A0A0A] font-bold'
              : 'text-[#A0A0A0] hover:text-[#FFD700]'
          )}
        >
          {lang.label}
        </button>
      ))}
    </div>
  )
}

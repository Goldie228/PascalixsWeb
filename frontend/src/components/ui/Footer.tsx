import { useTranslation } from 'react-i18next'
import { useToast } from '@/components/ui/Toast'
import {
  Discord,
  Youtube,
  Copy,
  Check,
  Telegram,
} from 'lucide-react'
import { useState } from 'react'

// Server IP - would come from env/config in production
const SERVER_IP = 'play.pascalixs.net'

export function Footer() {
  const { t } = useTranslation()
  const { toast } = useToast()
  const [copied, setCopied] = useState(false)

  const handleCopyIp = async () => {
    try {
      await navigator.clipboard.writeText(SERVER_IP)
      setCopied(true)
      toast(t('common.copied'), 'success', 2000)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      toast(t('common.copy_failed'), 'error', 2000)
    }
  }

  const currentYear = new Date().getFullYear()
  const startYear = 2025

  return (
    <footer className="bg-[#0A0A0A] shadow-lg mt-auto">
      <div className="mx-auto px-6 md:px-12 py-4 md:py-6">
        {/* Top section: links title + social icons */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-5">
          {/* Links title */}
          <h3 className="font-bold text-xl text-amber-400">
            {t('footer.our_links')}:
          </h3>

          {/* Social icons */}
          <div className="flex items-center gap-4">
            {/* Discord */}
            <a
              href="https://discord.gg/VwwzQJQpkW"
              target="_blank"
              rel="noopener noreferrer"
              className="text-amber-400 hover:text-[#FFC400] transition-colors duration-200"
              aria-label="Discord"
            >
              <Discord className="w-8 h-8" />
            </a>

            {/* YouTube */}
            <a
              href="https://www.youtube.com/@PascaLixs_mc"
              target="_blank"
              rel="noopener noreferrer"
              className="text-amber-400 hover:text-[#FFC400] transition-colors duration-200"
              aria-label="YouTube"
            >
              <Youtube className="w-8 h-8" />
            </a>
          </div>
        </div>

        {/* Amber divider */}
        <div className="h-0.5 bg-amber-400 mb-6" />

        {/* Main grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 justify-center">
          {/* Column 1: Server info */}
          <div>
            <h3 className="font-bold text-xl mb-4 pb-2">Pascalixs</h3>
            <p className="text-gray-400 mb-2 text-lg">
              Minecraft server with unique features and community
            </p>
            {/* Server IP with copy button */}
            <div className="flex items-center gap-2 mt-3">
              <span className="text-gray-400 text-sm">
                {t('footer.server_ip')}:
              </span>
              <button
                onClick={handleCopyIp}
                className="flex items-center gap-1.5 bg-[#1a1a1a] hover:bg-[#2a2a2a] text-amber-400 px-3 py-1.5 rounded-md transition-colors text-sm font-mono"
                aria-label={t('footer.copy_ip')}
              >
                {copied ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-green-400" />
                    <span className="text-green-400">{SERVER_IP}</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>{SERVER_IP}</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Column 2: Important links */}
          <div>
            <h3 className="font-bold text-xl mb-4 pb-2">
              {t('footer.important_links')}
            </h3>
            <ul className="space-y-2 text-lg">
              <li>
                <a
                  href="#"
                  className="text-gray-400 hover:text-[#FFD700] transition-colors duration-200"
                >
                  Rules
                </a>
              </li>
              <li>
                <a
                  href="#"
                  className="text-gray-400 hover:text-[#FFD700] transition-colors duration-200"
                >
                  Events
                </a>
              </li>
              <li>
                <a
                  href="#"
                  className="text-gray-400 hover:text-[#FFD700] transition-colors duration-200"
                >
                  Wiki
                </a>
              </li>
            </ul>
          </div>

          {/* Column 3: Contact */}
          <div>
            <h3 className="font-bold text-xl mb-4 pb-2">
              {t('footer.contact_the_administration')}
            </h3>
            <div className="flex flex-col gap-4">
              {/* Telegram */}
              <a
                href="#"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-gray-400 hover:text-[#FFD700] transition-colors duration-200"
                aria-label={t('footer.telegram')}
              >
                <Telegram className="w-6 h-6" />
                <span className="font-medium text-lg">
                  {t('footer.telegram')}
                </span>
              </a>

              {/* Discord */}
              <a
                href="https://discord.gg/VwwzQJQpkW"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-gray-400 hover:text-[#FFD700] transition-colors duration-200"
                aria-label={t('footer.discord')}
              >
                <Discord className="w-6 h-6" />
                <span className="font-medium text-lg">
                  {t('footer.discord')}
                </span>
              </a>
            </div>
          </div>
        </div>

        {/* Copyright */}
        <div className="mt-8 border-t border-gray-700 pt-6 text-center">
          <p className="text-gray-400 text-xs tracking-wider uppercase">
            &copy; {startYear === currentYear
              ? startYear
              : `${startYear}\u2013${currentYear}`}
            <span className="mx-2">|</span>
            Copyright:{' '}
            <span className="font-medium">{t('footer.pascalixs_team')}</span>
          </p>
        </div>
      </div>
    </footer>
  )
}

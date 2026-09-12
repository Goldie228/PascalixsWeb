import { useTranslation } from 'react-i18next'
import { useNews } from '@/hooks/useQueries'
import type { NewsItem } from '@/types'

export default function NewsList() {
  const { t } = useTranslation()
  const { data, isLoading } = useNews()

  if (isLoading) {
    return (
      <div className="flex justify-center py-8">
        <span className="loading loading-spinner loading-lg"></span>
      </div>
    )
  }

  const news = data?.data as NewsItem[] | undefined

  return (
    <div className="space-y-4">
      {news?.length ? (
        news.map((item) => (
          <div key={item.id} className="card bg-base-200">
            <div className="card-body">
              <h2 className="card-title text-primary">{item.title}</h2>
              <p className="text-base-content/70">{item.content}</p>
              <div className="card-actions justify-end text-sm text-base-content/50">
                <span>{t('news.author')} {item.author}</span>
                <span>•</span>
                <span>{new Date(item.createdAt).toLocaleDateString()}</span>
              </div>
            </div>
          </div>
        ))
      ) : (
        <p className="text-center text-base-content/50">{t('news.no_news')}</p>
      )}
    </div>
  )
}

import Hero from '@/components/Hero'
import ServerStats from '@/components/ServerStats'
import NewsList from '@/components/NewsList'

export default function Home() {
  return (
    <div className="space-y-12">
      <Hero />
      <div>
        <h2 className="text-2xl font-bold mb-4 text-primary">Статус сервера</h2>
        <ServerStats />
      </div>
      <div>
        <h2 className="text-2xl font-bold mb-4 text-primary">Новости</h2>
        <NewsList />
      </div>
    </div>
  )
}

import { motion } from 'framer-motion';
import { Button } from '@/components/ui/Button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import ServerStats from '@/components/ServerStats';
import NewsList from '@/components/NewsList';

function Home() {
  return (
    <div className="min-h-screen bg-base-100">
      {/* Hero Section */}
      <section className="relative overflow-hidden bg-gradient-to-b from-primary/10 to-base-100 py-20">
        <div className="container mx-auto px-4 text-center">
          <motion.h1
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-4 text-4xl font-bold text-base-content sm:text-5xl"
          >
            Welcome to Pascalixs
          </motion.h1>
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="mb-8 text-lg text-neutral/70"
          >
            Minecraft server with unique features and community
          </motion.p>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
            className="flex justify-center gap-4"
          >
            <Button size="lg" onClick={() => window.location.href = '/login'}>
              Get Started
            </Button>
            <Button variant="outline" size="lg" onClick={() => window.open('https://discord.gg/pascalixs', '_blank', 'noopener noreferrer')}>
              Join Discord
            </Button>
          </motion.div>
        </div>
      </section>

      {/* Server Stats */}
      <section className="py-12">
        <div className="container mx-auto px-4">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <h2 className="mb-6 text-center text-2xl font-bold text-base-content">
              Server Status
            </h2>
            <ServerStats />
          </motion.div>
        </div>
      </section>

      {/* Features */}
      <section className="py-12">
        <div className="container mx-auto px-4">
          <motion.h2
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="mb-8 text-center text-3xl font-bold text-base-content"
          >
            Features
          </motion.h2>
          <div className="grid gap-6 md:grid-cols-3">
            {[
              { title: 'Unique Gameplay', desc: 'Custom plugins and features', icon: '🎮' },
              { title: 'Active Community', desc: 'Join thousands of players', icon: '👥' },
              { title: 'Regular Updates', desc: 'Fresh content every week', icon: '🔄' },
            ].map((feature, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.1 + 0.3 }}
              >
                <Card>
                  <CardHeader>
                    <div className="flex items-center gap-2">
                      <span className="text-2xl">{feature.icon}</span>
                      <CardTitle>{feature.title}</CardTitle>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <p className="text-neutral/70">{feature.desc}</p>
                  </CardContent>
                </Card>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* News */}
      <section className="py-12">
        <div className="container mx-auto px-4">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
          >
            <h2 className="mb-6 text-center text-2xl font-bold text-base-content">
              Latest News
            </h2>
            <NewsList />
          </motion.div>
        </div>
      </section>

      {/* Footer Badge */}
      <section className="py-8">
        <div className="container mx-auto px-4 text-center">
          <Badge variant="outline" className="text-sm">
            v1.0.0 &copy; 2025 Pascalixs
          </Badge>
        </div>
      </section>
    </div>
  );
}

export default Home;

# Frontend (Vite dev server)
frontend: cd frontend && npm run dev -- --host 0.0.0.0

# Auth Service
auth: cd auth_service && PORT=${AUTH_SERVICE_PORT:-3002} rails s -p ${AUTH_SERVICE_PORT:-3002} -b 0.0.0.0
auth_karafka: cd auth_service && sleep 10 && bundle exec karafka server

# Minecraft Service
minecraft: cd minecraft_service && PORT=${MINECRAFT_SERVICE_PORT:-3004} rails s -p ${MINECRAFT_SERVICE_PORT:-3004} -b 0.0.0.0
minecraft_karafka: cd minecraft_service && sleep 10 && bundle exec karafka server
minecraft_sidekiq: cd minecraft_service && sleep 10 && bundle exec sidekiq -q default

# Mailer Service
mailer: cd mailer_service && PORT=${MAILER_SERVICE_PORT:-3003} rails s -p ${MAILER_SERVICE_PORT:-3003} -b 0.0.0.0
mailer_karafka: cd mailer_service && sleep 10 && bundle exec karafka server

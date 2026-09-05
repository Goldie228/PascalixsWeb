# Frontend (Vite dev server)
frontend: cd frontend && npm run dev -- --host 0.0.0.0

# Identity Service
auth: cd identity-service && PORT=${AUTH_SERVICE_PORT:-3002} rails s -p ${AUTH_SERVICE_PORT:-3002} -b 0.0.0.0
auth_karafka: cd identity-service && sleep 10 && bundle exec karafka server

# Game Service
minecraft: cd game-service && PORT=${MINECRAFT_SERVICE_PORT:-3004} rails s -p ${MINECRAFT_SERVICE_PORT:-3004} -b 0.0.0.0
minecraft_karafka: cd game-service && sleep 10 && bundle exec karafka server
minecraft_sidekiq: cd game-service && sleep 10 && bundle exec sidekiq -q default

# Notification Service
mailer: cd notification-service && PORT=${MAILER_SERVICE_PORT:-3003} rails s -p ${MAILER_SERVICE_PORT:-3003} -b 0.0.0.0
mailer_karafka: cd notification-service && sleep 10 && bundle exec karafka server

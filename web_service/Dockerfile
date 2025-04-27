# syntax=docker/dockerfile:1
# Production Dockerfile для проекта (web_service) с Rails, esbuild, TailwindCSS и Importmap

FROM ruby:3.2.0


RUN apt-get update -qq && \
    apt-get install -y build-essential libsqlite3-dev curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

WORKDIR /app

# Устанавливаем переменные окружения для production
ENV RAILS_ENV=production
ENV NODE_ENV=production

# Копируем Gemfile и Gemfile.lock, устанавливаем Ruby gems без разработки и тестов
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Копируем package.json и yarn.lock, устанавливаем npm пакеты только для production
COPY package.json yarn.lock ./
RUN yarn install --production

# Копируем конфигурации для Tailwind/PostCSS (если используются)
COPY tailwind.config.js postcss.config.js ./

# Обновляем базу данных browserslist (опционально, для оптимизаций Tailwind/PostCSS)
RUN npx update-browserslist-db@latest

# Копируем весь проект
COPY . .

# Готовим директорию для ассетов (если требуется)
RUN mkdir -p ./app/assets/builds

RUN bin/rails credentials:edit

# Прекомпилируем ассеты Rails (включает сборку JS через esbuild, Importmap, Tailwind и т.д.)
RUN ./bin/rails tailwindcss:install

# Открываем порт, на котором будет доступно приложение
EXPOSE 3000

# Запускаем сервер, слушая все интерфейсы
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

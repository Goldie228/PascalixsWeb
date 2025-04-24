# syntax = docker/dockerfile:1

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t my-app .
# docker run -d -p 80:80 -p 443:443 --name my-app -e RAILS_MASTER_KEY=<value from config/master.key> my-app

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
FROM ruby:3.2.0

# Обновляем списки пакетов и устанавливаем зависимости
RUN apt-get update -qq && \
    apt-get install -y build-essential libsqlite3-dev curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

WORKDIR /app

# Устанавливаем режим разработки
ENV RAILS_ENV=development

# Копируем Gemfile и устанавливаем гемы
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Копируем package.json и устанавливаем npm пакеты
COPY package.json yarn.lock ./
RUN yarn install

# Копируем tailwind и postcss конфигурацию
COPY tailwind.config.js postcss.config.js .postcssrc.json ./

# Обновляем базу данных browserslist
RUN npx update-browserslist-db@latest

# Копируем весь проект
COPY . .

# Компилируем CSS
RUN mkdir -p ./app/assets/builds
RUN yarn build:css

# Компилируем ассеты Rails
RUN bin/rails assets:precompile

# Открываем порт
EXPOSE 3000

# Запускаем сервер на 0.0.0.0 для доступа извне
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

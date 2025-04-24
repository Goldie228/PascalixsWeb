import { Application } from "@hotwired/stimulus"
const application = Application.start()

// Эта функция автоматически импортирует все контроллеры
const context = require.context(".", true, /\.js$/)
context.keys().forEach((key) => {
  if (key === "./index.js") return
  application.register(key.replace(/(\.\/|\.js)/g, ""), context(key).default)
})

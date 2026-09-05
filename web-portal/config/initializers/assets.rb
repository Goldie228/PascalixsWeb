Rails.application.config.assets.precompile += %w[account_drawer.js purchase_pass_modal.js navbar.js]
Rails.application.config.assets.paths << Rails.root.join("app", "assets", "fonts")
Rails.application.config.assets.precompile += %w( *.ttf *.woff *.woff2 )

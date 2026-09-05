namespace :tailwind do
  desc "Install and setup Tailwind CSS"
  task setup: :environment do
    puts "Installing Tailwind CSS and dependencies..."
    
    # Install required npm packages
    system "npm install --save tailwindcss@3.4.0 daisyui@4.5.0 autoprefixer@10.4.21 postcss@8.4.35"
    
    # Create tailwind config file if it doesn't exist
    unless File.exist?(Rails.root.join("tailwind.config.js"))
      system "npx tailwindcss init"
    end
    
    # Generate CSS files
    puts "Compiling Tailwind CSS..."
    system "npx tailwindcss -i ./app/assets/tailwind/application.css -o ./app/assets/stylesheets/tailwind.css"
    
    puts "Tailwind CSS setup completed successfully!"
  end
  
  desc "Compile Tailwind CSS"
  task compile: :environment do
    puts "Compiling Tailwind CSS..."
    system "npx tailwindcss -i ./app/assets/tailwind/application.css -o ./app/assets/stylesheets/tailwind.css"
    puts "Compilation completed!"
    
    # Копируем файл в builds для доступа через asset pipeline
    FileUtils.mkdir_p(Rails.root.join("app", "assets", "builds"))
    FileUtils.cp(
      Rails.root.join("app", "assets", "stylesheets", "tailwind.css"),
      Rails.root.join("app", "assets", "builds", "tailwind.css")
    )
    puts "CSS file copied to builds directory."
  end
  
  desc "Switch to using local Tailwind CSS"
  task use_local: :environment do
    layout_file = Rails.root.join("app", "views", "layouts", "application.html.erb")
    content = File.read(layout_file)
    
    # Заменяем CDN-ссылки на локальные стили
    if content.include?("cdn.jsdelivr.net/npm/tailwindcss")
      content.gsub!(
        /<!-- CDN ссылки для быстрого исправления -->\s+<link href=".*tailwindcss.*" rel="stylesheet">\s+<link href=".*daisyui.*" rel="stylesheet">/m,
        "<!-- Важно: подключаем локальные стили вместо CDN -->\n    <%= stylesheet_link_tag \"tailwind\", \"data-turbo-track\": \"reload\" %>"
      )
      
      File.write(layout_file, content)
      puts "Switched to local Tailwind CSS in layout file."
    else
      puts "Already using local Tailwind CSS."
    end
    
    # Компилируем Tailwind для применения изменений
    Rake::Task["tailwind:compile"].invoke
  end
end 
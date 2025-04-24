namespace :assets do
  desc "Simple assets refresh (legacy version - deprecated)"
  task simple_refresh: :environment do
    puts "WARNING: This task is deprecated, please use bin/refresh-assets instead"
    Rake::Task["assets:clobber"].invoke
    Rake::Task["assets:precompile"].invoke
  end
end

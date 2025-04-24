namespace :assets do
  desc "Clobber and precompile assets"
  task auto_refresh: :environment do
    Rake::Task["assets:clobber"].invoke
    Rake::Task["assets:precompile"].invoke
  end
end
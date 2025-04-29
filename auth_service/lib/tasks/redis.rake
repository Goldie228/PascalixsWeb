namespace :redis do
  desc "Create RediSearch index"
  task create_index: :environment do
    command = [
      'FT.CREATE', 'user_idx',
      'ON', 'HASH',
      'PREFIX', '1', 'user:',
      'SCHEMA',
      'user_id', 'TEXT'
    ]

    redis = Redis.new(host: ENV.fetch('REDIS_HOST', 'localhost'), port: ENV.fetch('REDIS_PORT', 6379))
    redis.call(*command)
    puts "RediSearch index created successfully"
  rescue => e
    puts "Error creating index: #{e.message}"
  end
end

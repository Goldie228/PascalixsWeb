#!/usr/bin/env ruby
require 'open3'

Dir.chdir('/home/goldie/Progs/Pascalixs/PascalixsWeb/auth_service')

# Run specific test files that were failing
tests = [
  'spec/models/role_spec.rb',
  'spec/models/user_spec.rb',
  'spec/factories_spec.rb',
]

total_examples = 0
total_failures = 0

tests.each do |test|
  cmd = "bundle exec rspec #{test} --order defined 2>&1"
  stdout, stderr, status = Open3.capture3(cmd)
  output = stdout + stderr
  
  # Extract example and failure counts
  lines = output.lines
  last_lines = lines.last(5).join
  
  if match = last_lines.match(/(\d+) examples?, (\d+) failure/)
    examples = match[1].to_i
    failures = match[2].to_i
    total_examples += examples
    total_failures += failures
    puts "#{test}: #{examples} examples, #{failures} failures"
  else
    puts "#{test}: Could not parse results"
    puts last_lines
  end
end

puts "\nTotal: #{total_examples} examples, #{total_failures} failures"

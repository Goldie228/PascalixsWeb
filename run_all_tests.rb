#!/usr/bin/env ruby
# Run all tests in a single rspec invocation (much faster than per-file)
require 'open3'

Dir.chdir('/home/goldie/Progs/Pascalixs/PascalixsWeb/auth_service')

# Run ALL specs in one go — single Rails boot, ~10x faster
cmd = "bundle exec rspec --format documentation --order defined 2>&1"
stdout, stderr, status = Open3.capture3(cmd)
output = stdout + stderr

puts output
puts
puts "Exit status: #{status}"

File.write('/tmp/test_results.txt', { exit_status: status.to_s, output: output }.to_json)
puts "Results saved to /tmp/test_results.txt"

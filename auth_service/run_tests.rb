#!/usr/bin/env ruby
require 'open3'

Dir.chdir('/home/goldie/Progs/Pascalixs/PascalixsWeb/auth_service')
cmd = 'bundle exec rspec spec/requests/api/v1/auth_spec.rb --order defined 2>&1'
stdout, stderr, status = Open3.capture3(cmd)
File.write('/tmp/test_output.txt', stdout + stderr)
File.write('/tmp/test_status.txt', status.to_s)
puts "Exit status: #{status}"
puts "Output length: #{(stdout + stderr).length}"

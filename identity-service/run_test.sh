#!/bin/bash
cd /home/goldie/Progs/Pascalixs/PascalixsWeb/identity-service
bundle exec rspec spec/requests/api/v1/auth_spec.rb --order defined 2>&1 | tail -80
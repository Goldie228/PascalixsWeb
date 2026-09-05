ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load environment variables from parent directory's .env file
require 'dotenv'
Dotenv.load(File.expand_path('../../../.env', __dir__))

# Set default test values for OAuth credentials if not present
# This ensures tests can run even without a .env file in the identity-service directory
ENV["DISCORD_CLIENT_ID"] ||= "test_discord_client_id"
ENV["DISCORD_CLIENT_SECRET"] ||= "test_discord_client_secret"
ENV["GOOGLE_CLIENT_ID"] ||= "test_google_client_id"
ENV["GOOGLE_CLIENT_SECRET"] ||= "test_google_client_secret"
ENV["WEB_PORTAL_URL"] ||= "http://localhost:3000"
ENV["IDENTITY_SERVICE_URL"] ||= "http://localhost:3001"

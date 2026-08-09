# frozen_string_literal: true

# Configure Active Record encryption for test environment
# Rails 8.1 requires encryption keys to be set via credentials or config
ActiveRecord::Encryption.configure(
  primary_key: "test-primary-key-that-is-32-chars",
  deterministic_key: "test-deterministic-key-32-chars!!",
  key_derivation_salt: "test-key-derivation-salt"
)

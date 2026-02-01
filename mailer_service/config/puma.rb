threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", ENV['PORT'])

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

ssl_bind "0.0.0.0", "#{ENV['PORT']}", {
  key: "config/ssl/server.key",
  cert: "config/ssl/server.crt",
  verify_mode: "none"
}

#!/bin/bash -e

# Enable jemalloc for reduced memory usage and latency.
if [ -z "${LD_PRELOAD+x}" ] && [ -f /usr/lib/*/libjemalloc.so.2 ]; then
  export LD_PRELOAD="$(echo /usr/lib/*/libjemalloc.so.2)"
fi

bundle exec rails server -p 3002 -b 0.0.0.0 -d
bundle exec karafka server

exec "${@}"

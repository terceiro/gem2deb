#!/bin/sh

exec 2>&1
set -eu

run() {
  echo "$" "$@"
  "$@"
  echo
}

create_file() {
  cat > "${1}"
  show_file "${1}"
}

show_file() {
  for f in $@; do
    echo "${f}"
    echo "${f}" | sed -e 's/./-/g'
    sed -e 's/^/| /' "${f}"
    echo "${f}" | sed -e 's/./-/g'
    echo
  done
}

gem=${1}
ruby=${2:-ruby}
src=$(pwd)

# Create a dummy rails app skeleton
cd ${AUTOPKGTEST_TMP:-/tmp}
rm -rf testapp
mkdir testapp
cd testapp
mkdir -p config
mkdir -p app/assets/javascripts

create_file Gemfile <<EOF
gem "rake"
gem "railties"
gem "sass-rails"
gem '${gem}'
EOF

# Include the rails assets we want to test
cp -r ${src}/debian/tests/assets app/
show_file $(find app/ -type f)

run $ruby -S bundle install --local

# Copied from rails new foo
create_file Rakefile <<EOF
require_relative 'config/application'

Rails.logger = Logger.new(STDOUT)
Rails.application.load_tasks
EOF

# Copied from rails new foo
create_file config/application.rb <<EOF
require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Foo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
EOF

# Copied from rails new foo
create_file config/boot.rb <<EOF
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
EOF

# Copied from rails new foo
create_file config/environment.rb <<EOF
# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!
EOF

# Confirm sprockets can find the asset
run $ruby -S bundle exec rake assets:precompile

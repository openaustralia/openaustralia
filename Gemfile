# This Gemfile is used ONLY for deployment and other dev tools
# Capistrano configures the destination server with openaustralia-parser/Gemfile and openaustralia-parser/.ruby-version

source 'https://rubygems.org'

ruby file: ".ruby-version"

gem 'capistrano', '~> 3.20'
gem 'capistrano-aws'
gem 'capistrano-bundler'
gem 'capistrano-composer'
gem 'capistrano-rbenv'
gem "capistrano-tagging3", "~> 2.0"

# XML library for aws-sdk-core (rexml is no longer a default gem in Ruby 3.4)
gem 'rexml'

# needed for capistrano to work with ed25519 ssh keys
gem 'ed25519', '>= 1.2', '< 2.0'
gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0'

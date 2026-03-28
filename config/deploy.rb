# Common Capistrano 3 configuration
set :application, 'openaustralia.org'
set :repo_url, 'https://github.com/openaustralia/openaustralia.git'
set :deploy_via, :remote_cache

# Ruby/rbenv configuration
# Check for this ruby manager first in openaustralia-parser:bin/run
set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip

# Bundler configuration
set :bundle_gemfile, 'openaustralia-parser/Gemfile'
set :bundle_roles, :app
set :bundle_flags, '--deployment'

# Use sudo for apache restart
set :use_sudo, true

# Keep last 5 releases
set :keep_releases, 5

# SSH options
set :ssh_options, {
  forward_agent: true,
  user: 'deploy',
  keys: %w[~/.ssh/id_rsa],
  verify_host_key: :accept_new_or_local_tunnel,
  # verbose: :info
}

# Load stage-specific configuration
load "#{__dir__}/deploy/#{fetch(:stage, 'staging')}.rb"

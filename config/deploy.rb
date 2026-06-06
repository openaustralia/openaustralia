# Common Capistrano 3 configuration
set :application, 'openaustralia.org'
set :repo_url, 'https://github.com/openaustralia/openaustralia.git'
set :deploy_via, :remote_cache

# Ruby/rbenv configuration
# Check for this ruby manager first in openaustralia-parser:bin/run
set :rbenv_type, :user
set :rbenv_ruby, File.read('openaustralia-parser/.ruby-version').strip

# Bundler configuration
set :bundle_gemfile, 'openaustralia-parser/Gemfile'
set :bundle_roles, :app
set :bundle_config, { deployment: true }

# Composer configuration (PHP dependencies for the twfy app).
# composer.json lives in the twfy submodule, so override the default working
# directory (which is release_path). capistrano/composer hooks composer:install
# into `before deploy:updated`, which runs after our custom git:create_release
# task has populated release_path, so release_path/twfy/composer.json exists by
# the time composer runs.
set :composer_roles, :app
set :composer_working_dir, -> { release_path.join('twfy') }
set :composer_install_flags, '--no-dev --prefer-dist --no-interaction --optimize-autoloader'

# Use sudo for apache restart
set :use_sudo, true

# Keep last 5 releases
set :keep_releases, 5

# SSH options
set :ssh_options, {
  forward_agent: true,
  user: 'deploy',
  keys: [ENV['DEPLOY_SSH_KEY'], '~/.ssh/id_ed25519', '~/.ssh/id_rsa'].compact,
  verify_host_key: :accept_new_or_local_tunnel,
  # verbose: :info
}

# Load stage-specific configuration
stage_config = File.join(__dir__, 'deploy', "#{fetch(:stage, 'staging')}.rb")
if File.exist?(stage_config)
  load stage_config
else
  puts "warning: No stage-specific configuration found for #{fetch(:stage, 'staging').inspect}!"
end

# Tagging options
set :tagging3_format, ':stage_:release'

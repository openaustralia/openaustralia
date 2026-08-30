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

# AWS EC2 instance lookup (capistrano-aws). The instance is tagged by Terraform
# (infrastructure:terraform/openaustralia/production.tf) with Application and
# Roles tags for exactly this purpose.
set :aws_ec2_regions, ['ap-southeast-2']

# Use the instance ID as the contact point as that is what SSM needs.
set :aws_ec2_contact_point, :id

# Don't filter on the stage tag: the single instance has no Stage tag because
# it is the deploy target for both production and staging.
set :aws_ec2_default_filters, (proc {
  [
    {
      name: "tag:#{fetch(:aws_ec2_application_tag)}",
      values: [fetch(:aws_ec2_application)]
    },
    {
      name: 'instance-state-name',
      values: ['running']
    }
  ]
})

# SSH options - proxied through AWS SSM Session Manager, so no direct SSH
# access to the instance is needed. Key auth still happens over the tunnel.
#
# --profile oaf only when NOT running in GitHub Actions - same "oaf" pin as
# infrastructure repo's bin/ssh-config (its own comment explains why: this
# ProxyCommand string runs later, at `ssh` time, potentially from a
# completely different shell/context than whatever ran this file, so it
# can't rely on AWS_PROFILE being set there either - only ad hoc commands an
# operator runs themselves get to assume that). But there is no "oaf" profile
# on a GitHub Actions runner - deploy-production.yml/deploy-staging.yml
# federate via OIDC (configure-aws-credentials) and export temporary
# credentials as plain environment variables instead, which a --profile flag
# would shadow rather than use.
ssm_proxy_profile = ENV['GITHUB_ACTIONS'] ? '' : '--profile oaf '
set :ssh_options, {
  forward_agent: true,
  user: 'deploy',
  keys: [ENV['DEPLOY_SSH_KEY'], '~/.ssh/id_ed25519', '~/.ssh/id_rsa'].compact,
  verify_host_key: :accept_new_or_local_tunnel,
  proxy: Net::SSH::Proxy::Command.new(
    "aws ssm start-session #{ssm_proxy_profile}--target %h " \
    '--document-name AWS-StartSSHSession --parameters portNumber=%p'
  ),
  # verbose: :info
}

# Tagging options
set :tagging3_format, ':stage_:release'

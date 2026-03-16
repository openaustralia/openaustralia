server 'staging.openaustralia.org.au', user: 'deploy', roles: %w[app web], primary: true

set :deploy_to, '/srv/www/staging'
set :branch, 'staging'

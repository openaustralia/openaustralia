puts '=' * 75, "NOTICE: using branch: #{ENV.fetch('STAGING_BRANCH', 'staging')} on server: staging.openaustralia.org.au NOT production on live!", '=' * 75

server 'staging.openaustralia.org.au', user: 'deploy', roles: %w[app web], primary: true

set :deploy_to, '/srv/www/production'
set :branch, ENV.fetch('STAGING_BRANCH', 'staging')

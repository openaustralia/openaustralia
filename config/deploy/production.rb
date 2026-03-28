puts '=' * 75, 'NOTICE: using branch: staging on server: staging.openaustralia.org.au NOT production!', '=' * 75

server 'staging.openaustralia.org.au', user: 'deploy', roles: %w[app web], primary: true

set :deploy_to, '/srv/www/production'
set :branch, 'staging'

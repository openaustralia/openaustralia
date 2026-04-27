puts '=' * 75, "NOTICE: using branch: #{ENV.fetch('OVERRIDE_BRANCH', 'main')} on server: newprod.openaustralia.org.au NOT production on live!", '=' * 75

server 'newprod.openaustralia.org.au', user: 'deploy', roles: %w[app web], primary: true

set :deploy_to, '/srv/www/production'
set :branch, ENV.fetch('OVERRIDE_BRANCH', 'main')

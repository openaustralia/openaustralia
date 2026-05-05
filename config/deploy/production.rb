server 'openaustralia.org.au', user: 'deploy', roles: %w[app web], primary: true

set :deploy_to, '/srv/www/production'
set :branch, ENV.fetch('PRODUCTION_BRANCH', 'main')

puts '=' * 75, "NOTICE: deploying #{ENV['PRODUCTION_BRANCH']} NOT main branch to production!", '=' * 75 if ENV['PRODUCTION_BRANCH']

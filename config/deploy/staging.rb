server 'openaustralia.org.au', user: 'deploy', roles: %w[app web], primary: true

set :deploy_to, '/srv/www/staging'
set :branch, ENV.fetch('STAGING_BRANCH', 'main')

puts '=' * 75, "NOTICE: deploying #{ENV['STAGING_BRANCH']} NOT main branch to staging!", '=' * 75 if ENV['STAGING_BRANCH']

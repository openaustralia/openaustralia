# Roles come from the instance's Roles tag (app,web)
aws_ec2_register(user: 'deploy')

set :deploy_to, '/srv/www/staging'
set :branch, ENV.fetch('STAGING_BRANCH', 'main')

puts '=' * 75, "NOTICE: deploying #{ENV['STAGING_BRANCH']} NOT main branch to staging!", '=' * 75 if ENV['STAGING_BRANCH']

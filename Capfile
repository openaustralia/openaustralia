# Capistrano 2.x recipe file
#
# Requirement cap 2.2
#
# Execute with:
# cap -S stage=<production|test> task

set :application, "openaustralia.org"

# default_run_options[:pty] = true

set :use_sudo, false

set :scm, :git
set :repository, "https://github.com/openaustralia/openaustralia.git"
set :git_enable_submodules, true
set :deploy_via, :remote_cache

set :stage, "test" unless exists? :stage

set :user, "deploy"

# A great little trick I learned recently. If you have a machine running on a non-standard ssh port
# put the following in your ~/.ssh/config file:
# Host myserver.com
#   Port 1234
# This will change the port for all ssh commands on that server which saves a whole lot of typing

if stage == "production"
  role :web, "openaustralia.org.au"
  set :deploy_to, "/srv/www/production"
elsif stage == "test"
  role :web, "openaustralia.org.au"
  set :deploy_to, "/srv/www/staging"
  set :branch, "test"
elsif stage == "development"
  role :web, "openaustralia.org.au.test"
  set :deploy_to, "/srv/www/production"
end
set :bundle_gemfile, "openaustralia-parser/Gemfile"

load 'deploy' if respond_to?(:namespace) # cap2 differentiator

require "bundler/capistrano"

# Clean up old releases so we don't fill up our disk
after "deploy:restart", "deploy:cleanup"

namespace :deploy do
	# Restart Apache because for some reason a deploy can cause trouble very occasionally (which is fixed by a restart). So, playing safe
	task :restart do
	 sudo "apache2ctl restart"
	end

	task :finalize_update do
		run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
	end

	desc "After a code update, we link the images directories to the shared ones"
	after "deploy:update_code" do
		links = {
			"#{release_path}/searchdb"                                => "../../shared/searchdb",

			"#{release_path}/openaustralia-parser/configuration.yml"  => "../../../shared/parser_configuration.yml",

			"#{release_path}/twfy/conf/general"                       => "../../../../shared/general",
			"#{release_path}/twfy/scripts/alerts-lastsent"            => "../../../../shared/alerts-lastsent",

			"#{release_path}/twfy/www/docs/sitemap.xml"               => "../../../../../shared/sitemap.xml",
			"#{release_path}/twfy/www/docs/sitemaps"                  => "../../../../../shared/sitemaps",

		  "#{release_path}/twfy/www/docs/images/mps"                => "../../../../../../shared/images/mps",
      "#{release_path}/twfy/www/docs/images/mpsL"               => "../../../../../../shared/images/mpsL",
      "#{release_path}/twfy/www/docs/images/mpsXL"              => "../../../../../../shared/images/mpsXL",
			"#{release_path}/twfy/www/docs/regmem/scan"               => "../../../../../../shared/regmem_scan",
			"#{release_path}/twfy/www/docs/rss/mp"                    => "../../../../../../shared/rss/mp",
			"#{release_path}/twfy/www/docs/debates/debates.rss"       => "../../../../../../shared/rss/senate.rss",
			"#{release_path}/twfy/www/docs/senate/senate.rss"       => "../../../../../../shared/rss/senate.rss"
		}
		# First copy any images that have been checked into the repository to the shared area
		run "cp #{release_path}/twfy/www/docs/images/mps/* #{shared_path}/images/mps"
		run "cp #{release_path}/twfy/www/docs/images/mpsL/* #{shared_path}/images/mpsL"
		# HACK: Remove directories next because they have files in them
		run "rm -rf #{release_path}/twfy/www/docs/images/mps #{release_path}/twfy/www/docs/images/mpsL #{release_path}/twfy/www/docs/rss/mp"
		# "ln -sf <a> <b>" creates a symbolic link but deletes <b> if it already exists
		run links.map {|a| "ln -sf #{a.last} #{a.first}"}.join(";")
		# Now compile twfy/scripts/run-with-lockfile.c
		run "gcc -o #{release_path}/twfy/scripts/run-with-lockfile #{release_path}/twfy/scripts/run-with-lockfile.c"
	end

  task :setup_db do
    run "mysql < #{current_path}/twfy/db/schema.sql"
  end
end

namespace :parse do
	desc 'Parses data about MPs & Senators and loads it into OpenAustralia'
	task :members do
		run "#{current_path}/openaustralia-parser/parse-members.rb"
	end
end

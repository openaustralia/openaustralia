# Capistrano 2.x recipe file
#
# Requirement cap 2.2

require 'tempfile'

set :application, "openaustralia"

# default_run_options[:pty] = true

set :use_sudo, false

set :scm, :git
set :repository, "git://github.com/mlandauer/openaustralia.git"
set :git_enable_submodules, true
set :deploy_via, :remote_cache

local_deploy = false

if local_deploy
	set :deploy_to, "/Library/WebServer/Documents/test-deploy/#{application}"
	role :web, "localhost"
	set :user, "matthewl"
	set :scm_command, "/opt/local/bin/git"
else
	set :deploy_to, "/www/openaustralia.org/#{application}"
	role :web, "www.openaustralia.org"
	set :user, "matthewl"
end

load 'deploy' if respond_to?(:namespace) # cap2 differentiator

namespace :deploy do
	task :setup do
		dirs = [deploy_to, releases_path, shared_path]
		shared_images_path = File.join(shared_path, "images")
		dirs += ["mps", "mpsL"].map {|d| File.join(shared_images_path, d)}
		dirs << File.join(shared_path, "rss", "mp")
		run "umask 02 && mkdir -p #{dirs.join(' ')}"
	end

	# Do nothing for deploy:restart
	task :restart do
	end

	task :finalize_update do
		run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
	end

	desc "After a code update, we link the images directories to the shared ones"
	task :after_update_code do
		links = {"#{release_path}/twfy/www/docs/images/mps" => "#{shared_path}/images/mps",
			"#{release_path}/twfy/www/docs/images/mpsL" => "#{shared_path}/images/mpsL",
			"#{release_path}/twfy/conf/general" => "#{shared_path}/general",
			"#{release_path}/twfy/www/docs/.htaccess" => "#{shared_path}/root_htaccess",
			"#{release_path}/openaustralia-parser/configuration.yml" => "#{shared_path}/parser_configuration.yml",
			"#{release_path}/xapiandb" => "#{shared_path}/xapiandb",
			"#{release_path}/searchdb" => "#{shared_path}/searchdb",
			"#{release_path}/twfy/www/docs/rss/mp" => "#{shared_path}/rss/mp",
			"#{release_path}/twfy/www/docs/debates/debates.rss" => "#{shared_path}/rss/debates.rss"}
		
		run "rm -rf #{links.keys.join(' ')}; " + links.map {|a| "ln -s #{a.last} #{a.first}"}.join(";")
		# Now compile twfy/scripts/run-with-lockfile.c
		run "gcc -o #{release_path}/twfy/scripts/run-with-lockfile #{release_path}/twfy/scripts/run-with-lockfile.c"
	end
	
	desc "Upload member images from local machine"
	task :images do
		put_directory "../pwdata/images/mps", "#{shared_path}/images/mps"
		put_directory "../pwdata/images/mpsL", "#{shared_path}/images/mpsL"
	end	
end

# Capistrano 2.x recipe file
#
# Requirement cap 2.2
#
# Execute with:
# cap -S stage=<production|test> task

require 'tempfile'

set :application, "openaustralia"

# default_run_options[:pty] = true

set :use_sudo, false

set :scm, :git
set :repository, "git://github.com/mlandauer/openaustralia.git"
set :git_enable_submodules, true
set :deploy_via, :remote_cache

ssh_options[:port] = 2506

set :stage, "" unless exists? :stage

set :user, "matthewl"
role :web, "www.openaustralia.org"
if stage == "production"
  set :deploy_to, "/www/www.openaustralia.org/#{application}"
elsif stage == "test"
  set :deploy_to, "/www/test.openaustralia.org/#{application}"
  set :branch, "test"
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
			"#{release_path}/searchdb" => "#{shared_path}/searchdb",
			"#{release_path}/twfy/www/docs/rss/mp" => "#{shared_path}/rss/mp",
			"#{release_path}/twfy/www/docs/debates/debates.rss" => "#{shared_path}/rss/debates.rss",
			"#{release_path}/twfy/scripts/alerts-lastsent" => "#{shared_path}/alerts-lastsent",
			"#{release_path}/twfy/www/docs/sitemap.xml" => "#{shared_path}/sitemap.xml",
			"#{release_path}/twfy/www/docs/sitemaps" => "#{shared_path}/sitemaps",
			"#{release_path}/twfy/www/docs/regmem/scan" => "#{shared_path}/regmem_scan"}
		
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
	
	desc "Upload member images from local machine"
	task :images do
		put_directory "../pwdata/images/mps", "#{shared_path}/images/mps"
		put_directory "../pwdata/images/mpsL", "#{shared_path}/images/mpsL"
	end	
end

# Capistrano 3.x Capfile
require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/scm/git'
install_plugin Capistrano::SCM::Git
require 'capistrano/bundler'
require 'capistrano/rbenv'

# Load custom tasks
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

namespace :deploy do
  desc 'Checkout code to release directory'
  task :checkout do
    on roles(:all) do
      cached_copy = "#{shared_path}/cached-copy"
      
      # Clone or fetch repo
      if test("[ -d #{cached_copy} ]")
        within cached_copy do
          execute :git, 'fetch', 'origin'
          execute :git, 'reset', '--hard', "origin/#{fetch(:branch)}"
          execute :git, 'clean', '-d', '-x', '-f'
        end
      else
        execute :git, 'clone', '--branch', fetch(:branch), fetch(:repo_url), cached_copy
        within cached_copy do
          execute :git, 'reset', '--hard', "origin/#{fetch(:branch)}"
          execute :git, 'clean', '-d', '-x', '-f'
        end
      end
      
      # Update submodules
      within cached_copy do
        execute :git, 'submodule', 'init'
        execute :git, 'submodule', 'update', '--recursive'
      end
      
      # Copy to release directory
      execute :cp, '-PR', cached_copy, release_path
    end
  end

  desc 'Create symlinks to shared directories'
  task :symlink_shared do
    on roles(:all) do
      links = {
        'searchdb' => '../../../shared/searchdb',
        'openaustralia-parser/configuration.yml' => '../../../../shared/parser_configuration.yml',
        'twfy/conf/general' => '../../../../../shared/general',
        'twfy/scripts/alerts-lastsent' => '../../../../../shared/alerts-lastsent',
        'twfy/www/docs/sitemap.xml' => '../../../../../../shared/sitemap.xml',
        'twfy/www/docs/sitemaps' => '../../../../../../shared/sitemaps',
        'twfy/www/docs/images/mps' => '../../../../../../../shared/images/mps',
        'twfy/www/docs/images/mpsL' => '../../../../../../../shared/images/mpsL',
        'twfy/www/docs/images/mpsXL' => '../../../../../../../shared/images/mpsXL',
        'twfy/www/docs/regmem/scan' => '../../../../../../../shared/regmem_scan',
        'twfy/www/docs/rss/mp' => '../../../../../../../shared/rss/mp',
        'twfy/www/docs/debates/debates.rss' => '../../../../../../../shared/rss/senate.rss',
        'twfy/www/docs/senate/senate.rss' => '../../../../../../../shared/rss/senate.rss'
      }
      
      within release_path do
        # Copy checked-in images to shared area
        execute :bash, '-c', "cp twfy/www/docs/images/mps/* #{shared_path}/images/mps 2>/dev/null || true"
        execute :bash, '-c', "cp twfy/www/docs/images/mpsL/* #{shared_path}/images/mpsL 2>/dev/null || true"
        
        # Remove directories with checked-in files
        execute :rm, '-rf', 'twfy/www/docs/images/mps', 'twfy/www/docs/images/mpsL', 'twfy/www/docs/rss/mp', '||', 'true'
        
        # Create symlinks
        links.each do |from, to|
          execute :bash, '-c', "ln -sf #{to} #{from} || true"
        end
      end
    end
  end

  desc 'Compile run-with-lockfile'
  task :compile_lockfile do
    on roles(:all) do
      execute :gcc, '-o', "#{release_path}/twfy/scripts/run-with-lockfile", "#{release_path}/twfy/scripts/run-with-lockfile.c"
    end
  end

  desc 'Restart Apache'
  task :restart do
    on roles(:web) do
      execute :sudo, '/usr/sbin/apache2ctl', 'restart'
    end
  end

  task :setup_db do
    on roles(:db) do
      within current_path do
        execute :mysql, '<', "#{current_path}/twfy/db/schema.sql"
      end
    end
  end
end

# Deploy hooks
after 'deploy:new_release_path', 'deploy:checkout'
after 'deploy:checkout', 'deploy:symlink_shared'
after 'deploy:symlink_shared', 'deploy:compile_lockfile'
after 'deploy:published', 'deploy:restart'

namespace :parse do
  desc 'Parse member data and load into OpenAustralia'
  task :members do
    on roles(:app) do
      within release_path do
        execute :bash, '-c', 'cd openaustralia-parser && bundle exec parse-members.rb'
      end
    end
  end
end

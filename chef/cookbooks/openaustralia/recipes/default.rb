#
# Cookbook Name:: openaustralia
# Recipe:: default
#

require_recipe 'xapian'
require_recipe 'apache'
require_recipe 'php'
require_recipe 'mysql'

[:production, :test].each do |stage|
  directory node[:openaustralia][stage][:install_path] do
    owner "matthewl"
    group "matthewl"
    mode 0755
    recursive true
  end

  # Hmmm... I wonder if Apache will start up if the openaustralia app is not installed
  link node[:openaustralia][stage][:html_root] do
    to "openaustralia/current/twfy/www/docs"
  end

  %w{shared releases shared/images/mps shared/images/mpsL shared/rss/mp}.each do |dir|
    directory "#{node[:openaustralia][stage][:install_path]}/#{dir}" do
      owner "matthewl"
      group "matthewl"
      mode 0775
      recursive true
    end
  end

  # Xapian Search directory needs to be writable by www
  directory "#{node[:openaustralia][stage][:install_path]}/shared/searchdb" do
    owner "matthewl"
    group "www"
    mode 0775
  end

  # Configuration for OpenAustralia web app
  template "#{@node[:openaustralia][stage][:install_path]}/shared/general" do
    source "general.erb"
    owner "matthewl"
    group "matthewl"
    mode 0644
    variables :stage_config => @node[:openaustralia][stage]
  end

  template "#{@node[:openaustralia][stage][:install_path]}/shared/parser_configuration.yml" do
    source "parser_configuration.yml.erb"
    owner "matthewl"
    group "matthewl"
    mode 0644
    variables :stage_config => @node[:openaustralia][stage]
  end  
end

directory "/www/secure/html" do
  owner "matthewl"
  group "matthewl"
  mode 0755
  action :create
  recursive true
end

# PHP bits and pieces
package "php5-ctype"
package "php5-curl"

# Ruby bits and pieces
gem_package "activesupport"
package "ruby-iconv"
package "ImageMagick"
gem_package "rmagick"
gem_package "mechanize" do
  version "0.8.5"
end
gem_package "htmlentities"
gem_package "log4r"

# Perl bits and pieces
package "p5-XML-Twig"

# TODO:
#   cron jobs

# Needed to put a password on the test instance
apache_module "authn_file"
apache_module "auth_basic"
apache_module "authz_user"
# Needed to display directory listings for data.openaustralia.org
apache_module "autoindex"
# Needed to use "Options MultiViews" (which is required for /api/key to find /api/key.php)
apache_module "negotiation"
# Required for ProxyPass on software.openaustralia.org
apache_module "proxy"

remote_file @node[:openaustralia][:test][:apache_password_file] do
  source "htpasswd"
  mode 0644
end

template "#{@node[:apache][:dir]}/sites-available/default" do
  source "apache_production.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

template "#{@node[:apache][:dir]}/sites-available/test" do
  source "apache_test.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

template "#{@node[:apache][:dir]}/sites-available/software" do
  source "apache_software.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

template "#{@node[:apache][:dir]}/sites-available/data" do
  source "apache_data.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

apache_site "default"
apache_site "test"
apache_site "software"
apache_site "data"

#MAILTO=matthew@openaustralia.org
#HOME=/www/www/openaustralia/current/twfy/scripts
#PATH=/usr/local/bin

# daily update at night for MP data (regmem, data from Public Whip etc.)
#cron "dailyupdate" do
#  provider Chef::Provider::Cron
#  hour 1
#  minute 37
#  command "HOME=#{@node[:openaustralia][:production][:install_path]}/current/twfy/scripts $HOME/dailyupdate"
#  user "matthewl"
#end

# every week early Sunday grab weekly range of data
#cron "weeklyupdate" do
#  provider Chef::Provider::Cron
#  weekday "Sun"
#  hour 4
#  minute 23
#  command "HOME=#{@node[:openaustralia][:production][:install_path]}/current/twfy/scripts $HOME/weeklyupdate"
#  user "matthewl"
#end

# daily backup of database
#cron "dumpallforbackup" do
#  provider Chef::Provider::Cron
#  hour 2
#  minute 30
#  command "HOME=#{@node[:openaustralia][:production][:install_path]}/current/twfy/scripts $HOME/dumpallforbackup"
#  user "matthewl"
#end

# Morning update (Australian Hansard is supposed to be up by 9am the next working day)
#cron "morningupdate" do
#  provider Chef::Provider::Cron
#  hour 9
#  minute 5
#  weekday "Mon-Fri"
#  command "HOME=#{@node[:openaustralia][:production][:install_path]}/current/twfy/scripts VERBOSE=true $HOME/morningupdate"
#  user "matthewl"
#end

# Email updates (Going at 10am to give me time to fix things if necessary)
#cron "alertmailer" do
#  provider Chef::Provider::Cron
#  weekday "Mon-Fri"
#  hour 10
#  minute 0
#  command "HOME=#{@node[:openaustralia][:production][:install_path]}/current/twfy/scripts php -q alertmailer.php"
#  user "matthewl"
#end

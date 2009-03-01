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
    action :create
    recursive true
  end

  # Hmmm... I wonder if Apache will start up if the openaustralia app is not installed
  link node[:openaustralia][stage][:html_root] do
    to "#{node[:openaustralia][stage][:install_path]}/current/twfy/www/docs"
  end

  directory "#{node[:openaustralia][stage][:install_path]}/shared" do
    owner "matthewl"
    group "matthewl"
    mode 0775
    action :create
  end

  # Xapian Search directory needs to be writable by www
  directory "#{node[:openaustralia][stage][:install_path]}/shared/searchdb" do
    owner "matthewl"
    group "www"
    mode 0775
    action :create
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

directory "/www/secure.openaustralia.org/html" do
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
#   email
#   cron jobs
#   Wordpress
#   Mediawiki
#   Password on test website

template "#{@node[:apache][:dir]}/sites-available/default" do
  source "apache_production.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

template "#{@node[:apache][:dir]}/sites-available/openaustralia.org" do
  source "apache_production_redirect.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

template "#{@node[:apache][:dir]}/sites-available/test.openaustralia.org" do
  source "apache_test.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

apache_site "default"
apache_site "openaustralia.org"
apache_site "test.openaustralia.org"

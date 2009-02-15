#
# Cookbook Name:: openaustralia
# Recipe:: default
#

# For capistrano deploy we need at least version 1.5.5 of git
# So, slightly hacky. Going to force install from ports (which we're assuming has been updated)
package "git" do
  source "ports"
end

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

package "apache" do
  source "apache22"
end

# Need to specify the build option for the php5 package below
remote_file "/var/db/ports/php5/options" do
  source "php5.ports.options"
  mode 0644
  owner "root"
  group "wheel"
end

# Need to build php5 from ports to select the option for building mod_php
package "php5" do
  source "ports"
end

# Xapian bindings for php (as well as other languages)
package "xapian-bindings"
# Xapian bindings for Perl
package "p5-Search-Xapian"

package "php5-ctype"

# Would be nicer to just check that the "extension=xapian.so" line is present
# rather than overwriting the whole file everytime
remote_file "/usr/local/etc/php/extensions.ini" do
  source "extensions.ini"
end

package "mysql-server" do
  source "mysql50-server"
end
package "php5-mysql"
package "php5-curl"

service "mysql-server" do
  supports :status => true, :restart => true
  action [:enable, :start]
end

service "apache22" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

remote_file "/usr/local/etc/apache22/httpd.conf" do
  source "httpd.conf"
  mode 0644
  owner "root"
  group "wheel"
  notifies :reload, resources("service[apache22]")
end

remote_file "/usr/local/etc/apache22/extra/httpd-vhosts.conf" do
  source "httpd-vhosts.conf"
  mode 0644
  owner "root"
  group "wheel"
  notifies :reload, resources("service[apache22]")
end

# SSL key (first step of self-signed certificate)
execute "openssl genrsa 1024 > server.key" do
  cwd "/usr/local/etc/apache22"
  creates "/usr/local/etc/apache22/server.key"
end

# Provide defaults for generating certificate so this can all be done automatically
remote_file "/etc/ssl/openssl.cnf" do
  source "openssl.cnf"
  mode 0644
  owner "root"
  group "wheel"
end

execute "openssl req -batch -new -x509 -nodes -sha1 -days 365 -key server.key > server.crt" do
  cwd "/usr/local/etc/apache22"
  creates "/usr/local/etc/apache22/server.crt"
end

remote_file "/usr/local/etc/apache22/extra/httpd-ssl.conf" do
  source "httpd-ssl.conf"
  mode 0644
  owner "root"
  group "wheel"
  notifies :reload, resources("service[apache22]")
end

gem_package "activesupport"
# Temporarily installing from ports
package "ruby-iconv" do
  source "ports"
end
package "ImageMagick"
gem_package "rmagick"
gem_package "mechanize" do
  version "0.8.5"
end
package "p5-DBD-mysql50"
package "p5-XML-Twig"
gem_package "htmlentities"
gem_package "log4r"

# TODO:
#   email
#   cron jobs
#   Wordpress
#   Mediawiki
#   Mysql Admin
#   Xapian

service "sshd" do
  supports :status => true, :reload => true
end

remote_file "/etc/ssh/sshd_config" do
  source "sshd_config"
  notifies :reload, resources("service[sshd]")
end

# Because of an interesting naming difference between the port and the package as a workaround installing from the port
package "phpmyadmin" do
  source "ports"
end

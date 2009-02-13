#
# Cookbook Name:: openaustralia
# Recipe:: default
#

# For capistrano deploy we need at least version 1.5.5 of git
# So, slightly hacky. Going to force install from ports (which we're assuming has been updated)
package "git" do
  source "ports"
end

# Container for all the web applications
directory "/www" do
  owner "matthewl"
  group "matthewl"
  mode 0755
  action :create
end

directory "/www/www.openaustralia.org" do
  owner "matthewl"
  group "matthewl"
  mode 0755
  action :create
end

# Hmmm... I wonder if Apache will start up if the openaustralia app is not installed
link "/www/www.openaustralia.org/html" do
  to "openaustralia/current/twfy/www/docs"
end

link "/www/test.openaustralia.org/html" do
  to "openaustralia/current/twfy/www/docs"
end

# Configuration for OpenAustralia web app
remote_file "/www/www.openaustralia.org/openaustralia/shared/general" do
  source "www.openaustralia.org/general"
  owner "matthewl"
  group "matthewl"
end

remote_file "/www/www.openaustralia.org/openaustralia/shared/parser_configuration.yml" do
  source "www.openaustralia.org/parser_configuration.yml"
  owner "matthewl"
  group "matthewl"
end

remote_file "/www/test.openaustralia.org/openaustralia/shared/general" do
  source "test.openaustralia.org/general"
  owner "matthewl"
  group "matthewl"
end

remote_file "/www/test.openaustralia.org/openaustralia/shared/parser_configuration.yml" do
  source "test.openaustralia.org/parser_configuration.yml"
  owner "matthewl"
  group "matthewl"
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

# Setup clock synchronisation. This isn't necessary on a VPS because this is done for us.
# This is mainly needed for testing on a virtual machine where we want an accurate clock too
remote_file "/etc/ntp.conf" do
  source "ntp.conf"
end

service "ntpd" do
  supports :status => true
  action [:enable, :start]
end

# TODO:
#   Setup email
#   Setup cron jobs
#   Change SSH port to 2506
#   Setup Virtual Hosts


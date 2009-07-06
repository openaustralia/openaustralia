require_recipe 'apache'
require_recipe 'mysql'

directory "/var/db/ports/phpMyAdmin"

# Turn off pdflib (because we don't need it and it requires a heap of other dependencies)
remote_file "/var/db/ports/phpMyAdmin/options" do
  source "ports.options"
  mode 0644
end

# Install from ports so that it uses the currently installed version of mysql
package "phpmyadmin" do
  source "ports"
end

# Copy across configuration file for phpmyadmin
template "/usr/local/www/phpMyAdmin/config.inc.php" do
  source "config.inc.php.erb"
  mode 0640
  owner "root"
  group "www"
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

template "#{@node[:apache][:dir]}/sites-available/secure" do
  source "apache.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

apache_site "secure"
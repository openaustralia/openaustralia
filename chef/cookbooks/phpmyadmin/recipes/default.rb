require_recipe 'apache'
require_recipe 'mysql'

# Install from ports so that it uses the currently installed version of mysql
package "phpmyadmin" do
  source "ports"
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
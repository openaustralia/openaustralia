# TODO: currently contains configuration for the web apps mixed up the Apache configuration

package "apache" do
  source "ports:apache22"
end

remote_file "httpd.conf" do
  path "/usr/local/etc/apache22/httpd.conf"
  source "httpd.conf"
  mode 0644
  owner "root"
  group "wheel"
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

remote_file "httpd-ssl.conf" do
  path "/usr/local/etc/apache22/extra/httpd-ssl.conf"
  source "httpd-ssl.conf"
  mode 0644
  owner "root"
  group "wheel"
end

service "apache22" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  subscribes :reload, resources('remote_file[httpd.conf]', 'remote_file[httpd-ssl.conf]')
end

directory "/usr/local/etc/apache22/sites-enabled" do
  mode 0755
  owner "root"
  group "wheel"
end

# Add individual site virtual hosts here
%w{www.openaustralia.org openaustralia.org test.openaustralia.org wiki.openaustralia.org software.openaustralia.org blog.openaustralia.org}.each do |site|
  remote_file "site.conf" do
    if site == "www.openaustralia.org"
      path "/usr/local/etc/apache22/sites-enabled/000-default"
    else
      path "/usr/local/etc/apache22/sites-enabled/#{site}"
    end
    source "httpd-vhost-#{site}.conf"
    mode 0644
    owner "root"
    group "wheel"
    notifies :reload, resources(:service => "apache22")
  end
end

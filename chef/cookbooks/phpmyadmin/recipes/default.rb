# TODO: Requires Apache, Apache configuration, SSL setup
require_recipe 'apache'
 
# Because of an interesting naming difference between the port and the package as a workaround installing from the port
package "phpmyadmin" do
  source "ports"
end

template "#{@node[:apache][:dir]}/sites-available/secure.openaustralia.org" do
  source "apache.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

apache_site "secure.openaustralia.org"
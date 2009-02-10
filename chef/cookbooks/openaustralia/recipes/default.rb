#
# Cookbook Name:: openaustralia
# Recipe:: default
#

# Container for all the web applications
directory "/www" do
  owner "matthewl"
  group "matthewl"
  mode 0755
  action :create
end

package "git"
package "apache" do
  source "ports:apache22"
end

remote_file "/usr/local/etc/apache22/httpd.conf" do
  source "httpd.conf"
  mode 0644
  owner "root"
  group "wheel"
end

service "apache22" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  subscribes :reload, resources('remote_file[/usr/local/etc/apache22/httpd.conf]'), :immediately
end
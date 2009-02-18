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

service "apache22" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  subscribes :reload, resources('remote_file[httpd.conf]')
end

remote_file "/usr/local/bin/apache2_module_conf_generate.pl" do
  source "apache2_module_conf_generate.pl"
  mode 0755
  owner "root"
  group "wheel"
end

%w{sites-available sites-enabled mods-available mods-enabled}.each do |dir|
  directory "#{node[:apache][:dir]}/#{dir}" do
    mode 0755
    owner "root"
    group "wheel"
  end
end

execute "generate-module-list" do
  command "/usr/local/bin/apache2_module_conf_generate.pl /usr/local/libexec/apache22 #{node[:apache][:dir]}/mods-available"  
  action :run
end

%w{a2ensite a2dissite a2enmod a2dismod}.each do |modscript|
  template "/usr/local/sbin/#{modscript}" do
    source "#{modscript}.erb"
    mode 0755
    owner "root"
    group "wheel"
  end  
end

# Add individual site virtual hosts here
%w{wiki.openaustralia.org software.openaustralia.org blog.openaustralia.org}.each do |site|
  remote_file "site.conf" do
    path "/usr/local/etc/apache22/sites-available/#{site}"
    source "httpd-vhost-#{site}.conf"
    mode 0644
    owner "root"
    group "wheel"
  end
  
  apache_site site
end

apache_module "authz_host"
apache_module "log_config"
apache_module "setenvif"
apache_module "ssl"
apache_module "mime"
apache_module "alias"
apache_module "rewrite"
apache_module "dir"
apache_module "deflate"


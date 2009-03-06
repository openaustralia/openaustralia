directory "/var/db/ports/apache22"

# Building mod_proxy and mod_proxy_http as well. Settings this in the apache22 options file
remote_file "/var/db/ports/apache22/options" do
  source "apache22.ports.options"
  mode 0644
  owner "root"
  group "wheel"
end

# Perl is needed by the Apache install. Installing it explicitly from binary so that it doesn't get
# built from source in the Apache install (for speed)
package "perl5.8"

# Because we are setting build options we need to build this from source
package "apache22" do
  source "ports"
end

remote_file "httpd.conf" do
  path "/usr/local/etc/apache22/httpd.conf"
  source "httpd.conf"
  mode 0644
  owner "root"
  group "wheel"
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

service "apache22" do
  supports :status => true, :restart => true, :reload => true
  action [:enable]
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

directory "/www/wiki.#{node[:oa_domain]}"
directory "/www/wiki.#{node[:oa_domain]}/html"

# Add individual site virtual hosts here
%w{wiki software}.each do |site|
  template "site.conf" do
    path "/usr/local/etc/apache22/sites-available/#{site}.#{node[:oa_domain]}"
    source "httpd-vhost-#{site}.conf.erb"
    mode 0644
    owner "root"
    group "wheel"
  end
  
  apache_site "#{site}.#{node[:oa_domain]}"
end

service "apache22" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  subscribes :reload, resources('remote_file[httpd.conf]')
end


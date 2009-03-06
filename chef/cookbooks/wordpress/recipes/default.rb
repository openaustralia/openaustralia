include_recipe "apache"

directory "/www/blog.#{node[:oa_domain]}"
directory "/www/blog.#{node[:oa_domain]}/html"

template "site.conf" do
  path "/usr/local/etc/apache22/sites-available/blog.#{node[:oa_domain]}"
  source "httpd.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end
  
apache_site "blog.#{node[:oa_domain]}"



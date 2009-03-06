include_recipe "apache"

directory "/www/blog"
directory "/www/blog/html"

template "site.conf" do
  path "/usr/local/etc/apache22/sites-available/blog"
  source "httpd.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end
  
apache_site "blog"



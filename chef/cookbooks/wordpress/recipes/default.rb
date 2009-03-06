include_recipe "apache"

remote_file "site.conf" do
  path "/usr/local/etc/apache22/sites-available/blog.openaustralia.org"
  source "httpd.conf"
  mode 0644
  owner "root"
  group "wheel"
end
  
apache_site "blog.openaustralia.org"



include_recipe "apache"

package "www/wordpress" do
  source "ports"
end

template "/usr/local/www/data/wordpress/wp-config.php" do
  source "wp-config.php.erb"
  mode 0644
end

directory "/www/blog"

link "/www/blog/html" do
  to "/usr/local/www/data/wordpress"
end

template "site.conf" do
  path "/usr/local/etc/apache22/sites-available/blog"
  source "httpd.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end
  
apache_site "blog"



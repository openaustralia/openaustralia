require_recipe "apache"

# TODO: Still need to actually add the packages

directory "/www/wiki"
directory "/www/wiki/html"

template "/usr/local/etc/apache22/sites-available/wiki" do
  source "httpd.conf.erb"
  mode 0644
  owner "root"
  group "wheel"
end

apache_site "wiki"

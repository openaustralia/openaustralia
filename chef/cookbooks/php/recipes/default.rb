# Because we're building mod_php at the same time, we need Apache
require_recipe 'apache'

directory "/var/db/ports/php5" do
  owner "root"
  group "wheel"
end

# Need to specify the build option for the php5 package below
remote_file "/var/db/ports/php5/options" do
  source "php5.ports.options"
  mode 0644
  owner "root"
  group "wheel"
end

# Need to build php5 from ports to select the option for building mod_php
package "php5" do
  source "ports"
end

# Tell apache about the new module
remote_file "#{@node[:apache][:dir]}/mods-available/php5.load" do
  source "php5.load"
  mode 0644
  owner "root"
  group "wheel"
end

apache_module "php5"

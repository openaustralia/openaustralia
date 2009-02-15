# TODO: Requires Apache, Apache configuration, SSL setup
require_recipe 'apache'
 
# Because of an interesting naming difference between the port and the package as a workaround installing from the port
package "phpmyadmin" do
  source "ports"
end

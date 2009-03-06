require_recipe 'php'
# TODO: Requires installation of perl first

package "mysql51-server"

service "mysql-server" do
  supports :status => true, :restart => true
  action [:enable, :start]
end

# Installing language bindings for mysql from ports so that it doesn't require mysql 5.0
package "php5-mysql" do
  source "ports"
end
package "p5-DBD-mysql" do
  source "ports"
end


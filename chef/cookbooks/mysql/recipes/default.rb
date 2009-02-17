require_recipe 'php'
# TODO: Requires installation of perl first

package "mysql-server" do
  source "ports:mysql50-server"
end

service "mysql-server" do
  supports :status => true, :restart => true
  action [:enable, :start]
end

# Language bindings for mysql
package "php5-mysql" do
  source "ports"
end
package "p5-DBD-mysql50" do
  source "ports"
end


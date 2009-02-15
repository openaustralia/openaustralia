require_recipe 'php'
# TODO: Requires installation of perl first

package "mysql-server" do
  source "mysql50-server"
end

service "mysql-server" do
  supports :status => true, :restart => true
  action [:enable, :start]
end

# Language bindings for mysql
package "php5-mysql"
package "p5-DBD-mysql50"


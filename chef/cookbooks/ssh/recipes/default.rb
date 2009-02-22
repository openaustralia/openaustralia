service "sshd" do
  supports :status => true, :reload => true
end

template "/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  notifies :restart, resources("service[sshd]")
end


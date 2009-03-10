package "postfix"

template "/usr/local/etc/postfix/main.cf" do
  source "main.cf.erb"
end

#service "postfix" do
#  supports :status => true, :restart => true
#  action [:enable, :start]
#end
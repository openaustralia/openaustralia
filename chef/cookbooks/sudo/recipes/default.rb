#
# Cookbook Name:: sudo
# Recipe:: default
#

package "sudo"

template "/usr/local/etc/sudoers" do
  source "sudoers.erb"
  mode 0440
  owner "root"
  group "wheel"
  variables(
    :sudoers_users => node[:authorization][:sudo][:users]
  )
end

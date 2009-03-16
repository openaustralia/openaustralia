package "py-setuptools" do
  source "ports"
end

unless File.exists?("/usr/local/bin/gitosis-serve")
  execute "git clone git://eagain.net/gitosis.git" do
    cwd "/tmp"
  end
  execute "python setup.py install" do
    cwd "/tmp/gitosis"
  end
  execute "rm -rf /tmp/gitosis"
end

# 'user' resource isn't working under FreeBSD yet, so in the meantime add the user by hand

#user "git" do
#  shell "/bin/sh"
#  comment "gitosis server"
#  home "/home/git"
#end

=begin
$ sudo adduser -w no
Username: git
Full name: gitosis server
Uid (Leave empty for default): 
Login group [git]: 
Login group is git. Invite gitosis into other groups? []: 
Login class [default]: 
Shell (sh csh tcsh git-shell nologin) [sh]: 
Home directory [/home/git]: 
Use password-based authentication? [no]: 
Lock out the account after creation? [no]: 
Username   : git
Password   : <disabled>
Full Name  : gitosis server
Uid        : 1002
Class      : 
Groups     : git 
Home       : /home/git
Shell      : /bin/sh
Locked     : no
OK? (yes/no): yes
adduser: INFO: Successfully added (git) to the user database.
Add another user? (yes/no): no
Goodbye!
=end

# Initialise the gitosis setup
execute "echo '#{node[:gitosis_admin_public_ssh_key]}' | gitosis-init" do
  environment "HOME" => "/home/git"
  user "git"
  creates "/home/git/gitosis"
end


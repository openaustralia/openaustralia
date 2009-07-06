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
#  comment "git version control"
#  home node[:gitosis_home]
#end

=begin
$ sudo adduser -w no
Username: git
Full name: git version control
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
  environment "HOME" => node[:gitosis_home]
  user "git"
  creates node[:git_root]
end

# Fix up problem caused by old version of python-setup (make it executable)
file "#{node[:git_root]}/gitosis-admin.git/hooks/post-update" do
  mode 0755
end

# Can now create repositories by doing the following on your local machine:
# git clone git@test.org:gitosis-admin.git
# Add something like the following to gitosis.conf:
#   [group openaustralia]
#   writable = openaustralia openaustralia-parser perllib phplib rblib shlib twfy 
#   members = matthewl
# Which will allow writing to the repositories in 'writable' by the people mentioned in 'members'
# Then commit the changes and push them out


require_recipe "git"

# Add some options to /etc/rc.conf for the git-daemon
# TODO: Need to restart the daemon anytime we change these options
remote_file_line "/etc/rc.conf" do
  line "git_daemon_directory=\"#{node[:git_root]}\""
end

remote_file_line "/etc/rc.conf" do
  line "git_daemon_flags=\"--syslog --base-path=#{node[:git_root]}\""
end

remote_file_line "/etc/rc.conf" do
  line "git_daemon_user=\"git\""
end

service "git_daemon" do
  supports :status => true
  action [:enable, :start]
end

# To enable a repository to be exported by git_daemon must touch a file called git-daemon-export-ok in the
# root directory of the repository.
# For instance: touch /home/git/repositories/openaustralia.git/git-daemon-export-ok
# Note: this is easily done by using gitosis. Just put daemon=yes in the [repo <repo name>] section.
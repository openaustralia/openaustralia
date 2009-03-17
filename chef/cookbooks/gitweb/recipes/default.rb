require_recipe "apache"

unless File.exists?("#{node[:gitweb_root]}/gitweb.cgi")
  # This is a HACK
  workdir_prefix = "/tmp"
  workdir = "#{workdir_prefix}/usr/ports/devel/git/work/git-1.6.0.6"
  
  execute "make configure" do
    cwd "/usr/ports/devel/git"
    creates workdir
    # Specifically setting WRKDIRPREFIX as a temporary workaround for bug in run_command which
    # is not passing on environment from parent
    environment "WRKDIRPREFIX" => workdir_prefix
  end

  execute "gmake gitweb/gitweb.cgi" do
    cwd "#{workdir}"
    creates "#{workdir}/gitweb/gitweb.cgi"
  end

  # Fix path on the cgi script. On the server perl is only available in /usr/local/bin
  execute "sed 's$/usr/bin/perl$/usr/local/bin/perl$' gitweb.cgi > gitweb.cgi.fixed.path" do
    cwd "#{workdir}/gitweb"
    creates "#{workdir}/gitweb/gitweb.cgi.fixed.path"
  end
  
  execute "mv gitweb.cgi.fixed.path gitweb.cgi" do
    cwd "#{workdir}/gitweb"
  end
  
  directory node[:gitweb_root] do
    owner "www"
    group "www"
  end
  
  execute "cp git-favicon.png git-logo.png gitweb.cgi gitweb.css #{node[:gitweb_root]}" do
    cwd "#{workdir}/gitweb"
    creates "#{node[:gitweb_root]}/gitweb.cgi"
  end
  
  # The cgi script needs to be executable
  file "#{node[:gitweb_root]}/gitweb.cgi" do
    mode 0755
  end
  
  execute "make clean" do
    cwd "/usr/ports/devel/git"
    environment "WRKDIRPREFIX" => workdir_prefix
  end
  
end

# The configuration file for gitweb
template "#{node[:gitweb_root]}/gitweb_config.perl" do
  source "gitweb_config.perl.erb"
  mode 0644
end

apache_module "cgi"

template "#{node[:apache][:dir]}/sites-available/git" do
  source "apache.conf.erb"
  owner "root"
  mode 0644
end

apache_site "git"

# Also need to ensure that the apache server has read access to the repository
# pw group mod git -m www
# TODO: Replace this with group resource or the like

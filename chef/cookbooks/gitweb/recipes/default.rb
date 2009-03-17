require_recipe "apache"

unless File.exists?("#{node[:gitweb_root]}/gitweb.cgi")
  execute "make configure" do
    cwd "/usr/ports/devel/git"
    creates "/usr/ports/devel/git/work"
  end

  execute "gmake gitweb/gitweb.cgi" do
    cwd '/usr/ports/devel/git/work/git-1.6.1.3'
    creates "/usr/ports/devel/git/work/git-1.6.1.3/gitweb/gitweb.cgi"
  end

  directory node[:gitweb_root]

  execute "cp git-favicon.png git-logo.png gitweb.cgi gitweb.css #{node[:gitweb_root]}" do
    cwd "/usr/ports/devel/git/work/git-1.6.1.3/gitweb"
    creates "#{node[:gitweb_root]}/gitweb.cgi"
  end

  execute "make clean" do
    cwd "/usr/ports/devel/git"
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

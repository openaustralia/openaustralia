#
# Cookbook Name:: jira
# Recipe:: default
#
# Copyright 2008, OpsCode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Manual Steps!
#
# MySQL:
#
#   create database jiradb character set utf8;
#   grant all privileges on $jira_database_name.* to '$jira_user'@'localhost' identified by '$jira_password';
#   flush privileges;

include_recipe "java"
include_recipe "apache"

directory "/www/jira.openaustralia.org" do
  owner "www"
  group "www"
end

unless File.exists?(node[:jira_install_path])
  remote_file "jira" do
    path "/tmp/jira.tar.gz"
    source "http://downloads.atlassian.com/software/jira/downloads/atlassian-jira-#{node[:jira_version]}-standalone.tar.gz"
  end
  
  execute "untar-jira" do
    command "(cd /tmp; tar zxvf /tmp/jira.tar.gz)"
  end
  
  execute "install-jira" do
    command "mv /tmp/atlassian-jira-#{node[:jira_version]}-standalone #{node[:jira_install_path]}"
  end
end

unless File.exists?("#{node[:jira_install_path]}/common/lib/mysql-connector-java-5.1.7-bin.jar")
  remote_file "mysql-connector" do
    path "/tmp/mysql-connector.tar.gz"
    source "http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.7.tar.gz/from/http://mysql.mirrors.ilisys.com.au/"
  end

  execute "untar-mysql-connector" do
    command "(cd /tmp; tar zxvf /tmp/mysql-connector.tar.gz)"
  end

  execute "install-mysql-connector" do
    command "cp /tmp/mysql-connector-java-5.1.7/mysql-connector-java-5.1.7-bin.jar #{node[:jira_install_path]}/common/lib"
  end
end

directory "/www/jira.openaustralia.org/jira" do
  owner "www"
  group "www"
end

directory "/www/jira.openaustralia.org/jira/logs" do
  owner "www"
  group "www"
end

template "#{node[:jira_install_path]}/conf/server.xml" do
  source "server.xml.erb"
  owner "root"
  mode 0755
end
  
template "#{node[:jira_install_path]}/atlassian-jira/WEB-INF/classes/entityengine.xml" do
  source "entityengine.xml.erb"
  owner "root"
  mode 0755
end

apache_module "proxy"
apache_module "proxy_http"

template "#{node[:apache][:dir]}/sites-available/jira.openaustralia.org" do
  source "apache.conf.erb"
  owner "root"
  mode 0644
end

apache_site "jira.openaustralia.org"

#runit_service "jira"

template "/usr/local/etc/rc.d/jira" do
  source "jira.erb"
  mode 0555
end

service "jira" do
  supports :start => true, :stop => true, :status => true
  action [:enable, :start]
end



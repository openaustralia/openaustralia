jira_virtual_host_name "tickets.openaustralia.org" unless attribute?("jira_virtual_host_name")
# type-version-standalone
jira_version "enterprise-3.13.2" unless attribute?("jira_version")
jira_install_path "/www/#{jira_virtual_host_name}" unless attribute?("jira_install_path")
jira_database "mysql" unless attribute?("jira_database")
jira_database_name "jiradb" unless attribute?("jira_database_name")
jira_database_host "localhost" unless attribute?("jira_database_host")
jira_database_user "jira" unless attribute?("jira_database_user")
jira_database_password "jira" unless attribute?("jira_database_password")
jira_run_user "www" unless attribute?("jira_run_user")
# Common bits of configuration 
openaustralia_email_contact "contact@openaustralia.org" unless attribute?("openaustralia_email_contact")
openaustralia_domain "test-openaustralia.org" unless attribute?("openaustralia_domain")
openaustralia_database_name_prefix "openaustralia" unless attribute?("openaustralia_database_name_prefix")
openaustralia_database_user_prefix "oa" unless attribute?("openaustralia_database_user_prefix")

# Configuration for www.openaustralia.org
openaustralia_production_database_name "#{openaustralia_database_name_prefix}_production" unless attribute?("openaustralia_production_database_name")
openaustralia_production_database_user "#{openaustralia_database_user_prefix}_production" unless attribute?("openaustralia_production_database_user")
openaustralia_production_database_password "oa_production" unless attribute?("openaustralia_production_database_password")
openaustralia_production_virtual_host_name "www.#{openaustralia_domain}" unless attribute?("openaustralia_production_virtual_host_name")
openaustralia_production_install_path "/www/www.openaustralia.org/openaustralia" unless attribute?("openaustralia_production_install_path")
openaustralia_production_html_root "/www/www.openaustralia.org/html" unless attribute?("openaustralia_production_html_root")

# Configuration for test.openaustralia.org
openaustralia_test_database_name "#{openaustralia_database_name_prefix}_test" unless attribute?("openaustralia_test_database_name")
openaustralia_test_database_user "#{openaustralia_database_user_prefix}_test" unless attribute?("openaustralia_test_database_user")
openaustralia_test_database_password "oa_test" unless attribute?("openaustralia_test_database_password")
openaustralia_test_virtual_host_name "test.#{openaustralia_domain}" unless attribute?("openaustralia_test_virtual_host_name")
openaustralia_test_install_path "/www/test.openaustralia.org/openaustralia" unless attribute?("openaustralia_test_install_path")
openaustralia_test_html_root "/www/test.openaustralia.org/html" unless attribute?("openaustralia_test_html_root")

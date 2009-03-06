# Common bits of configuration 
openaustralia_email_contact "contact@openaustralia.org" unless attribute?("openaustralia_email_contact")
openaustralia_database_name_prefix "openaustralia" unless attribute?("openaustralia_database_name_prefix")
openaustralia_database_user_prefix "oa" unless attribute?("openaustralia_database_user_prefix")
openaustralia Mash.new unless attribute?("openaustralia")

[:production, :test].each do |stage|
  openaustralia[stage] = Mash.new unless openaustralia.has_key?(stage)
  openaustralia[stage][:database] = Mash.new unless openaustralia[stage].has_key?(:database)
end

openaustralia[:production][:subdomain] = "www" unless openaustralia[:production].has_key?(:subdomain)
openaustralia[:test][:subdomain] = "test" unless openaustralia[:test].has_key?(:subdomain)
openaustralia[:production][:database][:password] = "oa_production" unless openaustralia[:production][:database].has_key?(:password)
openaustralia[:test][:database][:password] = "oa_test" unless openaustralia[:test][:database].has_key?(:password)
openaustralia[:production][:dev_site] = "false" unless openaustralia[:production].has_key?(:dev_site)
openaustralia[:test][:dev_site] = "true" unless openaustralia[:test].has_key?(:dev_site)
openaustralia[:production][:pingmymap_api_key] = "0123456789abcdef0123456789abcdef" unless openaustralia[:production].has_key?(:pingmymap_api_key)
openaustralia[:test][:pingmymap_api_key] = "" unless openaustralia[:test].has_key?(:pingmymap_api_key)

# Making the configuration for the test and production site very similar. We could override this later if so desired
[:production, :test].each do |stage|
  openaustralia[stage][:virtual_host_name] = "#{openaustralia[stage][:subdomain]}.#{oa_domain}" unless openaustralia[stage].has_key?(:virtual_host_name)
  openaustralia[stage][:database][:name] = "#{openaustralia_database_name_prefix}_#{stage}" unless openaustralia[stage][:database].has_key?(:name)
  openaustralia[stage][:database][:user] = "#{openaustralia_database_user_prefix}_#{stage}" unless openaustralia[stage][:database].has_key?(:user)
  openaustralia[stage][:install_path] = "/www/#{openaustralia[stage][:subdomain]}/openaustralia" unless openaustralia[stage].has_key?(:install_path)
  openaustralia[stage][:html_root] = "/www/#{openaustralia[stage][:subdomain]}/html" unless openaustralia[stage].has_key?(:html_root)
end

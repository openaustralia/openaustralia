# Capistrano 2.x recipe file
#
# Requirement cap 2.2
#
# Execute with:
# cap -S stage=<production|test> task

require 'tempfile'
# SHA and OpenSSL required for encryption/decryption
require 'digest/sha2'
require 'openssl'
# Required for processing JSON input to Chef
require 'json'

set :application, "openaustralia.org"

# default_run_options[:pty] = true

set :use_sudo, false

set :scm, :git
set :repository, "git://github.com/openaustralia/openaustralia.git"
set :git_enable_submodules, true
set :deploy_via, :remote_cache

set :stage, "test" unless exists? :stage

role :web, "kedumba.openaustraliafoundation.org.au"
set :user, "deploy"

# A great little trick I learned recently. If you have a machine running on a non-standard ssh port
# put the following in your ~/.ssh/config file:
# Host myserver.com
#   Port 1234
# This will change the port for all ssh commands on that server which saves a whole lot of typing

if stage == "production"
  set :deploy_to, "/srv/www/www.#{application}"
elsif stage == "test"
  set :deploy_to, "/srv/www/test.#{application}"
  set :branch, "test"
end

load 'deploy' if respond_to?(:namespace) # cap2 differentiator

# Symmetric encryption using AES and arbitrary length alpha key
module SymmetricCrypto
  def SymmetricCrypto.decrypt(data, key)
    aes = OpenSSL::Cipher::Cipher.new("AES-256-ECB")
    aes.decrypt
    # This ensures we get the correct length key out of an arbitrary password
    aes.key = Digest::SHA256.digest(key)
    aes.update(data) + aes.final  
  end
  
  def SymmetricCrypto.encrypt(data, key)
    aes = OpenSSL::Cipher::Cipher.new("AES-256-ECB")
    aes.encrypt
    # This ensures we get the correct length key out of an arbitrary password
    aes.key = Digest::SHA256.digest(key)
    aes.update(data) + aes.final      
  end
  
  # Little convenience methods
  def SymmetricCrypto.encrypt_file(file_in, file_out, key)
    File.open(file_out, "w") do |f|
      f << SymmetricCrypto.encrypt(File.read(file_in), key)
    end
  end
  
  def SymmetricCrypto.decrypt_file(file_in, file_out, key)
    File.open(file_out, "w") do |f|
      f << SymmetricCrypto.decrypt(File.read(file_in), key)
    end
  end
end

set :chef_private_password_file, File.expand_path("~/.chef_private_data_password")
set :chef_public, "openaustralia-chef/config/dna.json.public"
set :chef_private, "openaustralia-chef/config/dna.json.private"
set :chef_private_encrypted, "openaustralia-chef/config/dna.json.private.encrypted"
set :chef_public_and_private, "openaustralia-chef/config/dna.json"

if File.exists?(fetch(:chef_private_password_file))
  password = File.read(fetch(:chef_private_password_file))
else
  password = Capistrano::CLI.password_prompt("Type in your password for decrypting secret chef data: ")
  File.open(fetch(:chef_private_password_file), "w") {|f| f << password }
end
set(:chef_encryption_password) { password.strip }

# Takes two hashes and merges them - but has special handling for where the keys are the same. It will
# merge the values using the same method
def merge_values(h1, h2)
  out = {}
  (h1.keys + h2.keys).uniq.each do |key|
    # If the key is present in both hashes
    if h1.key?(key) && h2.key?(key)
      out[key] = merge_values(h1[key], h2[key])
    elsif h1.key?(key)
      out[key] = h1[key]
    else
      out[key] = h2[key]
    end
  end
  out
end

namespace :chef do
  # Using Chef (http://wiki.opscode.com/display/chef/Home) configure the server to
  # have all the software we need. WORK IN PROGRESS
  desc "Update the server configuration using Chef"
  task :default do
    private_data
    combine_public_and_private_data
    upload_recipes
    run_chef
  end
  
  task :upload_recipes do
    run "rm -rf /tmp/chef; mkdir -p /tmp/chef"
    # Ensures that openaustralia-chef/.git isn't transferred needlessly
    upload("openaustralia-chef/config", "/tmp/chef/config", :via => :scp, :recursive => true)
    upload("openaustralia-chef/cookbooks", "/tmp/chef/cookbooks", :via => :scp, :recursive => true)
  end
  
  task :run_chef do
    # Using "sudo -E" to ensure that environment variables are propogated to new environment
    # so that pkg_add knows to use passive ftp. What a PITA.
    #run "chef-solo -l debug -c /tmp/chef/config/solo.rb -j /tmp/chef/config/dna.json"
    sudo "-E chef-solo -c /tmp/chef/config/solo.rb -j /tmp/chef/config/dna.json"
  end
  
  task :combine_public_and_private_data do
    pub = JSON.parse(File.read(fetch(:chef_public)))
    pri = JSON.parse(File.read(fetch(:chef_private)))
    # Need to merge the public and private data so that where the same keys exist in both, the values get merged as well
    File.open(fetch(:chef_public_and_private), "w") do |f|
      f << JSON.generate(merge_values(pub, pri))
    end
  end

  desc "Decrypt/Encrypt the private chef data"
  task :private_data do
    unless File.exists?(fetch(:chef_private))
      SymmetricCrypto.decrypt_file(fetch(:chef_private_encrypted), fetch(:chef_private), fetch(:chef_encryption_password))      
    end
    # Always encrypt the file
    SymmetricCrypto.encrypt_file(fetch(:chef_private), fetch(:chef_private_encrypted), fetch(:chef_encryption_password))
  end
end

namespace :deploy do
	# Restart Apache because for some reason a deploy can cause trouble very occasionally (which is fixed by a restart). So, playing safe
	task :restart do
	#  sudo "apache2ctl restart"
	end

	task :finalize_update do
		run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
	end

	desc "After a code update, we link the images directories to the shared ones"
	task :after_update_code do
		links = {
			"#{release_path}/searchdb"                                => "../../shared/searchdb",

			"#{release_path}/openaustralia-parser/configuration.yml"  => "../../../shared/parser_configuration.yml",

			"#{release_path}/twfy/conf/general"                       => "../../../../shared/general",
			"#{release_path}/twfy/scripts/alerts-lastsent"            => "../../../../shared/alerts-lastsent",

			"#{release_path}/twfy/www/docs/sitemap.xml"               => "../../../../../shared/sitemap.xml",
			"#{release_path}/twfy/www/docs/sitemaps"                  => "../../../../../shared/sitemaps",

		  "#{release_path}/twfy/www/docs/images/mps"                => "../../../../../../shared/images/mps",
			"#{release_path}/twfy/www/docs/images/mpsL"               => "../../../../../../shared/images/mpsL",
			"#{release_path}/twfy/www/docs/regmem/scan"               => "../../../../../../shared/regmem_scan",
			"#{release_path}/twfy/www/docs/rss/mp"                    => "../../../../../../shared/rss/mp",
			"#{release_path}/twfy/www/docs/debates/debates.rss"       => "../../../../../../shared/rss/senate.rss",
			"#{release_path}/twfy/www/docs/senate/senate.rss"       => "../../../../../../shared/rss/senate.rss"
		}
		# First copy any images that have been checked into the repository to the shared area
		run "cp #{release_path}/twfy/www/docs/images/mps/* #{shared_path}/images/mps"
		run "cp #{release_path}/twfy/www/docs/images/mpsL/* #{shared_path}/images/mpsL"
		# HACK: Remove directories next because they have files in them
		run "rm -rf #{release_path}/twfy/www/docs/images/mps #{release_path}/twfy/www/docs/images/mpsL #{release_path}/twfy/www/docs/rss/mp"
		# "ln -sf <a> <b>" creates a symbolic link but deletes <b> if it already exists
		run links.map {|a| "ln -sf #{a.last} #{a.first}"}.join(";")
		# Now compile twfy/scripts/run-with-lockfile.c
		run "gcc -o #{release_path}/twfy/scripts/run-with-lockfile #{release_path}/twfy/scripts/run-with-lockfile.c"
	end
end

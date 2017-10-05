# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "ubuntu/trusty64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # If true, then any SSH connections made will enable agent forwarding.
  # Default value: false
  # config.ssh.forward_agent = true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Don't boot with headless mode
  #   vb.gui = true
  #
  #   # Use VBoxManage to customize the VM. For example to change memory:
  #   vb.customize ["modifyvm", :id, "--memory", "1024"]
  # end
  #
  # View the documentation for the provider you're using for more
  # information on available options.

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "site.yml"

    # Doing this here so we don't need to put in the playbook
    ansible.sudo = true

    # Uncomment the following line if you want some verbose output from ansible
    #ansible.verbose = "vv"

    # Don't try to setup DNS stuff when running things through vagrant
    # because chances are we're just doing things with development VMs anyway
    ansible.skip_tags = "dns"

    ansible.groups = {
      "righttoknow"      => ["righttoknow.org.au.dev"],
      "planningalerts"   => ["planningalerts.org.au.dev"],
      "electionleaflets" => ["electionleaflets.org.au.dev"],
      "theyvoteforyou"   => ["theyvoteforyou.org.au.dev"],
      "oaf"              => ["oaf.org.au.dev"],
      "openaustralia"    => ["openaustralia.org.au.dev"],
      "morph"            => ["morph.io.dev"]
    }
  end

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    # Uncomment this and crank up the memory for a faster build
    # v.cpus = 2
  end

  hosts = {
    "righttoknow.org.au.dev"      => "192.168.10.10",
    "planningalerts.org.au.dev"   => "192.168.10.11",
    "electionleaflets.org.au.dev" => "192.168.10.12",
    "theyvoteforyou.org.au.dev"   => "192.168.10.14",
    "oaf.org.au.dev"              => "192.168.10.15",
    "openaustralia.org.au.dev"    => "192.168.10.16",
    "morph.io.dev"                => "192.168.10.17"
  }

  hosts.each do |hostname, ip|
    config.vm.define hostname do |host|
      host.vm.network :private_network, ip: ip
      host.vm.hostname = hostname
    end
  end
end

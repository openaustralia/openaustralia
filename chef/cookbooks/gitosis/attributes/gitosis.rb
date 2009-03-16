# The publish ssh key (on their local machine) of the admin for gitosis
# Can be found by doing 'cat ~/.ssh/id_rsa.pub'
gitosis_admin_public_ssh_key "" unless attribute?("gitosis_admin_public_ssh_key")

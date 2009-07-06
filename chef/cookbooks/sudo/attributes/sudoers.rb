# We are going to put our users and groups in the 'authorization' namespace
authorization Mash.new unless attribute?("authorization")

# With the 'sudo' key
authorization[:sudo] = Mash.new unless authorization.has_key?(:sudo)

# And set up an Array of users
unless authorization[:sudo].has_key?(:users)
  authorization[:sudo][:users] = Array.new
end

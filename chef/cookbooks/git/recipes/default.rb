# For capistrano deploy we need at least version 1.5.5 of git
# So, slightly hacky. Going to force install from ports (which we're assuming has been updated)
package "git" do
  source "ports"
end


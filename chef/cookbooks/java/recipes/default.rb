package "javavmwrapper"

# Installation of java needs to be actually be done by hand because a license agreement needs to be agreed
# Go to http://www.freebsdfoundation.org/downloads/java.shtml and download diablo-jdk-freebsd7.i386.1.6.0.07.02.tbz
# and install it with "pkg_add diablo-jdk-freebsd7.i386.1.6.0.07.02.tbz"
package "diablo-jdk16"

# Seems to be missing from the packages. WTF?
package "apache-ant" do
  source "ports"
end


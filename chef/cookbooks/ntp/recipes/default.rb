# Setup clock synchronisation. This isn't necessary on a VPS because this is done for us.
# This is mainly needed for testing on a virtual machine where we want an accurate clock too
remote_file "/etc/ntp.conf" do
  source "ntp.conf"
end

service "ntpd" do
  supports :status => true
  action [:enable, :start]
end


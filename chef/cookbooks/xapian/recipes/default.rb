require_recipe 'php'
# TODO: Need to make sure that perl has already been installed

# Xapian bindings for php (as well as other languages)
package "xapian-bindings"

# Xapian bindings for Perl
package "p5-Search-Xapian"

directory "/usr/local/etc/php"

# Make sure the line is added to the file (if it's not there already)
remote_file_line "/usr/local/etc/php/extensions.ini" do
  line "extension=xapian.so"
end

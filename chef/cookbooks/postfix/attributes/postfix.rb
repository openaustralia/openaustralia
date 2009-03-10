postfix Mash.new unless attribute?("postfix")
postfix[:myhostname] = "www.#{oa_domain}" unless postfix.has_key?(:myhostname)
postfix[:mydomain] = oa_domain unless postfix.has_key?(:mydomain)

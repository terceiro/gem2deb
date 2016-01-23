require 'install_as_gem'
require 'install_as_gem/install_as_gem_native'
puts $LOADED_FEATURES.select { |f| f =~ /install_as_gem/ }

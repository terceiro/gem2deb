# source this script from your shell to override the gem2deb installed
# system-wide with the one from the source tree.

gem2deb_root=$(dirname "$BASH_SOURCE")
export PATH="${gem2deb_root}/bin:${PATH}"
export RUBYLIB="${gem2deb_root}/lib"
export PERL5LIB=${gem2deb_root}/debhelper

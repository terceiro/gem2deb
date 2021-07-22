#!/bin/sh
gem2deb_root=$(readlink -f $BASH_SOURCE | xargs dirname | xargs dirname)
export PATH="${gem2deb_root}/bin:${PATH}"
export PERL5LIB="${gem2deb_root}/debhelper"
export RUBYLIB="${gem2deb_root}/lib"
PS1="\033[31;40;01m** gem2deb debug **\033[m $PS1"

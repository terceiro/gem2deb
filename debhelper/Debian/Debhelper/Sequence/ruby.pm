#! /usr/bin/perl
# debhelper sequence file for ruby

use warnings;
use strict;
use Debian::Debhelper::Dh_Lib;

insert_after( "dh_shlibdeps", "dh_ruby_fixdepends" );

insert_after( "dh_installdocs", "dh_ruby_fixdocs" );

add_command_options( "dh_compress", "-X.rb" );

1

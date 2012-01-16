# A debhelper build system class for building Ruby projects.
#
# Copyright: © 2011 Vincent Fourmond
# License: GPL-2+
# Based on the ruby.pm build system

package Debian::Debhelper::Buildsystem::rubysetuprb;

use strict;
use base 'Debian::Debhelper::Buildsystem';

sub DESCRIPTION {
	"Ruby (Gem2Deb+setup.rb)"
}

sub check_auto_buildable {
	my $this=shift;
	return 0;		# Never autobuildable
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

sub configure {
	my $this=shift;
	$this->doit_in_sourcedir("dh_ruby", "--setuprb", "--configure", @_);
}

sub build {
	my $this=shift;
	$this->doit_in_sourcedir("dh_ruby", "--setuprb", "--build", @_);
}

sub test {
	my $this=shift;
	$this->doit_in_sourcedir("dh_ruby", "--setuprb", "--test", @_);
}

sub install {
	my $this=shift;
	$this->doit_in_sourcedir("dh_ruby", "--setuprb", "--install", @_);
}

sub clean {
	my $this=shift;
	$this->doit_in_sourcedir("dh_ruby", "--setuprb", "--clean", @_);
}

1

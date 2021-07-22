# A debhelper build system class for building Ruby projects.
#
# Copyright: © 2011 Lucas Nussbaum
# License: GPL-2+
# Strongly based on other build systems. Thanks!

package Debian::Debhelper::Buildsystem::ruby;

use strict;
use base 'Debian::Debhelper::Buildsystem';

sub DESCRIPTION {
    "Ruby (Gem2Deb)";
}

sub check_auto_buildable {
    my $this = shift;
    my $metadata_yaml = -e $this->get_sourcepath("metadata.yml");
    my $gemspec = scalar(glob("*.gemspec"));
    return ( $metadata_yaml || $gemspec ) ? 1 : 0;
}

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    $this->enforce_in_source_building();
    return $this;
}

sub configure {
    my $this = shift;
    $this->doit_in_sourcedir( "dh_ruby", "--configure", @_ );
}

sub build {
    my $this = shift;
    $this->doit_in_sourcedir( "dh_ruby", "--build", @_ );
}

sub test {
    my $this = shift;
    $this->doit_in_sourcedir( "dh_ruby", "--test", @_ );
}

sub install {
    my $this = shift;
    $this->doit_in_sourcedir( "dh_ruby", "--install", @_ );
}

sub clean {
    my $this = shift;
    $this->doit_in_sourcedir( "dh_ruby", "--clean", @_ );
}

1

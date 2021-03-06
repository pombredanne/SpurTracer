# Stats.pm: Per-Object/Interval Statistics Data Access
#
# Copyright (C) 2012 GFZ Deutsches GeoForschungsZentrum Potsdam <lars.lindner@gfz-potsdam.de>
# Copyright (c) 2014 Lars Windolf <lars.windolf@gmx.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# The current simple key schema only allows tracking data for
#
# - per host name
# - per component name
# - per component instance (host+component)
# - per interface name (component1+component2)
# - per interface instance (host1+component1+component2)
#
# These counters are kept for different intervals using one
# Redis ZSET for each interval. 

package Stats;

use warnings;
use strict;
use POSIX;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
	stats_get_default_interval
	stats_get_interval_definitions
);

my @INTERVALS = (
	{ 'name' => 'hour',	'resolution' => 60,	'step' => 60 },
	{ 'name' => 'day',	'resolution' => 24*60,	'step' => 60 },
	{ 'name' => 'week',	'resolution' => 7*144,	'step' => 600 },
	{ 'name' => 'year',	'resolution' => 365,	'step' => 24*60*60 }
);

################################################################################
# Constructor
#
# Initializes the statistics access object for a given interval. All query
# methods will use that interval whose name is passed in $1. If no valid
# name is passed the default (the smallest) interval will be used.
#
# $1	interval name (optional)
################################################################################
sub new {
	my ($type, $intervalName) = @_;
	my $this = { };

	# Try to find interval with given name
	if(defined($intervalName)) {
		foreach my $i (@INTERVALS) {
			if($$i{'name'} eq $intervalName) {
				$this->{'interval'} = $i;
				last;
			}
		}
	}

	unless(defined($this->{'interval'})) {
		# Note: We expect @INTERVALS to be sorted from smallest to largest 
		# interval. The smallest one is considered default.
		$this->{'interval'} = $INTERVALS[0];
	}

	return bless $this, $type;
}

################################################################################
# Simple returns the interval definitions as an array
################################################################################
sub stats_get_interval_definitions {

	return \@INTERVALS;
}

################################################################################
# Simple returns the interval definitions as an array
################################################################################
sub stats_get_default_interval {

	return $INTERVALS[0];
}

################################################################################
# Generic interval counter method. Increases counter by $2 for all configured
# intervals. To be used by _count_object/interface() only.
#
# $2	Value to add
# $3	Key
################################################################################
sub _count_interval {
	my ($this, $add, $key) = @_;

	# Writing to an interval set of resolution m at time slot n
	# is done by incrementing slot n and resetting slot n+1
	# based on server time where
	#
	#	n = time() % m
	#	m = interval resolution + 1
	#
	# The resulting error rate is the sum of all values in
	# the interval array. The array (excluding the n+1) field
	# can be used for a graphical
	foreach my $interval (@INTERVALS) {
		my $n = (time() / $$interval{'step'}) % ($$interval{'resolution'} + 1);

		DB->hsetnx("stats$$interval{name}\!$key", $n, 0);
		DB->hincrby("stats$$interval{name}\!$key", $n, $add);
		DB->hset("stats$$interval{name}\!$key", ($n + 1) % ($$interval{resolution} + 1), 0);
	}
}

################################################################################
# Generic object counter method. Increases counter by $3.
#
# $2	object type ('interface', 'component' or 'host')
# $3	value to add
# $4	object name
# $5	event that is counted ('error', 'started' or 'timeout')
################################################################################
sub _count_object {
	my $this = shift;
	my $add = shift;
	my $key = join("!", @_);

	DB->incrby("stats!object!$key", $add);
	$this->_count_interval($add, "object!$key");
}

################################################################################
# Generic instance counter method. Increases counter by $3.
#
# $2	object type ('interface', 'component')
# $3	value to add
# $4	object name
# $5	event that is counted ('error', 'started' or 'timeout')
################################################################################
sub _count_instance {
	my $this = shift;
	my $add = shift;
	my $key = join("!", @_);

	DB->incrby("stats!instance!$key", $add);
	$this->_count_interval($add, "instance!$key");
}

################################################################################
# Generic started counter method.
#
# $2	Host
# $3	Component
################################################################################
sub add_start_notification {
	my $this = $_[0];

	$this->_count_object(1, 'global', 'started');
	$this->_count_object(1, 'host', $_[1], 'started');
	$this->_count_object(1, 'component', $_[2], 'started');

	$this->_count_instance(1, 'component', $_[1], $_[2], 'started');
}

################################################################################
# Generic error counter method.
#
# $2	Host
# $3	Component
################################################################################
sub add_error_notification {
	my $this = $_[0];

	$this->_count_object(1, 'global', 'failed');
	$this->_count_object(1, 'host', $_[1], 'failed');
	$this->_count_object(1, 'component', $_[2], 'failed');

	$this->_count_instance(1, 'component', $_[1], $_[2], 'failed');
}

################################################################################
# Generic announcement counter method. Additionally counts an interface as 
# 'started' so we have a total number of times the interface was triggered.
#
# $2	Source Host
# $3	Source Component
# $4	Target Component
################################################################################
sub add_interface_announced {
	my $this = $_[0];

	$this->_count_object(1, 'global', 'announced');
	$this->_count_object(1, 'interface', $_[2], $_[3], 'announced');
	$this->_count_object(1, 'interface', $_[2], $_[3], 'started');

	$this->_count_instance(1, 'interface', $_[1], $_[2], $_[3], 'announced');
	$this->_count_instance(1, 'interface', $_[1], $_[2], $_[3], 'started');
}

################################################################################
# Generic announcement counter method.
#
# $2	Source Host
# $3	Source Component
################################################################################
sub add_component_announced {
	my $this = $_[0];

	$this->_count_object(1, 'global', 'announced');
	$this->_count_object(1, 'component', $_[2], 'announced');

	$this->_count_instance(1, 'component', $_[1], $_[2], 'announced');
}

################################################################################
# Generic interface timeout counter method. Increases all relevant counters.
# Additionally decreases the 'announced' counter so we have a live gauge of
# pending interfaces.
#
# To be called only by AlarmMonitor!
#
# $2	Source Host
# $3	Source Component
# $5	Target Component
################################################################################
sub add_interface_timeout {
	my $this = $_[0];

	$this->_count_object(1, 'global', 'timeout');
	$this->_count_object(1, 'host', $_[1], 'timeout');
	$this->_count_object(-1, 'interface', $_[2], $_[3], 'announced');
	$this->_count_object( 1, 'interface', $_[2], $_[3], 'timeout');

	$this->_count_instance(-1, 'interface', $_[1], $_[2], $_[3], 'announced');
	$this->_count_instance( 1, 'interface', $_[1], $_[2], $_[3], 'timeout');
}

################################################################################
# Generic error counter method. Increases the error for all relevant counters.
#
# To be called only by AlarmMonitor!
#
# $2	Host
# $3	Component
################################################################################
sub add_component_timeout {
	my $this = $_[0];

	$this->_count_object(1, 'global', 'timeout');
	$this->_count_object(1, 'host', $_[1], 'timeout');
	$this->_count_object(-1, 'component', $_[2], 'announced');
	$this->_count_object( 1, 'component', $_[2], 'timeout');

	$this->_count_instance(-1, 'component', $_[1], $_[2], 'announced');
	$this->_count_instance( 1, 'component', $_[1], $_[2], 'timeout');
}

################################################################################
# Save component execution duration to performance metrics. Triggered when a
# component finishes processing a context. The duration passed should be
# determined from the corresponding start event.
#
# $2	Host
# $3	Component
# $4	End Time
# $5    Announcement (or undef)
################################################################################
sub add_component_duration {
	my ($this, $host, $component, $end_time, $announcement) = @_;

	if(defined($announcement)) {
		my $duration = ($end_time - $announcement->{'time'});
		$this->_count_object($duration, 'component', $component, 'perf_values');
		$this->_count_object(1,         'component', $component, 'perf_samples');
		$this->_count_instance($duration, 'component', $host, $component, 'perf_values');
		$this->_count_instance(1,         'component', $host, $component, 'perf_samples');
	}

	# Decreases the 'announced' counter so we have a live gauge of pending interfaces
	$this->_count_object(-1, 'component', $component, 'announced');
	$this->_count_instance(-1, 'component', $host, $component, 'announced');
}

################################################################################
# Save interface latency duration to performance metrics. Triggered when an
# interface is responding. The method automatically determines the duration by
# fetching the interface announcement.
#
# $2	Source Host
# $3	Source Component
# $4	Target Component
# $5	Duration
################################################################################
sub add_interface_duration {
	my ($this, $host, $component1, $component2, $duration) = @_;

	$this->_count_object($duration, 'interface', $component1, $component2, 'perf_values');
	$this->_count_object(1,         'interface', $component1, $component2, 'perf_samples');
	$this->_count_instance($duration, 'interface', $host, $component1, $component2, 'perf_values');
	$this->_count_instance(1,         'interface', $host, $component1, $component2, 'perf_samples');

	# Decreases the 'announced' counter so we have a live gauge of pending interfaces
	$this->_count_object(-1, 'interface', $component1, $component2, 'announced');
	$this->_count_instance(-1, 'interface', $host, $component1, $component2, 'announced');
}

################################################################################
# Generic counter getter. Returns all interesting fields per object+type as
# a hash.
#
# $2	object type ('interface', 'component' or 'host')
# $3	object name
#
# Returns hash with properties of the object
################################################################################
sub get_object {
	my $this = shift;
	my %interval = %{$this->{'interval'}};
	my $key_prefix = join("!", @_);
	my %results = ();

	foreach(('failed', 'started', 'timeout', 'announced')) {
		my %tmp = DB->hgetall("stats$interval{name}!object!$key_prefix!$_");
		$results{$_} = 0;
		# Sum up the interval to get sum
		foreach my $value (values(%tmp)) {
			$results{$_} += $value;
		}
		$results{$_} = 0 if($results{$_} < 0);	# can happen for announcements

	}

	# E.g. in object lists it might be important to further
	# resolve object properties so we provide additionally
	# the human readable 'name' and the DB lookup 'key'
	$results{'key'} = "object!$key_prefix";

	return %results;
}

################################################################################
# Get a list of all known object keys of a type
#
# $2	type ('object' or 'instance')
# $3	value type ('global', 'interface', 'component' or 'host')
# $4	counter name (optional, defaults to 'started')
#
# Returns a list of key names
################################################################################
sub get_keys {
	my ($this, $type, $valueType, $counter) = @_;
	my %interval = %{$this->{'interval'}};

	$counter = "started" unless(defined($counter));
	my @keys = DB->keys("stats$interval{name}!$type!$valueType!*!$counter");

	return \@keys;
}

################################################################################
# Get a list of all known objects of a type and their properties as returned
# by stats_get_object()
#
# $2	object type ('global', 'interface', 'component' or 'host')
#
# Returns a list reference with hash describing the objects
################################################################################
sub get_object_list {
	my ($this, $type) = @_;
	my %interval = %{$this->{'interval'}};
	my @results = ();

	foreach(@{$this->get_keys('object', $type)}) {
		next unless(/^stats$interval{name}!object!$type!(.+)!\w+$/);
		my %tmp = $this->get_object($type, $1);

		# provide human readable name
		$tmp{'name'} = $1;
	
		# We must distinguish between interfaces and objects
		# as interface names are <from>!<to> pairs...
		if($type eq "interface") {
			next unless($1 =~ /^([^!]+)!([^!]+)$/);
			$tmp{'from'} = $1;
			$tmp{'to'} = $2;
		}
		
		push(@results, \%tmp);
	}

	return \@results;
}

################################################################################
# Generic counter getter. Returns all interesting fields per instance+type as
# a hash.
#
# $2	instance type ('interface', 'component')
# $3	instance name
#
# Returns hash with properties of the instance
################################################################################
sub get_instance {
	my $this = shift;
	my %interval = %{$this->{'interval'}};
	my $key_prefix = join("!", @_);
	my %results = ();

	foreach(('failed', 'started', 'timeout', 'announced')) {
		my %tmp = DB->hgetall("stats$interval{name}!instance!$key_prefix!$_");
		$results{$_} = 0;
		# Sum up the interval to get sum
		foreach my $value (values(%tmp)) {
			$results{$_} += $value;
		}
		$results{$_} = 0 if($results{$_} < 0);	# can happen for announcements
	}

	return %results;
}

################################################################################
# Get a list of all known objects of a type and their properties as returned
# by get_instance()
#
# $2	object type ('interface', 'component')
#
# Returns a list of get_instance() results augmented by some identifier fields
################################################################################
sub get_instance_list {
	my ($this, $type) = @_;
	my %interval = %{$this->{'interval'}};
	my @results = ();

	foreach(@{$this->get_keys('instance', $type)}) {
		next unless(/^stats$interval{name}!instance!$type!(.+)!\w+$/);
		my %tmp = $this->get_instance($type, $1);

		# Split instance name into it's parts. E.g.
		#
		# 	host0!comp1		for a component instance
		#	host0!comp1!comp2	for an interface instance
		if($1 =~ /^([^!]+)!([^!]+)(!([^!]+))?$/) {
			$tmp{'host'} = $1;
			$tmp{'component'} = $2;
			$tmp{'newcomponent'} = $4 if(defined($4));
			push(@results, \%tmp); 
		}
	}

	return \@results;
}

1;

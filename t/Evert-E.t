use strict;
use Test::More;
use Evert::E;

# Test list of subs
can_ok('Evert::E', 'da');
can_ok('Evert::E', 'do_action');
can_ok('Evert::E', 'do_req_filter');
can_ok('Evert::E', 'do_sync_action');
can_ok('Evert::E', 'do_async_action');
can_ok('Evert::E', 'af');
can_ok('Evert::E', 'apply_filter');
can_ok('Evert::E', 'apply_req_filter');
can_ok('Evert::E', 'apply_cached_filter');
can_ok('Evert::E', 'add_action');
can_ok('Evert::E', 'add_operation');
can_ok('Evert::E', 'add_temp_filter');
can_ok('Evert::E', 'add_alone_filter');
can_ok('Evert::E', 'add_filter');
can_ok('Evert::E', 'remove_action');
can_ok('Evert::E', 'remove_filter');
can_ok('Evert::E', 'did_action');
can_ok('Evert::E', 'has_action');
can_ok('Evert::E', 'has_filter');
can_ok('Evert::E', 'list_all_actions');
can_ok('Evert::E', 'list_handlers');
can_ok('Evert::E', 'get_events');

# Adding action
is(Evert::E::add_action('event_name_1', \&some_action_1), 1,"Adding action");

# Has action
is(Evert::E::has_action("event_name_1"), 1,"Has action");

# Removing action with name
is(Evert::E::remove_action('event_name_1'), 1,"Removing action with event name");
is(Evert::E::has_action("event_name_1"), 0,"Removing action with  event name - success removing");

# Removing unknown action
is(Evert::E::remove_action('unknown_name_1'), 0,"Removing unknown action");

# Bad removing event name
is(Evert::E::remove_action(undef), 0,"Bad removing params");

# Removing action with id
my $num=Evert::E::add_action('event_name_1', \&some_action_1);
is(Evert::E::remove_action('event_name_1', {id=>$num}), 1,"Removing action with id");
is(Evert::E::has_action("event_name_1"), 0,"Removing action with id - success removing");


# Removing action with package name
Evert::E::add_action('event_name_1', \&some_action_1);
is(Evert::E::remove_action('event_name_1',  {package=>'main'}), 1,"Removing action with package name");
is(Evert::E::has_action("event_name_1"), 0,"Removing action with package name - success removing");

# Removing action with handler
Evert::E::add_action('event_name_1', \&some_action_1);
is(Evert::E::remove_action('event_name_1', {handler=>\&some_action_1}), 1,"Removing action with handler");
is(Evert::E::has_action("event_name_1"), 0,"Removing action with handler - success removing");

# Removing filter
my $num=Evert::E::add_action('event_filter_1', \&some_filter_1);
is(Evert::E::remove_action('event_filter_1', {id=>$num}), 1,"Removing filter");
is(Evert::E::has_action("event_name_1"), 0,"Removing handler - success removing");

# Did action
is(Evert::E::did_action("event_name_1"), 0,"Did action");

# Did action 2
Evert::E::add_action('event_name_1', \&some_action_1);
Evert::E::do_action('event_name_1');
Evert::E::do_action('event_name_1');
is(Evert::E::did_action("event_name_1"), 2,"Did action 2");


# List all actions
is(Evert::E::list_all_actions(), "event_name_1\nevent_filter_1\n","List all actions");

# Test event list
test_event();

# Fire action as a filter
is(Evert::E::apply_filter("event_name_1"), 'action_1',"Do action 1");
Evert::E::remove_action('event_name_1');

# Fire filter
Evert::E::add_action('event_filter_1', \&some_filter_1);
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_ok',"Apply filter 1");
Evert::E::remove_action('event_filter_1');

# Test filter chain
Evert::E::add_action('event_filter_1', \&some_filter_1);
Evert::E::add_action('event_filter_1', \&some_filter_2);
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_ok_no',"Test filter chain");
Evert::E::remove_action('event_filter_1');

# Test filter reverse chain
Evert::E::add_action('event_filter_1', \&some_filter_2);
Evert::E::add_action('event_filter_1', \&some_filter_1);
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_no_ok',"Test filter reverse chain");
Evert::E::remove_action('event_filter_1');

# Test priority
Evert::E::add_action('event_filter_1', \&some_filter_1, {priority=>2});
Evert::E::add_action('event_filter_1', \&some_filter_2, {priority=>1});
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_no_ok',"Test filter priority");
Evert::E::remove_action('event_filter_1');

# Add alone filter
Evert::E::add_alone_filter('event_filter_1', \&some_filter_1);
is(Evert::E::add_alone_filter('event_filter_1', \&some_filter_2), 0, "Add alone filter");
Evert::E::remove_action('event_filter_1');

# Add alone filter 2
Evert::E::add_alone_filter('event_filter_1', \&some_filter_1);
Evert::E::add_alone_filter('event_filter_1', \&some_filter_2);
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_ok',"Test alone filter 2");
Evert::E::remove_action('event_filter_1');

# Add alone filter 3
Evert::E::add_alone_filter('event_filter_1', \&some_filter_1);
Evert::E::remove_action('event_filter_1');
Evert::E::add_alone_filter('event_filter_1', \&some_filter_2);
Evert::E::add_alone_filter('event_filter_1', \&some_filter_1);
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_no',"Test alone filter 3");

# Add temp filter
Evert::E::add_temp_filter('event_filter_1', \&some_filter_1);
Evert::E::add_temp_filter('event_filter_1', \&some_filter_2);
is(Evert::E::apply_filter("event_filter_1", 'action_1'), 'action_1_no',"Test temp filter");
Evert::E::remove_action('event_filter_1');

# Apply cached filter
Evert::E::add_filter('event_filter_1', \&some_count_filter);
Evert::E::apply_cached_filter("event_filter_1", 'action_1');
isnt(Evert::E::apply_cached_filter("event_filter_1", 'action_1'), 2,"Apply cached filter");
Evert::E::remove_action('event_filter_1');

# Apply required filter - 1
is(Evert::E::apply_req_filter("event_filter_5", "filter", "default_content"), "default_content" ,"Apply required filter - 1");

# Apply required filter - 2
Evert::E::add_filter('event_filter_1', \&some_filter_2);
is(Evert::E::apply_req_filter("event_filter_1", 'action_1', "default_content"), 'action_1_no',"Apply required filter - 2");
Evert::E::remove_action('event_filter_1');

# Do required filter - 1
is(Evert::E::do_req_filter("event_filter_1", \&some_filter_2, 'action_1'), 'action_1_no',"Do required filter - 1");
Evert::E::remove_action('event_filter_1');

# Do required filter - 2
Evert::E::add_filter('event_filter_1', \&some_filter_2);
is(Evert::E::do_req_filter("event_filter_1", \&some_filter_1, "action_1"), 'action_1_no',"Do required filter - 2");
Evert::E::remove_action('event_filter_1');

# Action params
Evert::E::add_filter('event_filter_1', \&action_param_test);
Evert::E::do_action("event_filter_1", 'event_filter_1', 'main', 158);
Evert::E::remove_action('event_filter_1');

# Export event sub - 1
Evert::E::add_filter('some_sub', \&some_action_1);
eval
{
	Evert::E::some_sub();
};
if ($@)
{
	pass("Export event sub - 1");
}
Evert::E::remove_action('some_sub');

# Export event sub - 2
Evert::E::add_filter('some_sub', \&some_action_1, {need_export=>1});
eval
{
	is(Evert::E::some_sub(), 'action_1',"Export event sub - 2");
};
if ($@)
{
	fail("Export event sub - 2");
}
Evert::E::remove_action('some_sub');


# Test call
Evert::E::add_action('event_name_1', \&test_action);
Evert::E::do_action('event_name_1');
Evert::E::remove_action('event_name_1');


done_testing();



sub some_action_1
{
	return "action_1";
}

sub some_action_2
{
	return "action_2";
}

sub some_filter_1
{
	my $text=$_[1];
	return $text.'_ok';
}

sub some_filter_2
{
	my $text=$_[1];
	return $text.'_no';
}

{
	my $i=0;
	sub some_count_filter
	{
		$i++;
		return $i;
	}
}

sub action_param_test
{
	my $action=$_[0];
	my $name=$_[1];
	my $sub=$_[2];
	my $line=$_[3];
	is($action->{name}, $name, "Action name param");
	is($action->{package}, $sub, "Action package param");
	is($action->{line}, $line, "Action line param");
}


sub test_action
{
	my $action=$_[0];
	is(ref($action), "HASH", "Good hash action");
	is(exists($action->{handler}), 1, "Passed handler");
}



sub test_event
{
	my $name='event_test_events_list';
	Evert::E::add_action($name, \&some_filter_1);
	my $events=Evert::E::get_events();

	my $test_1=0;
	my $test_2=0;
	
	foreach my $prior (sort {$b <=> $a} keys %{$events->{$name}{"handlers"}})
	{
		for my $handle (@{$events->{$name}{"handlers"}{$prior}})
		{
			$test_2++;
			next if (!defined($handle));
			if ($prior==1 && exists($handle->{filename}) && exists($handle->{package}) && exists($handle->{line}))
			{
				$test_1=1;
			}
		}
	}
	
	is($test_1, 1, "Events list");
	is($test_2, 1, "Events list 2");
	Evert::E::remove_action('event_test_events_list');
}


1;
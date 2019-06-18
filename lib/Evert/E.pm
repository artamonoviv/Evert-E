package Evert::E;
use strict;
use warnings;
use Carp ();
use v5.10;

use Exporter qw(import);

our $VERSION = '0.002';
our @EXPORT_OK=qw(apply_filter do_action add_operation af da);

our $AUTOLOAD;

my %EXPORTED; # List of exported functions

our %events; # Global events cache

# Call exported events
sub AUTOLOAD
{
	my $called=$AUTOLOAD=~ s/.*:://r;
	if(exists($EXPORTED{$called}) && has_action($called))
	{
		return apply_filter($called,@_);
	}
	my ($package, $filename, $line) = caller();
	Carp::croak "$called not found in Evert's events => $package, $filename, $line";
}

# Exported synonym of do_action
sub da
{
	return do_action(@_);
}

# Main action sub. Returns the number of called events' callback functions
sub do_action($;@) # event name, params
{
	my $name = $_[0];

	return 0 if (!$name || !exists($events{$name}));

	my $count = 0;

	my ($package, $filename, $line) = caller;

	$events{$name}{"count"}++;

	my @a=@_;

	foreach my $priority (sort {$a <=> $b} keys %{$events{$name}{"handlers"}})
	{
		my @handlers=grep {defined($_)} @{$events{$name}{"handlers"}{$priority}};
		foreach my $handler ( @handlers  )
		{

			my $pid;

			eval
			{

				local $SIG{CHLD} = "IGNORE" if ($handler->{async});

				if (!$handler->{async} || !defined($pid = fork())) # Be carefull of using async # If forking fails
				{
					&{$handler->{sub}}({  name => $name, package=>$package, filename=>$filename, line=>$line, handler=>$handler }, @a[1 .. $#_]);
				}
				else
				{
					if ($pid==0) # if child
					{
						&{$handler->{async_callback}}(&{$handler->{sub}}({ name => $name, package=>$package, filename=>$filename, line=>$line, handler=>$handler }, @a[1 .. $#_]), @a);
						exit;
					}
				}

				$count++;
			};

			no warnings;
			do_action("evert_error", {name=>$name, handler=>$handler, error=>$@}) if ($@ && $name ne "evert_error");
			use warnings;

			if ($handler->{async} && $pid==0) # if child
			{
				exit;
			}
		}
	}

	return $count;
}


#  Try to call mandatory filter. Use 'callback' if it does not exist.
sub do_req_filter($&;@) # event name, callback sub, params
{
	my $name=$_[0];

	my $callback=$_[1] || Carp::croak "Callback for do_req_filter is missing";

	return apply_filter($name, @_[2 .. $#_]) if ($name && has_filter($name));

	return &{$callback}($name, @_[2 .. $#_]);
}


#  Force use action in sync manner
sub do_sync_action($;@) # event name, params
{
	my $name = $_[0];

	return 0 if (!$name || !exists($events{$name}));

	my $count = 0;

	my ($package, $filename, $line) = caller;

	$events{$name}{"count"}++;

	my @a=@_;

	foreach my $priority (sort {$a <=> $b} keys %{$events{$name}{"handlers"}})
	{

		my @handlers=grep {defined($_)} @{$events{$name}{"handlers"}{$priority}};
		foreach my $handler ( @handlers  )
		{

			my $pid;

			eval
			{

				&{$handler->{sub}}({  name => $name, package=>$package, filename=>$filename, line=>$line, handler=>$handler }, @a[1 .. $#_]);

				$count++;
			};

			do_action("evert_error", {name=>$name, handler=>$handler, error=>$@}) if ($@ && $name ne "evert_error");
		}
	}

	return $count;
}

#  Force use action in async manner
#  Be aware: it uses simple fork()
sub do_async_action($;@) # event name, params
{
	my $name = $_[0];

	return 0 if (!$name ||  !exists($events{$name}));

	my $count = 0;

	my ($package, $filename, $line) = caller;

	$events{$name}{"count"}++;

	my @a=@_;

	foreach my $priority (sort {$a <=> $b} keys %{$events{$name}{"handlers"}})
	{

		my @handlers=grep {defined($_)} @{$events{$name}{"handlers"}{$priority}};
		foreach my $handler ( @handlers  )
		{

			my $pid;

			eval
			{

				local $SIG{CHLD} = "IGNORE";

				if (!defined($pid = fork())) # Be carefull in using async # Forking fails
				{
					&{$handler->{sub}}({ name => $name, package=>$package, filename=>$filename, line=>$line, handler=>$handler }, @a[1 .. $#_]);
				}
				else
				{
					if (!$pid) # if child
					{
						&{$handler->{async_callback}}(&{$handler->{sub}}({ name => $name, package=>$package, filename=>$filename, line=>$line, handler=>$handler }, @a[1 .. $#_]), @a);
						exit;
					}
				}

				$count++;
			};

			do_action("evert_error", {name=>$name, handler=>$handler, error=>$@}) if ($@ && $name ne "evert_error");

			if ($pid==0) # if child
			{
				exit;
			}
		}
	}
	return $count;
}


# Exported synonym of apply_filter
sub af
{
	return apply_filter(@_);
}

# Main filter sub. Returns transformed content
sub apply_filter($;@) # event name, content to transform, params
{
	my $name = $_[0];
	my $content = $_[1];
	my $result=0;

	if ($name && exists($events{$name}))
	{

		my ($package, $filename, $line) = caller;

		$events{$name}{"count"}++;

		my @a=@_;

		foreach my $priority (sort {$a <=> $b} keys %{$events{$name}{"handlers"}})
		{
			my @handlers=grep {defined($_)} @{$events{$name}{"handlers"}{$priority}};
			foreach my $handler ( @handlers  )
			{
				eval
				{
					$content = &{$handler->{sub}}({ name => $name, package=>$package, filename=>$filename, line=>$line, handler=>$handler }, $content, @a[2 .. $#_]);
				};
				do_action("evert_error", {name=>$name, handler=>$handler, error=>$@}) if ($@ && $name ne "evert_error");
			}
		}

	}

	return $content;
}

#  Try to call mandatory filter. Return default content if it does not exist.
sub apply_req_filter($;@) #event name, default content, params
{
	my $name=$_[0];
	my $default_content=$_[2] || undef;
	if (has_filter ($name))
	{
		return apply_filter($name, $_[1], @_[3 .. $#_]);
	}
	return $default_content;
}

# Cached filter results to next calling.
{
	my %cache=();
	sub apply_cached_filter($;*) # event name, default content
	{
		my $name = $_[0];

		Carp::croak "Apply_cached_filter need only 2 params." if (defined($_[2]));

		$cache{$name}=apply_filter($name, @_[1 .. $#_]) if (!exists($cache{$name}));

		return $cache{$name};

	}
}

# Adds action (or filter)
sub add_action($&;$) # event name, callback sub, params
{
	return  add_operation($_[0], $_[1], $_[2], [caller]);
}

# Adds filter (or action) that should be removed if another action will emerge
sub add_temp_filter($&;$) # event name, callback sub, params
{
	my $params=$_[2] || {};
	$params->{priority}=1000;
	return add_operation($_[0], $_[1], $params, [caller]);
}

# Adds filter (or action) that have only one handler
# Doesn't remove previously added filters/actions!
sub add_alone_filter($&;$)
{
	my $params=$_[2] || {};
	$params->{priority}=-1000;
	return add_operation($_[0], $_[1], $params, [caller]);
}

# Adds filter (or action)
sub add_filter($&;$)
{
	return add_operation($_[0], $_[1], $_[2], [caller]);
}

sub add_operation
{
	# The higher priority the later handler will be called
	# -1000 priority is reserved for alone filter
	# 1000 priority is reserved for "remove-me-in-case-of-another" filter

	my ($name, $handler, $params, $caller) = @_;

	my ($package, $filename, $line);

	if(defined($caller))
	{
		($package, $filename, $line) = @$caller;
	}
	else
	{
		($package, $filename, $line)=caller
	}

	if (!defined($handler) || ref($handler) ne "CODE")
	{
		$handler = sub {};
	}

	$params = {} if (!defined($params));
	$params->{priority} = 1 if (!exists($params->{priority}) || !length($params->{priority}));
	$params->{priority} = -1000 if (exists($params->{is_alone}) && $params->{is_alone});
	$params->{async} = 0 if (!exists($params->{async}) || !length($params->{async}));
	$params->{async_callback} = sub {} if (!exists($params->{async_callback}));
	$params->{need_export} = 0 if (!exists($params->{need_export}));

	$events{$name}{"count"} = 0 if (!exists($events{$name}));

	my $current = 0;
	return 0 if (1  <= scalar grep{defined($_)} @{$events{$name}{"handlers"}{-1000}});  # alone filter already exists

	delete ($events{$name}{"handlers"}{-1000}); # removes  "remove-me-in-case-of-another" filter

	state $id_handler=0;

	$id_handler++;

	push @{$events{$name}{"handlers"}{$params->{priority}}},{ sub => $handler, line => $line, filename=>$filename, package => $package, id_handler => $id_handler, %$params};

	if($params->{need_export})
	{
		if(!exists($EXPORTED{$name}))
		{
			push @EXPORT_OK, $name;
			$EXPORTED{$name}=1;
		}
	}

	return $id_handler;
}

# Removes action
sub remove_action($;%) # event name, handler, package, event unic id
{
	my $name = $_[0];
	my $args = $_[1] || {};

	return 0 if (!defined($name) || !exists($events{$name}));

	if (!exists($args->{handler}) && !exists($args->{package}) && !exists($args->{id}))
	{
		delete($events{$name});
		return 1;
	}
	else
	{
		foreach my $prior (keys %{$events{$name}{handlers}})
		{
			for my $i (0 .. (scalar @{$events{$name}{handlers}{$prior}} - 1))
			{
				next if (!defined($events{$name}{handlers}{$prior}[$i]));
				if (exists($args->{handler}) && $events{$name}{handlers}{$prior}[$i]->{sub} == $args->{handler})
				{
					$events{$name}{handlers}{$prior}[$i] = undef;
					return 1;
				}
				elsif (exists($args->{package}) && $events{$name}{handlers}{$prior}[$i]->{package} eq $args->{package})
				{
					$events{$name}{handlers}{$prior}[$i] = undef;
					return 1;
				}
				elsif (exists($args->{id}) && $events{$name}{handlers}{$prior}[$i]->{id_handler} == $args->{id})
				{
					$events{$name}{handlers}{$prior}[$i] = undef;
					return 1;
				}
			}
		}
	}
	return 0;
}

# Synonym of previous sub
sub remove_filter($;$$$)
{
	return remove_action(@_);
}

# How many times an action was called
sub did_action($) # event name
{
	return $events{$_[0]}{"count"};
}

# Has Evert this event?
sub has_action($) # event name
{
	my $name=$_[0];
	return 0 if (!exists($events{$name}) || !$events{$name});
	my $count=0;
	foreach my $prior (keys %{$events{$name}{"handlers"}})
	{
		for my $i (0 .. (scalar @{$events{$name}{"handlers"}{$prior}} - 1))
		{
			next if (!defined($events{$name}{"handlers"}{$prior}[$i]));
			$count++;
		}
	}
	return 1 if ($count);
	return 0;
}

# Synonym of previous sub
sub has_filter($)
{
	return exists($events{$_[0]});
}

# Prints list of events
sub list_all_actions()
{
	my $text = "";;
	foreach my $name (sort {$b cmp $a} keys %events)
	{
		$text .= "$name\n";
	}
	return $text;
}

# Prints list of handlers of an event
sub list_handlers($)
{
	my $text = "";
	my $name = shift;
	foreach my $prior (sort {$b <=> $a} keys %{$events{$name}{"handlers"}})
	{
		for my $handle (@{$events{$name}{"handlers"}{$prior}})
		{
			next if (!defined($handle));
			$text .= "$prior|$handle->{filename}|$handle->{package}|$handle->{line}\n";
		}

	}
	return $text;
}

# Returns events list
sub get_events()
{
	return \%events;
}


=pod

=encoding UTF-8

=head1 NAME

Evert::E - a heart of the lightweight platform for building loosely-coupled event-driven applications.

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use Evert::E;

    Evert::E::add_action('name_of_event_1', \&action_func_1); # add event listener 1
    Evert::E::add_action('name_of_event_1', \&action_func_2); # add event listener 2

    Evert::E::do_action('name_of_event_1'); # fire event

    Evert::E::add_filter('name_of_event_2', \&action_func_1); # add event listener 1
    Evert::E::add_filter('name_of_event_2', \&action_func_2); # add event listener 2

    my $content = 'some data';
    $content = Evert::E::apply_filter('name_of_event_2', $content); # fire event

    Evert::E::add_action('name_of_event_3', \&action_func_1, {async=>1, async_callback=>\&callback_func_1}); # add event listener that should be executed asynchronously.

    Evert::E::add_action('name_of_event_3', \&action_func_1, {priority=>2}); # add event listener with priority 2

    Evert::E::remove_action('name_of_event_3'); # remove all event handlers

=head1 DESCRIPTION

The main idea of Evert::E was inspired by WordPress "Hooks" mechanism, also known as "Filters" and "Actions".

An action is a function that is intended to process an event. There is a 'many-to-many' relationship between actions and events.
An event can be handled by a set of actions. Each action can be freely added or removed from handling of a particular event at any time.
An event can be fired multiple times. Each firing executes all actions associated with the Event.

An action returns nothing. If it returns some important result then it becomes a filter.
A filter is an action that returns a result. Filters can be put together to chain for complex input processing when the first filter output becomes the second filter input and so on.

The second and the last difference between actions and filters lies in asynchronicity. You can execute actions on the asynchronous manner, while filters cannot.

Nevertheless, actions and filters are stored inside Evert::E in the same place. So you can call an action as a filter (by mistake probably) or call a filter as an action (to discard result).

=head1 METHODS

=head2 Basic

=head3 add_action ($name, $handler, $params)

Adds new event handler. Returns unique handler id.

Note that 'add_action' is just a syntax sugar to the 'add_operation' method.

    Evert::E::add_action('name_of_event', \&action_func_1);

    sub action_func_1
    {
        # do something
    }

    # or

    Evert::E::add_action('name_of_event', sub {print 'Say something'});

The third argument is a hashref of params. Params may be:

=over 3

=item async

Shows that a handler should be executed asynchronously. Default is 0.

    Evert::E::add_action('name_of_event', \&action_func_1, {async=>1});

Note that Evert::E uses simple fork() function to spawn threads. And there are cases when asynchronous operations cannot be applied.

=item async_callback

Points to a callback that should process a handler result. Requires async = 1.

    Evert::E::add_action('name_of_event', \&action_func_1, {async=>1, async_callback=>\&callback_func_1});

=item priority

In case of event handlers are called in order of adding (FIFO). You can change the order with priorities. The handler with bigger priority will be called after the lesser.

    Evert::E::add_action('name_of_event', \&action_func_1, {priority=>2});
    Evert::E::add_action('name_of_event', \&action_func_2, {priority=>1});
    Evert::E::do_action('name_of_event'); # action_func_1 will be the last.

Default priority is 1.
Note that there are two reserved priorities:
-1000 priority is reserved for a "i-must-be-alone" filter.
1000 priority is reserved for a "remove-me-in-case-of-another" filter.
See add_temp_filter and add_alone_filter sections for details.

=item need_export

A handler with "need_export" flag automatically turns its event to a method of Evert::E. Default is 0, of course.

    Evert::E::add_action('name_of_event', \&action_func_1, {need_export=>1});

    my $data = Evert::E::name_of_event('content'); # "name_of_event" is now synonym of apply_filter('name_of_event',@_) method.

=back

=head3 add_filter ($name, $handler, $params)

A synonym of 'add_action' method. And also is a syntax sugar to the 'add_operation' method.

    Evert::E::add_filter('name_of_event', \&action_func_1); # action_func_1 must return only one value

Note: event handler must return only one value to proper work of filter chaining.

Returns unique filter id.

=head3 do_action ($name)

Signalize to Evert::E about event firing. Evert::E calls all related handlers in order of priority.

Has an only param - name of the event.

If a handler has 'async' flag it is executed in a new thread. Note that Evert::E uses simple fork() function to spawn threads.

Returns the number of called handlers.

=head3 apply_filter ($name, $content, $data1, $data2,...)

Make Evert::E call all event handlers as a chain to process 'input'. Returns 'output'.

    Evert::E::add_filter('name_of_event', \&action_func_1);

    my $data = 'some_information';

    $data = Evert::E::apply_filter('name_of_event', $data);

    print $data; # will print 'some_informaion_ok'

    sub action_func_1
    {
        return $_[0].'_ok';
    }

Note: a chain of filters can change only with the first argument. The next arguments remain unchanged but still are passed to every handler.

    my $data = 'some_information';
    $data = Evert::E::apply_filter('name_of_event', $data); # OK

    my $data = 'some_information';
    my $data2 = 'some_information_2';
    $data = Evert::E::apply_filter('name_of_event', $data, $data2, 'foo', 'bar'); # OK if you keep in mind that only $data will change while passing through a filter chain. $data2 and next params remain unchanged but still are passed to every handler.

Each filter must return only one value. It can be a scalar, a hashref or an arrayref, but not an array.
You must keep equal structure types between 'input' and 'output'.

    my ($data1, $data2) = Evert::E::apply_filter('name_of_event', $data); # Wrong!

    my ($data1, $data2) = @{Evert::E::apply_filter('name_of_event', $data)}; # Doubtful if $data is not an arrayref

    my %data = %{Evert::E::apply_filter('name_of_event', $data)}; # Doubtful if $data is not a hashref

    my ($data1, $data2) = @{Evert::E::apply_filter('name_of_event', [])}; # Perfect

    my @data=('foo', 'bar');
    my ($data1, $data2) = @{Evert::E::apply_filter('name_of_event', \@data)}; # Perfect
    my $data = Evert::E::apply_filter('name_of_event', \@data); # Perfect

    my $hashref = Evert::E::apply_filter('name_of_event', {}); # Perfect

    my %hash = %{Evert::E::apply_filter('name_of_event', [])}; # Wrong: input is an empty arrayref, output is a hashref

    my $hashref={foo=>'1', bar=>'2'};
    my %hash = %{Evert::E::apply_filter('name_of_event', $hashref)}; # Perfect

If an unknown event is called Evert::E returns the first argument.

    my $data = 'some_information';
    $data = Evert::E::apply_filter('unknown_event', $data);
    print $data; # will print 'some_information'

Please keep it in mind while creating filters:

    my $article = Foo::Bar->new(173); # Create new article with id=173;

    print Evert::E::apply_filter('give_me_article_url', $article); # Wrong! If a 'give_me_article_url' filter was not found, $article object is printed

    print Evert::E::apply_filter('give_me_article_url', '', $article); # Perfect

    print Evert::E::apply_filter('give_me_article_url', '/404', $article); # Perfect

=head3 remove_action ($name, $params)

Removes handlers from event. Returns 1 if success, 0 otherwise.

    Evert::E::add_filter('name_of_event', \&action_func_1);

    my $data = 'some_information';

    $data = Evert::E::apply_filter('name_of_event', $data);

    Evert::E::remove_action('name_of_event'); # Removes all event handlers

    my $handler_id=Evert::E::add_action('name_of_action_1', \&callback_func_1, {priority=>2}); # add event listener with priority 2

    Evert::E::remove_action('name_of_action_1', {id=>$handler_id}); # remove event handler with particular id

    Evert::E::remove_action('name_of_action_1', {package=>'Foo::Bar'}); # remove event handler that was added by Foo::Bar

    Evert::E::remove_action('name_of_action_1', {handler=>\&callback_func_1}); # remove particular event handler

The second argument is a hashref of mutually exclusive params. Params may be:

=over 3

=item id

Removes handler with a specific id.

=item package

Removes handler that was added by 'package'.

=item handler

Points to sub that should be removed from the event handlers list.

=back

Note that 'id', 'package', 'handler' are mutually exclusive. You can pass only one of them.

=head2 Advanced

=head3 da ($name)

A short synonym of 'do_action' method. Exported.

    use Evert::E qw(da); # import method names

    da('name_of_event');

=head3 af ($name, $content, $data1, $data2,...)

A short synonym of 'apply_filter' method. Exported.

=head3 do_async_action ($name)

Try to call asynchronously an action which handlers were created without 'async=>1' flag.

Returns the number of called handlers.

=head3 do_sync_action ($name)

Force synchronous execution of an action. Need to ignore 'async=>1' flag.

Returns the number of called handlers.

=head3 do_req_filter ($name, $callback_sub, $content, $param1, $param2, ...)

Tries to call a filter that must be already added. Pass params to a 'callback' sub if a target filter does not exist.

=head3 apply_req_filter ($name, $default_content, $content, $param1, $param2, ...)

Returns $default_content if event with $name does not exist. Note that $default_content is the second param.

=head3 apply_cached_filter ($name, $default_content)

Caches filters chain result (or $default_content) after first calling. Use it only for very useful and idempotent events.

    print apply_cached_filter('give_site_basic_url', 'http://foo.bar'); # First call requires full filters chain work
    print apply_cached_filter('give_site_basic_url', 'http://foo.bar'); # The next call uses Evert::E cache

Note: there is no special method to purge this cache in runtime.

=head3 add_operation ($name, $handler, $params, $caller)

Adds handler (filter or action) to an event. $caller must be an arrayref of caller() function output. Exported.

'add_operation' is used by 'add_action', 'add_filter', 'add_temp_filter', 'add_alone_filter' methods.

=head3 add_temp_filter ($name, $handler, $params)

Adds handler that must be removed if another handler of this event will appear. Call 'add_operation' method with priority = 1000.

Returns unique handler id.

=head3 add_alone_filter ($name, $handler, $params)

Adds handler that must be alone. It's impossible to add the second handler if the first is not yet removed.  Call 'add_operation' method with priority = -1000.

The 'remove_action' method disables this restriction.

    Evert::E::add_alone_filter('name_of_event', \&action_func_1); # Returns handler id
    Evert::E::add_filter('name_of_event', \&action_func_2); # Returns 0

    Evert::E::add_alone_filter('name_of_event', \&action_func_1); # Returns handler id
    Evert::E::remove_action('name_of_event'); # Disable restrictions
    Evert::E::add_alone_filter('name_of_event', \&action_func_2); # Returns handler id
    Evert::E::add_alone_filter('name_of_event', \&action_func_3); # Returns handler id

You can lock a handlers set with it:

    Evert::E::add_filter('name_of_event', \&action_func_1); # Returns handler id
    Evert::E::add_filter('name_of_event', \&action_func_2); # Returns handler id
    my $handler_id = Evert::E::add_alone_filter('name_of_event', \&action_func_3); # Returns handler id and lock the filter set
    Evert::E::add_filter('name_of_event', \&action_func_4); # Returns 0. The filter set is locked
    Evert::E::remove_action('name_of_event', {id = > handler_id}); # Removes handler with $handler_id and therefore unlock filter set.

A filter set remains locked while at least one handler with priority = -1000 is in it.

Returns unique handler id.

=head3 remove_filter ($name, $params)

A synonym of 'remove_action' method.

=head2 Miscellaneous

=head3 did_action ($name)

How many times an event was fired?

=head3 has_action ($name)

Has an action handlers?

=head3 has_filter ($name)

A synonym of 'has_action'

=head3 list_handlers ($name)

Returns a list of event's handlers.

Format of a string: priority|filename|package|line\n

=head3 list_all_actions()

Returns a list of all registered events.

Format of a string: name\n

Note that listed events may have not handlers.

=head3 get_events()

Returns inner events hashref.

=head2 Mechanism of handler calling

To every event handler Evert::E passes at least one argument: a hashref of event firing information. The rest existent parameters are passed too.

     Evert::E::add_filter('name_of_event_1', \&action_func_1);
     Evert::E::add_filter('name_of_event_2', \&action_func_2);

     my $data1 = Evert::E::apply_filter('name_of_event_1'); # $data1 become undef, but action_func_1 prints 'name_of_event_1'

     $data1 = Evert::E::apply_filter('name_of_event_1', 'foobar'); # $data1 still undef because of action_func_1 returns undef

     $data1 = Evert::E::apply_filter('name_of_event_2', 'foobar'); # $data1 become 'foobar_ok' and action_func_2 prints 'name_of_event_2'

     sub action_func_1
     {
         my $action=shift;
         print $action->{name};
         return undef;
     }

     sub action_func_2
     {
         my ($action, $content)=@_;
         print $action->{name};
         return $content.'_ok';
     }

     sub action_func_3
     {
         my ($action, $content)=@_;
         print $action->{name};
         return $content;
     }

The $action hashref has folowing keys:

=over 3

=item name

A name of the event

=item package

What package fires the event?

=item filename

What file fires the event?

=item line

What line of file fires the event?

=item handler

What handler is processing the event?

=back

=head2 Export methods names

Evert::E on request can export 'apply_filter', 'do_action', 'add_operation', 'af', 'da' method names.

    use Evert::E qw(add_operation apply_filter); # import method names

    add_operation('name_of_event', \&action_func_1); # add event handler

    apply_filter('name_of_event', 'content'); # fire event

This ability is necessary if you need to replace Evert::E by more advanced modules (for example for message bus support in microservice systems), but you still need the functionality of other Evert-depending packages.

So if you have a plan to scale your system up, it's a good practice to use exported names. Then you can replace Evert::E by another module only in one place of the code.

=head1 AUTHOR

Ivan Artamonov, <ivan.s.artamonov {at} gmail.com>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut

1;
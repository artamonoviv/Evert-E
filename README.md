# NAME

Evert::E - a heart of the lightweight platform for building loosely-coupled event-driven applications.

# VERSION

version 0.001

# SYNOPSIS

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

# DESCRIPTION

The main idea of Evert::E was inspired by WordPress "Hooks" mechanism, also known as "Filters" and "Actions".

An action is a function that is intended to process an event. There is a 'many-to-many' relationship between actions and events.
An event can be handled by a set of actions. Each action can be freely added or removed from handling of a particular event at any time.
An event can be fired multiple times. Each firing executes all actions associated with the Event.

An action returns nothing. If it returns some important result then it becomes a filter.
A filter is an action that returns a result. Filters can be put together to chain for complex input processing when the first filter output becomes the second filter input and so on.

The second and the last difference between actions and filters lies in asynchronicity. You can execute actions on the asynchronous manner, while filters cannot.

Nevertheless, actions and filters are stored inside Evert::E in the same place. So you can call an action as a filter (by mistake probably) or call a filter as an action (to discard result).

# METHODS

## Basic

### add\_action ($name, $handler, $params)

Adds new event handler. Returns unique handler id.

Note that 'add\_action' is just a syntax sugar to the 'add\_operation' method.

    Evert::E::add_action('name_of_event', \&action_func_1);

    sub action_func_1
    {
        # do something
    }

    # or

    Evert::E::add_action('name_of_event', sub {print 'Say something'});

The third argument is a hashref of params. Params may be:

- async

    Shows that a handler should be executed asynchronously. Default is 0.

        Evert::E::add_action('name_of_event', \&action_func_1, {async=>1});

    Note that Evert::E uses simple fork() function to spawn threads. And there are cases when asynchronous operations cannot be applied.

- async\_callback

    Points to a callback that should process a handler result. Requires async = 1.

        Evert::E::add_action('name_of_event', \&action_func_1, {async=>1, async_callback=>\&callback_func_1});

- priority

    In case of event handlers are called in order of adding (FIFO). You can change the order with priorities. The handler with bigger priority will be called after the lesser.

        Evert::E::add_action('name_of_event', \&action_func_1, {priority=>2});
        Evert::E::add_action('name_of_event', \&action_func_2, {priority=>1});
        Evert::E::do_action('name_of_event'); # action_func_1 will be the last.

    Default priority is 1.
    Note that there are two reserved priorities:
    \-1000 priority is reserved for a "i-must-be-alone" filter.
    1000 priority is reserved for a "remove-me-in-case-of-another" filter.
    See add\_temp\_filter and add\_alone\_filter sections for details.

- need\_export

    A handler with "need\_export" flag automatically turns its event to a method of Evert::E. Default is 0, of course.

        Evert::E::add_action('name_of_event', \&action_func_1, {need_export=>1});

        my $data = Evert::E::name_of_event('content'); # "name_of_event" is now synonym of apply_filter('name_of_event',@_) method.

### add\_filter ($name, $handler, $params)

A synonym of 'add\_action' method. And also is a syntax sugar to the 'add\_operation' method.

    Evert::E::add_filter('name_of_event', \&action_func_1); # action_func_1 must return only one value

Note: event handler must return only one value to proper work of filter chaining.

Returns unique filter id.

### do\_action ($name)

Signalize to Evert::E about event firing. Evert::E calls all related handlers in order of priority.

Has an only param - name of the event.

If a handler has 'async' flag it is executed in a new thread. Note that Evert::E uses simple fork() function to spawn threads.

Returns the number of called handlers.

### apply\_filter ($name, $content, $data1, $data2,...)

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

### remove\_action ($name, $params)

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

- id

    Removes handler with a specific id.

- package

    Removes handler that was added by 'package'.

- handler

    Points to sub that should be removed from the event handlers list.

Note that 'id', 'package', 'handler' are mutually exclusive. You can pass only one of them.

## Advanced

### da ($name)

A short synonym of 'do\_action' method. Exported.

    use Evert::E qw(da); # import method names

    da('name_of_event');

### af ($name, $content, $data1, $data2,...)

A short synonym of 'apply\_filter' method. Exported.

### do\_async\_action ($name)

Try to call asynchronously an action which handlers were created without 'async=>1' flag.

Returns the number of called handlers.

### do\_sync\_action ($name)

Force synchronous execution of an action. Need to ignore 'async=>1' flag.

Returns the number of called handlers.

### do\_req\_filter ($name, $callback\_sub, $content, $param1, $param2, ...)

Tries to call a filter that must be already added. Pass params to a 'callback' sub if a target filter does not exist.

### apply\_req\_filter ($name, $default\_content, $content, $param1, $param2, ...)

Returns $default\_content if event with $name does not exist. Note that $default\_content is the second param.

### apply\_cached\_filter ($name, $default\_content)

Caches filters chain result (or $default\_content) after first calling. Use it only for very useful and idempotent events.

    print apply_cached_filter('give_site_basic_url', 'http://foo.bar'); # First call requires full filters chain work
    print apply_cached_filter('give_site_basic_url', 'http://foo.bar'); # The next call uses Evert::E cache

Note: there is no special method to purge this cache in runtime.

### add\_operation ($name, $handler, $params, $caller)

Adds handler (filter or action) to an event. $caller must be an arrayref of caller() function output. Exported.

'add\_operation' is used by 'add\_action', 'add\_filter', 'add\_temp\_filter', 'add\_alone\_filter' methods.

### add\_temp\_filter ($name, $handler, $params)

Adds handler that must be removed if another handler of this event will appear. Call 'add\_operation' method with priority = 1000.

Returns unique handler id.

### add\_alone\_filter ($name, $handler, $params)

Adds handler that must be alone. It's impossible to add the second handler if the first is not yet removed.  Call 'add\_operation' method with priority = -1000.

The 'remove\_action' method disables this restriction.

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

### remove\_filter ($name, $params)

A synonym of 'remove\_action' method.

## Miscellaneous

### did\_action ($name)

How many times an event was fired?

### has\_action ($name)

Has an action handlers?

### has\_filter ($name)

A synonym of 'has\_action'

### list\_handlers ($name)

Returns a list of event's handlers.

Format of a string: priority|filename|package|line\\n

### list\_all\_actions()

Returns a list of all registered events.

Format of a string: name\\n

Note that listed events may have not handlers.

### get\_events()

Returns inner events hashref.

## Mechanism of handler calling

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

- name

    A name of the event

- package

    What package fires the event?

- filename

    What file fires the event?

- line

    What line of file fires the event?

- handler

    What handler is processing the event?

## Export methods names

Evert::E on request can export 'apply\_filter', 'do\_action', 'add\_operation', 'af', 'da' method names.

    use Evert::E qw(add_operation apply_filter); # import method names

    add_operation('name_of_event', \&action_func_1); # add event handler

    apply_filter('name_of_event', 'content'); # fire event

This ability is necessary if you need to replace Evert::E by more advanced modules (for example for message bus support in microservice systems), but you still need the functionality of other Evert-depending packages.

So if you have a plan to scale your system up, it's a good practice to use exported names. Then you can replace Evert::E by another module only in one place of the code.

# AUTHOR

Ivan Artamonov, &lt;ivan.s.artamonov {at} gmail.com>

# LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

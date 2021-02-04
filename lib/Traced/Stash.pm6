use v6;
use Traced;
#|[ Stash tracing module. ]
unit module Traced::Stash;

#|[ A type of stash trace. ]
enum Type <LOOKUP BIND ASSIGN>;

#|[ A traced stash event template. ]
role Event does Traced {
    #|[ The stash in question. ]
    has Stash:D $.stash is required;
    #|[ The stash key in question. ]
    has Str:D   $.key   is required;

    #|[ The name of the kind of traced event. ]
    method kind(::?CLASS:D: --> 'STASH') { }

    #|[ The full name of the stash member. ]
    method longname(::?CLASS:D: --> Str:D) {
        $!key.substr(0, 1) eq <$ @ % &>.any
          ?? $!key.substr(1, 1) eq <* . ! ^ : ? = ~>.any
            ?? "$!key.substr(0, 2)$!stash.gist()\:\:$!key.substr(2)"
            !! "$!key.substr(0, 1)$!stash.gist()\:\:$!key.substr(1)"
          !! "$!stash.gist()\:\:$!key"
    }
}

#|[ A traced stash lookup. ]
role Event[LOOKUP] does Event {
    #|[ The type of traced stash event. ]
    method of(::?CLASS:D: --> LOOKUP) { }

    #|[ Whether or not the stash has a new value. ]
    method modified(::?CLASS:D: --> False) { }

    multi method capture(::?CLASS:U:
        Stash:D :$stash, Str:D :$key
    --> Mu) is raw is hidden-from-backtrace {
        $stash.Stash::AT-KEY: $key
    }
}

#|[ A traced stash binding. ]
role Event[BIND] does Event {
    #|[ The new value for the stash key. ]
    has Mu $.value is built(:bind) is rw;

    #|[ The type of traced stash event. ]
    method of(::?CLASS:D: --> BIND) { }

    #|[ Whether or not the stash has a new value. ]
    method modified(::?CLASS:D: --> True) { }

    multi method capture(::?CLASS:U:
        Stash:D :$stash, Str:D :$key, Mu :$value is raw
    --> Mu) is raw is hidden-from-backtrace {
        $stash.Hash::BIND-KEY: $key, $value
    }
}

#|[ A traced stash assignment. ]
role Event[ASSIGN] does Event {
    #|[ The new value for the stash key. ]
    has Mu $.value is built(:bind) is rw;

    #|[ The type of traced stash event. ]
    method of(::?CLASS:D: --> ASSIGN) { }

    #|[ Whether or not the stash has a new value. ]
    method modified(::?CLASS:D: --> True) { }

    multi method capture(::?CLASS:U:
        Stash:D :$stash, Str:D :$key, Mu :$value is raw
    --> Mu) is raw is hidden-from-backtrace {
        $stash.Hash::ASSIGN-KEY: $key, $value
    }
}

my role Wrap { ... }

multi sub TRACING(Event:U, Stash:D $stash --> Nil) is export(:TRACING) {
    $stash does Wrap
}

#|[ Traces stash events. ]
my role Wrap {
    multi method AT-KEY(::?CLASS:D $stash:
        Str() $key
    --> Mu) is raw is hidden-from-backtrace {
        my constant LookupEvent = Event[LOOKUP].^pun;
        $*TRACER.render: LookupEvent.capture: :$stash, :$key
    }

    multi method BIND-KEY(::?CLASS:D $stash:
        Str() $key, Mu $value is raw
    --> Mu) is raw is hidden-from-backtrace {
        my constant BindEvent = Event[BIND].^pun;
        $*TRACER.render: BindEvent.capture: :$stash, :$key, :$value;
    }

    multi method ASSIGN-KEY(::?CLASS:D $stash:
        Str() $key, Mu $value is raw
    --> Mu) is raw is hidden-from-backtrace {
        my constant AssignEvent = Event[ASSIGN].^pun;
        $*TRACER.render: AssignEvent.capture: :$stash, :$key, :$value;
    }
}

use v6;
use Traced;
unit module Traced::Stash;

enum Type <LOOKUP BIND ASSIGN>;

role Event does Traced {
    has Stash:D $.stash is required;
    has Str:D   $.key   is required;

    method kind(::?CLASS:D: --> 'STASH') { }

    method longname(::?CLASS:D: --> Str:D) {
        $!key.substr(0, 1) eq <$ @ % &>.any
          ?? $!key.substr(1, 1) eq <* . ! ^ : ? = ~>.any
            ?? "$!key.substr(0, 2)$!stash.gist()\:\:$!key.substr(2)"
            !! "$!key.substr(0, 1)$!stash.gist()\:\:$!key.substr(1)"
          !! "$!stash.gist()\:\:$!key"
    }
}

role Event[LOOKUP] does Event {
    method of(::?CLASS:D: --> LOOKUP) { }

    method modified(::?CLASS:D: --> False) { }

    multi method event(::?CLASS:U: Stash:D :$stash, Str:D :$key --> Mu) is raw {
        $stash.Stash::AT-KEY: $key
    }
}

role Event[BIND] does Event {
    has Mu $.value is built(:bind) is rw;

    method of(::?CLASS:D: --> BIND) { }

    method modified(::?CLASS:D: --> True) { }

    multi method event(::?CLASS:U: Stash:D :$stash, Str:D :$key, Mu :$value is raw --> Mu) is raw {
        $stash.Hash::BIND-KEY: $key, $value
    }
}

role Event[ASSIGN] does Event {
    has Mu $.value is built(:bind) is rw;

    method of(::?CLASS:D: --> ASSIGN) { }

    method modified(::?CLASS:D: --> True) { }

    multi method event(::?CLASS:U: Stash:D :$stash, Str:D :$key, Mu :$value is raw --> Mu) is raw {
        $stash.Hash::ASSIGN-KEY: $key, $value
    }
}

my role Wrap { ... }

multi sub TRACING(Event:U, Stash:D $stash --> Nil) is export(:TRACING) {
    $stash does Wrap
}

my role Wrap {
    multi method AT-KEY(::?CLASS:D $stash: Str() $key --> Mu) is raw {
        my constant LookupEvent = Event[LOOKUP].^pun;
        $*TRACER.render: LookupEvent.event: :$stash, :$key
    }

    multi method BIND-KEY(::?CLASS:D $stash: Str() $key, Mu $value is raw --> Mu) is raw {
        my constant BindEvent = Event[BIND].^pun;
        $*TRACER.render: BindEvent.event: :$stash, :$key, :$value;
    }

    multi method ASSIGN-KEY(::?CLASS:D $stash: Str() $key, Mu $value is raw --> Mu) is raw {
        my constant AssignEvent = Event[ASSIGN].^pun;
        $*TRACER.render: AssignEvent.event: :$stash, :$key, :$value;
    }
}

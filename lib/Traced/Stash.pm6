use v6;
use Traced;
unit class Traced::Stash does Traced;

enum Type <LOOKUP BIND ASSIGN>;

has Stash:D $.stash is required;
has Str:D   $.key   is required;

method kind(::?CLASS:D: --> 'STASH') { }

method of(::?CLASS:D: --> Type:D) { ... }

method longname(::?CLASS:D: --> Str:D) {
    $!key.substr(0, 1) eq <$ @ % &>.any
      ?? $!key.substr(1, 1) eq <* . ! ^ : ? = ~>.any
        ?? "$!key.substr(0, 2)$!stash.gist()\:\:$!key.substr(2)"
        !! "$!key.substr(0, 1)$!stash.gist()\:\:$!key.substr(1)"
      !! "$!stash.gist()\:\:$!key"
}

my role Mixin { ... }

method wrap(::?CLASS:U: Stash:D $stash is raw --> Mu) { $stash.^mixin: Mixin }

my role Impl { ... }

method ^parameterize(::?CLASS:U $this is raw, ::Type:D $type is raw --> ::?CLASS:U) {
    my ::?CLASS:U $mixin := self.mixin: $this, Impl.^parameterize: $type;
    $mixin.^set_name: self.name($this) ~ qq/[$type]/;
    $mixin
}

my role Mixin {
    my \TracedStashLookup = CHECK Traced::Stash.^parameterize: LOOKUP;
    multi method AT-KEY(::?CLASS:D: Str() $key --> Mu) is raw {
        $*TRACER.render: TracedStashLookup.event:
            :stash(self), :$key
    }

    my \TracedStashBind = CHECK Traced::Stash.^parameterize: BIND;
    multi method BIND-KEY(::?CLASS:D: Str() $key, Mu $value is raw --> Mu) is raw {
        $*TRACER.render: TracedStashBind.event: :stash(self), :$key, :$value;
    }

    my \TracedStashAssign = CHECK Traced::Stash.^parameterize: ASSIGN;
    multi method ASSIGN-KEY(::?CLASS:D: Str() $key, Mu $value is raw --> Mu) is raw {
        $*TRACER.render: TracedStashAssign.event: :stash(self), :$key, :$value;
    }
}

my role Impl[LOOKUP] {
    method of(::?CLASS:D: --> LOOKUP) { }

    method modified(::?CLASS:D: --> False) { }

    multi method event(::?CLASS:U: Stash:D :$stash, Str:D :$key --> Mu) is raw {
        $stash.Stash::AT-KEY: $key
    }
}

my role Impl[BIND] {
    has Mu $.value is built(:bind) is rw;

    method of(::?CLASS:D: --> BIND) { }

    method modified(::?CLASS:D: --> True) { }

    multi method event(::?CLASS:U: Stash:D :$stash, Str:D :$key, Mu :$value is raw --> Mu) is raw {
        $stash.Hash::BIND-KEY: $key, $value
    }
}

my role Impl[ASSIGN] {
    has Mu $.value is built(:bind) is rw;

    method of(::?CLASS:D: --> ASSIGN) { }

    method modified(::?CLASS:D: --> True) { }

    multi method event(::?CLASS:U: Stash:D :$stash, Str:D :$key, Mu :$value is raw --> Mu) is raw {
        $stash.Hash::ASSIGN-KEY: $key, $value
    }
}

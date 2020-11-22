use v6.d;
use Traced;
unit class Traced::Stash does Traced;

enum Access <Lookup Assign Bind>;

has Access:D $.access    is required;
has Stash:D  $.stash     is required;
has Str:D    $.key       is required;
has Bool:D   $.modified  is required;
has Mu       $.old-value is built(:bind);
has Mu       $.new-value is built(:bind);

proto method new(::?CLASS:_: | --> ::?CLASS:D) {*}
multi method new(::?CLASS:_: Access::Lookup $access;; Stash:D $stash, Str:D $key, *%rest --> ::?CLASS:D) {
    self.bless: :$access, :$stash, :$key, :!modified, |%rest
}
multi method new(::?CLASS:_:
    Access:D $access;; Stash:D $stash, Str:D $key, Mu $old-value is raw, Mu $new-value is raw, *%rest
--> ::?CLASS:D) {
    self.bless: :$access, :$stash, :$key, :modified, :$old-value, :$new-value, |%rest
}

method colour(::?CLASS:D: --> 32)        { }
method category(::?CLASS:D: --> 'STASH') { }
method type(::?CLASS:D: --> Str:D)       { $!access.key.uc }

method what(::?CLASS:D: --> Str:D) {
    my Int:D $idx = $!key.substr(0, 1) eq <$ @ % &>.any
                 ?? $!key.substr(1, 1) eq <* . ! ^ : ? = ~>.any
                    ?? 2
                    !! 1
                 !! 0;
    $idx > 0
        ?? sprintf('%s%s::%s', $!key.substr(0, $idx), $!stash.gist, $!key.substr($idx))
        !! sprintf('%s::%s', $!stash.gist, $!key)
}

method entries(::?CLASS:D: --> Iterable:D) {
    gather if $!modified {
        take 'old' => $!old-value;
        take 'new' => $!new-value;
    }
}

my role Mixin {
    multi method AT-KEY(::?CLASS:D: Str() $key --> Mu) is raw {
        Traced::Stash.trace: Access::Lookup, self, $key
    }

    multi method BIND-KEY(::?CLASS:D: Str() $key, Mu $new-value is raw --> Mu) is raw {
        my Mu $old-value := self.Map::AT-KEY: $key;
        Traced::Stash.trace: Access::Bind, self, $key, $old-value, $new-value;
    }

    multi method ASSIGN-KEY(::?CLASS:D: Str() $key, Mu $new-value is raw --> Mu) is raw {
        my Mu $old-value = self.Map::AT-KEY: $key; # Intentionally uses $old-value's container.
        Traced::Stash.trace: Access::Assign, self, $key, $old-value, $new-value;
    }
}

method wrap(::?CLASS:U: Stash:D $stash is raw --> Mu) { $stash.^mixin: Mixin }

multi method trace(::?CLASS:U: Access::Lookup;; Stash:D $stash, Str:D $key --> Mu) is raw {
    $stash.Stash::AT-KEY: $key
}
multi method trace(::?CLASS:U:
    Access::Bind;; Stash:D $stash, Str:D $key, Mu $old-value is raw, Mu $new-value is raw
--> Mu) is raw {
    $stash.Hash::BIND-KEY: $key, $new-value
}
multi method trace(::?CLASS:U:
    Access::Assign;; Stash:D $stash, Str:D $key, Mu $old-value is raw, Mu $new-value is raw
--> Mu) is raw {
    $stash.Hash::ASSIGN-KEY: $key, $new-value
}

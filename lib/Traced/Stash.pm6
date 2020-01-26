use v6.d;
use Traced;
unit class Traced::Stash is Traced;

my enum Access <Lookup Assign Bind>;

has Access:D $.access    is required;
has Str:D    $.name      is required;
has Str:D    $.lookup    is required;
has Bool:D   $.modified  is required;
has Mu       $.old-value = Nil;
has Mu       $.new-value = Nil;

method new(::?CLASS:_: Access:D $access, Stash:D $stash, Str:D $lookup, *%rest --> ::?CLASS:D) {
    my Str:D  $name     = $stash.gist;
    my Bool:D $modified = %rest{<old-value new-value>}:exists.all.so;
    self.bless: :$access, :$name, :$lookup, :$modified, |%rest
}

method colour(::?CLASS:D: --> 32)        { }
method category(::?CLASS:D: --> 'STASH') { }
method type(::?CLASS:D: --> Str:D)       { $!access.key.uc }

multi method what(::?CLASS:D: --> Str:D) {
    my Int:D $idx = $!lookup.substr(0, 1) eq <$ @ % &>.any
                 ?? $!lookup.substr(1, 1) eq <* . ! ^ : ? = ~>.any
                    ?? 2
                    !! 1
                 !! 0;
    $idx > 0
        ?? sprintf('%s%s::%s', $!lookup.substr(0, $idx), $!name, $!lookup.substr($idx))
        !! sprintf('%s::%s', $!name, $!lookup)
}

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather if $!modified {
        take 'old' => $!old-value;
        take 'new' => $!new-value;
    }
}

my role Mixin {
    multi method AT-KEY(::?CLASS:D: Str() $lookup --> Mu) is raw {
        Traced::Stash.trace: Access::Lookup, self, $lookup
    }

    multi method BIND-KEY(::?CLASS:D: Str() $lookup, Mu $new-value is raw --> Mu) is raw {
        my Mu $old-value := self.Map::AT-KEY: $lookup;
        Traced::Stash.trace: Access::Bind, self, $lookup, :$old-value, :$new-value;
    }

    multi method ASSIGN-KEY(::?CLASS:D: Str() $lookup, Mu $new-value is raw --> Mu) is raw {
        my Mu $old-value = self.Map::AT-KEY: $lookup; # Intentionally uses $old-value's container.
        Traced::Stash.trace: Access::Assign, self, $lookup, :$old-value, :$new-value;
    }
}

multi method wrap(::?CLASS:U: Stash:D $stash is raw --> Mu) {
    $stash.^mixin: Mixin;
}

multi method trace(::?CLASS:U: Access::Lookup, Stash:D $stash, Str:D $lookup --> Mu) is raw {
    $stash.Stash::AT-KEY: $lookup
}
multi method trace(::?CLASS:U: Access::Bind, Stash:D $stash, Str:D $lookup, Mu :$old-value is raw, Mu :$new-value is raw --> Mu) is raw {
    $stash.Stash::BIND-KEY: $lookup, $new-value
}
multi method trace(::?CLASS:U: Access::Assign, Stash:D $stash, Str:D $lookup, Mu :$old-value is raw, Mu :$new-value is raw --> Mu) is raw {
    $stash.Stash::ASSIGN-KEY: $lookup, $new-value
}

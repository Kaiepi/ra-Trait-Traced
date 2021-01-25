use v6;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracer;
unit role Tracer::Standard does Tracer;

# NOTE: Use &take-rw when gathering here. This comes without the readonly
# containerization &take performs on values, which is rather costly in our
# case.

multi method Str(::?CLASS:D: Traced::Routine:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp()]$nl";
    # Header
    $result ~= "$margin\<== $e.declarator() ($e.package.^name())$nl";
    # Body
    for my Pair:D @entries = gather for $e -> Pair:D $argument {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
    } -> Pair:D $entry {
        state Int:D $width    = @entries.map(*.key.chars).max;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        $result ~= "$margin    $key:$padding $value.&stringify()$nl";
    }
    # Footer
    $result ~= $e.died
            ?? "$margin!!! $e.exception.&stringify()"
            !! "$margin==> $e.result.&stringify()";
    $result
}
multi method Str(::?CLASS:D: Traced::Stash:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<== $e.longname()$nl";
    # Body
    $result ~= "$margin    $e.value.&stringify()$nl" if $e.modified;
    # Footer
    $result ~= $e.died
            ?? "$margin!!! $e.exception.&stringify()"
            !! "$margin==> $e.result.&stringify()";
    $result
}
multi method Str(::?CLASS:D: Traced::Attribute:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<== $e.declarator() ($e.package.^name())$nl";
    # Body
    # (none to speak of)
    # Footer
    $result ~= $e.died
            ?? "$margin!!! $e.exception.&stringify()"
            !! "$margin==> $e.result.&stringify()";
    $result
}
multi method Str(::?CLASS:D: Traced::Variable:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<== $e.declarator() ($e.package.^name())$nl";
    # Body
    # (none to speak of)
    # Footer
    $result ~= $e.died
            ?? "$margin!!! $e.exception.&stringify()"
            !! "$margin==> $e.result.&stringify()";
    $result
}

sub stringify(Mu $value is raw --> Str:D) { $value.raku }

multi method gist(::?CLASS:D: Traced::Routine:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    \e[;1m$e.id() \e[2;31m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<== \e[;1m$e.declarator() \e[;2m($e.package.^name())\e[m$nl";
    # Body
    for my Pair:D @entries = gather for $e -> Pair:D $argument is raw {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
    } -> Pair:D $entry is raw {
        state Int:D $width    = @entries.map(*.key.chars).max;
        state Str:D $extra    = ' ' x $width + 2;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        $result ~= "$margin    \e[1m$key\e[m:$padding $value.&prettify.subst($nl, qq/$nl$margin    $extra/, :g)$nl";
    }
    # Footer
    $result ~= $e.died
            ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
            !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
    $result
}
multi method gist(::?CLASS:D: Traced::Stash:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    \e[;1m$e.id() \e[2;32m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<==\e[;1m $e.longname()\e[m$nl";
    # Body
    $result ~= "$margin    $e.value.&prettify.subst($nl, qq/$nl$margin         /, :g)$nl" if $e.modified;
    # Footer
    $result ~= $e.died
            ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
            !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
    $result
}
multi method gist(::?CLASS:D: Traced::Attribute:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    \e[;1m$e.id() \e[2;34m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<==\e[;1m $e.declarator() \e[;2m($e.package.^name())$nl";
    # Body
    # (none to speak of)
    # Footer
    $result ~= $e.died
            ?? "$margin!!! \e[m$e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
            !! "$margin==> \e[m$e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
    $result
}
multi method gist(::?CLASS:D: Traced::Variable:D :event($e)! is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    \e[;1m$e.id() \e[2;33m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<== \e[;1m$e.declarator() \e[;2m($e.package.^name())$nl";
    # Body
    # (none to speak of)
    # Footer
    $result ~= $e.died
            ?? "$margin!!! \e[m$e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
            !! "$margin==> \e[m$e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
    $result
}

proto sub prettify(Mu --> Str:D)                            {*}
multi sub prettify(Mu $value is raw --> Str:D)              { $value.gist }
multi sub prettify(Exception:D $exception is raw --> Str:D) { "\e[31m$exception.^name()\e[m" }
multi sub prettify(Failure:D $failure is raw --> Str:D)     { "\e[33m$failure.exception.^name()\e[m" }
multi sub prettify(Junction:D $junction is raw --> Str:D)   { $junction.THREAD(&prettify).gist }

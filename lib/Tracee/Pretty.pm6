use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracee::Standard;
unit class Tracee::Pretty does Tracee::Standard is repr<Uninstantiable>;

our proto sub prettify(Mu --> Str:D)                            {*}
    multi sub prettify(Mu $value is raw --> Str:D)              { $value.gist }
    multi sub prettify(Exception:D $exception is raw --> Str:D) { "\e[31m$exception.^name()\e[m" }
    multi sub prettify(Failure:D $failure is raw --> Str:D)     { "\e[33m$failure.exception.^name()\e[m" }
    multi sub prettify(Junction:D $junction is raw --> Str:D)   { $junction.THREAD(&prettify).gist }

method fill(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    self.title($e, :$nl, :$margin) ~
    self.header($e, :$nl, :$margin) ~
    self.entries($e, :$nl, :$margin).join ~
    self.footer($e, :$nl, :$margin)
}

proto method title(::?CLASS:U: Traced:D $e is raw;; Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    "$margin    \e[;1m$e.id() {{*}}$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl"
}
multi method title(::?CLASS:U: Traced::Routine --> "\e[2;31m")   { }
multi method title(::?CLASS:U: Traced::Stash --> "\e[2;32m")     { }
multi method title(::?CLASS:U: Traced::Variable --> "\e[2;33m")  { }
multi method title(::?CLASS:U: Traced::Attribute --> "\e[2;34m") { }

proto method header(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    "$margin\<== \e[;1m{{*}}$nl"
}
multi method header(::?CLASS:U: Traced::Routine $e is raw --> Str:D)   { "$e.declarator() \e[2m($e.package.^name())\e[m" }
multi method header(::?CLASS:U: Traced::Stash $e is raw --> Str:D)     { $e.longname }
multi method header(::?CLASS:U: Traced::Variable $e is raw --> Str:D)  { "$e.declarator() \e[2m($e.package.^name())\e[m" }
multi method header(::?CLASS:U: Traced::Attribute $e is raw --> Str:D) { "$e.declarator() \e[2m($e.package.^name())\e[m" }
    
proto method entries(::?CLASS:U: Traced:D --> Seq:D) {*}
multi method entries(::?CLASS:U: Traced:D --> Seq:D) { Empty.Seq }
multi method entries(::?CLASS:U:
    Traced::Routine:D $e is raw;; Str:D :$nl is raw = $?NL, Str:D :$margin! is raw
--> Seq:D) {
    gather for $e -> Pair:D $argument is raw {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
    } ==> my Pair:D @entries;

    gather for @entries -> Pair:D $entry is raw {
        state Int:D $width    = @entries.map(*.key.chars).max;
        state Str:D $extra    = ' ' x $width + 2;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        take-rw "$margin    \e[1m$key\e[m:$padding $value.&prettify.subst($nl, qq/$nl$margin    $extra/, :g)$nl";
    }
}
multi method entries(::?CLASS:U:
    Traced::Stash:D $e is raw;; Str:D :$nl is raw = $?NL, Str:D :$margin! is raw
--> Seq:D) {
    gather if $e.modified {
        take-rw "$margin    $e.value.&prettify.subst($nl, qq/$nl$margin         /, :g)$nl";
    }
}

method footer(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw--> Str:D) {
    $e.died
        ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
        !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)"
}

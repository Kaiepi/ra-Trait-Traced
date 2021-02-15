use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracee::Standard;
#|[ A tracee that produces standard, human-readable output. ]
unit class Tracee::Pretty does Tracee::Standard;

#|[ Prettifies a traced value. ]
our proto sub prettify(Mu --> Str:D)                            {*}
    multi sub prettify(Mu $value is raw --> Str:D)              { $value.gist }
    multi sub prettify(Exception:D $exception is raw --> Str:D) { "\e[31m$exception.^name()\e[m" }
    multi sub prettify(Failure:D $failure is raw --> Str:D)     { "\e[33m$failure.exception.^name()\e[m" }
    multi sub prettify(Junction:D $junction is raw --> Str:D)   { $junction.THREAD(&prettify).gist }

#|[ A trace's title. This contains metadata that distinguishes traces from one another. ]
proto method title(::?CLASS:D: Traced:D $e is raw;; Str:D :$margin! is raw --> Str:D) {
    "$margin    \e[;1m$e.id() {{*}}$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$!nl"
}
multi method title(::?CLASS:D: Traced::Routine::Event:D --> "\e[2;31m")   { }
multi method title(::?CLASS:D: Traced::Stash::Event:D --> "\e[2;32m")     { }
multi method title(::?CLASS:D: Traced::Variable::Event:D --> "\e[2;33m")  { }
multi method title(::?CLASS:D: Traced::Attribute::Event:D --> "\e[2;34m") { }

#|[ A trace's header. This represents an input of some sort. ]
proto method header(::?CLASS:D: Traced:D $e is raw, Str:D :$margin! is raw --> Str:D) {
    "$margin\<== \e[;1m{{*}}$!nl"
}
multi method header(::?CLASS:D: Traced::Routine::Event:D $e is raw --> Str:D) {
    "$e.declarator() \e[2m($e.package.^name())\e[m"
}
multi method header(::?CLASS:D: Traced::Stash::Event:D $e is raw --> Str:D) {
    $e.longname
}
multi method header(::?CLASS:D: Traced::Variable::Event:D $e is raw --> Str:D) {
    "$e.declarator() \e[2m($e.package.^name())\e[m"
}
multi method header(::?CLASS:D: Traced::Attribute::Event:D $e is raw --> Str:D) {
    "$e.declarator() \e[2m($e.package.^name())\e[m"
}

#|[ A trace's entries. This represents arguments of some sort given alongside an input. ]
proto method entries(::?CLASS:D: Traced:D --> Seq:D) {*}
multi method entries(::?CLASS:D: Traced:D --> Seq:D) { Empty.Seq }
multi method entries(::?CLASS:D: Traced::Routine::Event:D $e is raw;; Str:D :$margin! is raw --> Seq:D) {
    my Pair:D @entries = gather for $e -> Pair:D $argument is raw {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()" => $a);
    } ==> map(-> Pair:D $entry is raw {
        state Int:D $width    = @entries.map(*.key.chars).max;
        state Str:D $extra    = ' ' x $width + 2;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        "$margin    \e[1m$key\e[m:$padding $value.&prettify.subst($!nl, qq/$!nl$margin    $extra/, :g)$!nl"
    })
}
multi method entries(::?CLASS:D: Traced::Stash::Event:D $e is raw;; Str:D :$margin! is raw --> Seq:D) {
    gather if $e.modified {
        take-rw "$margin    $e.value.&prettify.subst($!nl, qq/$!nl$margin         /, :g)$!nl";
    }
}

#|[ A trace's footers. This represents an output of some sort. ]
method footer(::?CLASS:D: Traced:D $e is raw, Str:D :$margin! is raw --> Str:D) {
    $e.died
        ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($!nl, qq/$!nl$margin    /, :g)$!nl"
        !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($!nl, qq/$!nl$margin    /, :g)$!nl"
}

use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracee::Standard;
#|[ A tracee that produces standard, machine-readable output. ]
unit class Tracee::Bitty does Tracee::Standard;

#|[ Stringifies a value for output. ]
our sub stringify(Mu $value is raw --> Str:D) { $value.raku }

#|[ A trace's title. This contains metadata that distinguishes traces from one another. ]
method title(::?CLASS:D: Traced:D $e is raw, Str:D :$margin! is raw --> Str:D) {
    "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$!nl"
}

#|[ A trace's header. This represents an input of some sort. ]
proto method header(::?CLASS:D: Traced:D $e is raw, Str:D :$margin! is raw --> Str:D) {
    "$margin\<== {{*}}$!nl"
}
multi method header(::?CLASS:D: Traced::Routine::Event:D $e is raw --> Str:D) {
    "$e.declarator() ($e.package.^name())"
}
multi method header(::?CLASS:D: Traced::Stash::Event:D $e is raw --> Str:D) {
    $e.longname
}
multi method header(::?CLASS:D: Traced::Variable::Event:D $e is raw --> Str:D) {
    "$e.declarator() ($e.package.^name())"
}
multi method header(::?CLASS:D: Traced::Attribute::Event:D $e is raw --> Str:D) {
    "$e.declarator() ($e.package.^name())"
}

#|[ A trace's entries. This represents arguments of some sort given alongside an input. ]
proto method entries(::?CLASS:D: Traced:D --> Seq:D) {*}
multi method entries(::?CLASS:D: Traced:D --> Seq:D) { Empty.Seq }
multi method entries(::?CLASS:D: Traced::Routine::Event:D $e is raw;; Str:D :$margin! is raw --> Seq:D) {
    my Pair:D @entries = gather for $e -> Pair:D $argument {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()" => $a);
    } ==> map(-> Pair:D $entry {
        state Int:D $width    = @entries.map(*.key.chars).max;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        "$margin    $key:$padding $value.&stringify()$!nl"
    })
}
multi method entries(::?CLASS:D: Traced::Stash::Event:D $e is raw;; Str:D :$margin! is raw --> Seq:D) {
    gather if $e.modified {
        take-rw "$margin    $e.value.&stringify()$!nl";
    }
}

#|[ A trace's footers. This represents an output of some sort. ]
method footer(::?CLASS:D: Traced:D $e is raw, Str:D :$margin! is raw --> Str:D) {
    $e.died
        ?? "$margin!!! $e.exception.&stringify()$!nl"
        !! "$margin==> $e.result.&stringify()$!nl"
}

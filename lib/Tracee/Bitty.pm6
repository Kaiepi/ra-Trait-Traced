use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracee::Standard;
unit class Tracee::Bitty does Tracee::Standard is repr<Uninstantiable>;

our sub stringify(Mu $value is raw --> Str:D) { $value.raku }

method fill(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    self.title($e, :$nl, :$margin) ~
    self.header($e, :$nl, :$margin) ~
    self.entries($e, :$nl, :$margin).join ~
    self.footer($e, :$nl, :$margin)
}

method title(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl"
}

proto method header(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    "$margin\<== {{*}}$nl"
}
multi method header(::?CLASS:U: Traced::Routine:D $e is raw --> Str:D)   { "$e.declarator() ($e.package.^name())" }
multi method header(::?CLASS:U: Traced::Stash:D $e is raw --> Str:D)     { $e.longname }
multi method header(::?CLASS:U: Traced::Variable:D $e is raw --> Str:D)  { "$e.declarator() ($e.package.^name())" }
multi method header(::?CLASS:U: Traced::Attribute:D $e is raw --> Str:D) { "$e.declarator() ($e.package.^name())" }

proto method entries(::?CLASS:U: Traced:D --> Seq:D) {*}
multi method entries(::?CLASS:U: Traced:D --> Seq:D) { Empty.Seq }
multi method entries(::?CLASS:U:
    Traced::Routine:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw
--> Seq:D) {
    gather for $e -> Pair:D $argument {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
    } ==> my Pair:D @entries;

    gather for @entries -> Pair:D $entry {
        state Int:D $width    = @entries.map(*.key.chars).max;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        take-rw "$margin    $key:$padding $value.&stringify()$nl";
    }
}
multi method entries(::?CLASS:U:
    Traced::Stash:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw
--> Seq:D) {
    gather if $e.modified {
        take-rw "$margin    $e.value.&stringify()$nl";
    }
}

method footer(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    $e.died
        ?? "$margin!!! $e.exception.&stringify()"
        !! "$margin==> $e.result.&stringify()"
}

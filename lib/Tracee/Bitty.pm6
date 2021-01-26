use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracee::Standard;
unit class Tracee::Bitty does Tracee::Standard is repr<Uninstantiable>;

our sub stringify(Mu $value is raw --> Str:D) { $value.raku }

proto method fill(::?CLASS:U: Traced:D --> Str:D) {*}
multi method fill(::?CLASS:U: Traced::Routine:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
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
        $result ~= "$margin    $key:$padding $value.&::stringify()$nl";
    }
    # Footer
    $result ~= $e.died
            ?? "$margin!!! $e.exception.&::stringify()"
            !! "$margin==> $e.result.&::stringify()";
    $result
}
multi method fill(::?CLASS:U: Traced::Stash:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    my Str:D $result  = '';
    # Title
    $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
    # Header
    $result ~= "$margin\<== $e.longname()$nl";
    # Body
    $result ~= "$margin    $e.value.&::stringify()$nl" if $e.modified;
    # Footer
    $result ~= $e.died
            ?? "$margin!!! $e.exception.&::stringify()"
            !! "$margin==> $e.result.&::stringify()";
    $result
}
multi method fill(::?CLASS:U: Traced::Attribute:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
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
            ?? "$margin!!! $e.exception.&::stringify()"
            !! "$margin==> $e.result.&::stringify()";
    $result
}
multi method fill(::?CLASS:U: Traced::Variable:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
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
            ?? "$margin!!! $e.exception.&::stringify()"
            !! "$margin==> $e.result.&::stringify()";
    $result
}

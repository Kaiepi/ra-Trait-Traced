use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracer;
unit class Tracer::Default;

#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:_: --> IO::Handle:D) { ... }

role TTY does Tracer {
    has IO::Handle:D $.handle is required;

    # NOTE: Use &take-rw when gathering here. This comes without the readonly
    # containerization &take performs on values, which is rather costly in our
    # case.
    multi method gist(::?CLASS:D: Traced::Routine:D :event($e) is raw --> Str:D) {
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    \e[;1m$e.id() \e[2;31m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
        # Header
        $result ~= "$margin\<==\e[;1m $e.declarator() $e.prefix()$e.name() ($e.package.^name())$nl";
        # Body
        $result ~= gather for my Pair:D @entries = gather for Seq($e) -> (
            Parameter:D :key($p) is raw, Mu :value($a) is raw
        ) {
            once take-rw (self => $a) and next if $p.invocant and not $p.name;
            take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
        } -> (Str:D :$key is raw, Mu :$value is raw) {
            state Int:D $width    = @entries.map(*.key.chars).max;
            state Str:D $extra    = ' ' x $width + 2;
            my    Str:D $padding := ' ' x $width - $key.chars;
            take-rw "$margin    \e[1m$key\e[m:$padding $value.&prettify.subst($nl, qq/$nl$margin    $extra/, :g)$nl";
        }.join: "\e[1m";
        # Footer
        $result ~= $e.died
                ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
                !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
        $result
    }
    multi method gist(::?CLASS:D: Traced::Stash:D :event($e) is raw --> Str:D) {
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    \e[;1m$e.id() \e[2;32m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
        # Header
        $result ~= "$margin\<==\e[;1m $e.longname()$nl";
        # Body
        if $e.modified {
            $result ~= "$margin    old\e[m: $e.old-value.&prettify.subst($nl, qq/$nl$margin         /, :g)\e[;1m$nl";
            $result ~= "$margin    new\e[m: $e.new-value.&prettify.subst($nl, qq/$nl$margin         /, :g)$nl";
        }
        # Footer
        $result ~= $e.died
                ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
                !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
        $result
    }
    multi method gist(::?CLASS:D: Traced::Attribute:D :event($e) is raw --> Str:D) {
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    \e[;1m$e.id() \e[2;34m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
        # Header
        $result ~= "$margin\<==\e[;1m $e.name() ($e.package.^name())$nl";
        # Body
        # (none to speak of)
        # Footer
        $result ~= $e.died
                ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
                !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
        $result
    }
    multi method gist(::?CLASS:D: Traced::Variable:D :event($e) is raw --> Str:D) {
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    \e[;1m$e.id() \e[2;33m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
        # Header
        $result ~= "$margin\<==\e[;1m $e.declarator() ($e.package.^name())$nl";
        # Body
        # (none to speak of)
        # Footer
        $result ~= $e.died
                ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)"
                !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)";
        $result
    }

    proto sub prettify(Mu --> Str:D)                            {*}
    multi sub prettify(Mu $value is raw --> Str:D)              { $value.gist }
    multi sub prettify(Exception:D $exception is raw --> Str:D) { "\e[31m$exception.^name()\e[m" }
    multi sub prettify(Failure:D $failure is raw --> Str:D)     { "\e[33m$failure.exception.^name()\e[m" }
    multi sub prettify(Junction:D $junction is raw --> Str:D)   { $junction.THREAD: &prettify }

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        $!handle.say: self.gist: :$event
    }
}

role File does Tracer {
    has IO::Handle:D $.handle is required;

    multi method Str(::?CLASS:D: Traced::Routine:D :event($e) is raw --> Str:D) {
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp()]$nl";
        # Header
        $result ~= "$margin\<== $e.declarator() $e.prefix()$e.name() ($e.package.^name())$nl";
        # Body
        for my Pair:D @entries = gather for Seq($e) -> (Parameter:D :key($p) is raw, Mu :value($a) is raw) {
            once take-rw (self => $a) and next if $p.invocant and not $p.name;
            take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
        } -> (Str:D :$key is raw, Mu :$value is raw) {
            state Int:D $width    = @entries.map(*.key.chars).max;
            my    Str:D $padding := ' ' x $width - $key.chars;
            $result ~= "$margin    $key:$padding $value.&stringify()$nl";
        }
        # Footer
        $result ~= $e.died
                ?? "$margin!!! $e.exception.&stringify()"
                !! "$margin==> $e.result.&stringify()";
        $result
    }
    multi method Str(::?CLASS:D: Traced::Stash:D :event($e) is raw --> Str:D) {
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
        # Header
        $result ~= "$margin\<== $e.longname()$nl";
        # Body
        if $e.modified {
            $result ~= "$margin    old: $e.old-value.&stringify()$nl";
            $result ~= "$margin    new: $e.new-value.&stringify()$nl";
        }
        # Footer
        $result ~= $e.died
                ?? "$margin!!! $e.exception.&stringify()"
                !! "$margin==> $e.result.&stringify()";
        $result
    }
    multi method Str(::?CLASS:D: Traced::Attribute:D :event($e) is raw --> Str:D) {
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $nl     := $!handle.nl-out;
        my Str:D $result  = '';
        # Title
        $result ~= "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl";
        # Header
        $result ~= "$margin\<== $e.name() ($e.package.^name())$nl";
        # Body
        # (none to speak of)
        # Footer
        $result ~= $e.died
                ?? "$margin!!! $e.exception.&stringify()"
                !! "$margin==> $e.result.&stringify()";
        $result
    }
    multi method Str(::?CLASS:D: Traced::Variable:D :event($e) is raw --> Str:D) {
        my Str:D $margin := ' ' x 4 * $e.calls;
        my Str:D $nl     := $!handle.nl-out;
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

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        PRE  $!handle.lock;
        POST $!handle.unlock;
        $!handle.say: self.Str: :$event
    }
}

method ^parameterize(::?CLASS:U $this is raw, IO::Handle:D $handle is raw --> ::?CLASS:D) {
    my Mu         $mixin  := $handle.t ?? TTY !! File;
    my ::?CLASS:D $tracer := $this.new does $mixin :value($handle);
    $tracer.^set_name: self.name($this) ~ qq/["$handle"]/;
    $tracer
}

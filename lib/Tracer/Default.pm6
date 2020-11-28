use v6.d;
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

    # NOTE: It would be preferable to enforce trace formatting with methods to
    # render each each part of a trace. We don't for performance reasons.
    #
    # NOTE: Use &take-rw when gathering here. This comes without the readonly
    # containerization &take performs on values, which is rather costly in our
    # case.
    multi method gist(::?CLASS:D: Traced::Routine:D :event($e) is raw --> Str:D) {
        my Str:D $nl-out := $!handle.nl-out;
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    \e[;1m$e.id() \e[2;31m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<==\e[;1m $e.declarator() $e.prefix()$e.name() ($e.package.^name())";
            # Body
            take-rw gather for my Pair:D @entries = gather for Seq($e) -> (
                Parameter:D :key($p) is raw, Mu :value($a) is raw
            ) {
                once take-rw (self => $a) and next if $p.invocant and not $p.name;
                take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
            } -> (Str:D :$key is raw, Mu :$value is raw) {
                state Int:D $width  = @entries.map(*.key.chars).max;
                state Str:D $extra = ' ' x $width + 2;
                my Str:D $padding := ' ' x $width - $key.chars;
                take-rw "$margin    $key\e[m:$padding $value.&prettify.subst($nl-out, qq/$nl-out$margin    $extra/, :g)";
            }.join: "\e[;1m$nl-out";
            # Footer
            take-rw $e.died
                 ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)"
                 !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)";
        }.join: $nl-out
    }
    multi method gist(::?CLASS:D: Traced::Stash:D :event($e) is raw --> Str:D) {
        my Str:D $nl-out := $!handle.nl-out;
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    \e[;1m$e.id() \e[2;32m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<==\e[;1m $e.longname()";
            # Body
            if $e.modified {
                take-rw "$margin    old\e[m: $e.old-value.&prettify.subst($nl-out, qq/$nl-out$margin         /, :g)\e[;1m";
                take-rw "$margin    new\e[m: $e.new-value.&prettify.subst($nl-out, qq/$nl-out$margin         /, :g)";
            }
            # Footer
            take-rw $e.died
                 ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)"
                 !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)";
        }.join: $nl-out
    }
    multi method gist(::?CLASS:D: Traced::Attribute:D :event($e) is raw --> Str:D) {
        my Str:D $nl-out := $!handle.nl-out;
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    \e[;1m$e.id() \e[2;34m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<==\e[;1m $e.name() ($e.package.^name())";
            # Body
            # (none to speak of)
            # Footer
            take-rw $e.died
                 ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)"
                 !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)";
        }.join: $nl-out
    }
    multi method gist(::?CLASS:D: Traced::Variable:D :event($e) is raw --> Str:D) {
        my Str:D $nl-out := $!handle.nl-out;
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    \e[;1m$e.id() \e[2;33m$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<==\e[;1m $e.declarator() ($e.package.^name())";
            # Body
            # (none to speak of)
            # Footer
            take-rw $e.died
                 ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)"
                 !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl-out, qq/$nl-out$margin    /, :g)";
        }.join: $nl-out
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
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp()]";
            # Header
            take-rw "$margin\<== $e.declarator() $e.prefix()$e.name() ($e.package.^name())";
            # Body
            for my Pair:D @entries = gather for Seq($e) -> (Parameter:D :key($p) is raw, Mu :value($a) is raw) {
                once take-rw (self => $a) and next if $p.invocant and not $p.name;
                take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()$p.suffix()" => $a);
            } -> (Str:D :$key is raw, Mu :$value is raw) {
                state Int:D $width   = @entries.map(*.key.chars).max;
                state Str:D $padding = ' ' x $width + 2;
                take-rw "$margin    $key: $value.&stringify()";
            }
            # Footer
            take-rw $e.died
                 ?? "$margin!!! $e.exception.&stringify()"
                 !! "$margin==> $e.result.&stringify()";
        }.join: $!handle.nl-out
    }
    multi method Str(::?CLASS:D: Traced::Stash:D :event($e) is raw --> Str:D) {
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<== $e.longname()";
            # Body
            if $e.modified {
                take-rw "$margin    old: $e.old-value.&stringify()";
                take-rw "$margin    new: $e.new-value.&stringify()";
            }
            # Footer
            take-rw $e.died
                 ?? "$margin!!! $e.exception.&stringify()"
                 !! "$margin==> $e.result.&stringify()";
        }.join: $!handle.nl-out
    }
    multi method Str(::?CLASS:D: Traced::Attribute:D :event($e) is raw --> Str:D) {
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<== $e.name() ($e.package.^name())";
            # Body
            # (none to speak of)
            # Footer
            take-rw $e.died
                 ?? "$margin!!! $e.exception.&stringify()"
                 !! "$margin==> $e.result.&stringify()";
        }.join: $!handle.nl-out
    }
    multi method Str(::?CLASS:D: Traced::Variable:D :event($e) is raw --> Str:D) {
        gather {
            my Str:D $margin := ' ' x 4 * $e.calls;
            # Title
            take-rw "$margin    $e.id() $e.kind() $e.of() [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take-rw "$margin\<== $e.declarator() ($e.package.^name())";
            # Body
            # (none to speak of)
            # Footer
            take-rw $e.died
                 ?? "$margin!!! $e.exception.&stringify()"
                 !! "$margin==> $e.result.&stringify()";
        }.join: $!handle.nl-out
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

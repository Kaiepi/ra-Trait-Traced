use v6.d;
use Traced;
use Tracer;
unit class Tracer::Default;

#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:_: --> IO::Handle:D) { ... }

role TTY[IO::Handle:D $handle] does Tracer {
    method handle(::?CLASS:_: --> IO::Handle:D) { $handle }

    multi method gist(::?CLASS:_: Traced:D :event($e) --> Str:D) {
        my Str:D $nl-out = $handle.nl-out;
        gather {
            my Str:D constant $border = ' ' x 4;
            my Str:D          $margin = $border x $e.calls;
            # Title
            take "$margin$border\e[;1m$e.id() \e[2;$e.colour()m$e.category() $e.type()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]";
            # Header
            take "$margin\<==\e[;1m $e.what()";
            # Body
            for my Pair:D @entries = $e.entries -> (Str:D :$key, Mu :$value is raw) {
                state Int:D $width   = @entries.map(*.key.chars).max;
                state Str:D $padding = ' ' x $width + 2;
                take "$margin$border$key\e[m: $value.&prettify.subst($nl-out, qq/$nl-out$margin$border$padding/)\e[;1m";
            }
            # Footer
            if $e.died {
                take "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl-out, qq/$nl-out$margin$border/, :g)";
            } else {
                take "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl-out, qq/$nl-out$margin$border/, :g)";
            }
        }.join: $nl-out
    }

    proto sub prettify(Mu --> Str:D)                     {*}
    multi sub prettify(Mu $value is raw --> Str:D)       { $value.gist }
    multi sub prettify(Exception:D $exception --> Str:D) { "\e[31m$exception.^name()\e[0m" }
    multi sub prettify(Failure:D $failure --> Str:D)     { "\e[33m$failure.exception.^name()\e[0m"}

    multi method say(::?CLASS:_: Traced:D $event --> Bool:_) {
        $handle.say: self.gist: :$event
    }
}

role File[IO::Handle:D $handle] does Tracer {
    method handle(::?CLASS:_: --> IO::Handle:D) { $handle }

    method stringify(::?CLASS:_: Mu $value is raw --> Str:D) {
        $value.raku
    }

    multi method gist(::?CLASS:_: Traced:D :event($e) --> Seq:D) {
        gather {
            my Str:D $indent = ' ' x 4 * $e.calls;
            # Title
            take "$indent$e.id() $e.category() $e.type() [$e.thread-id() @ $e.timestamp()]",
            # Header
            take "$indent\<== $e.what()";
            # Body
            for my Pair:D @entries = $e.entries -> (Str:D :$key, Mu :$value is raw) {
                state Int:D $width   = @entries.map(*.key.chars).max;
                state Str:D $padding = ' ' x $width - .key.chars;
                take "$indent    $key:$padding $value.&stringify";
            }
            # Footer
            take $e.died
              ?? "$indent!!! $e.exception.&stringify"
              !! "$indent==> $e.exception.&stringify";
        }
    }

    sub stringify(Mu $value is raw --> Str:D) { $value.raku }

    multi method say(::?CLASS:_: Traced:D $event --> Bool:_) {
        PRE  $handle.lock;
        POST $handle.unlock;
        $handle.say: self.gist: :$event
    }
}

method ^parameterize(::?CLASS:U $this is raw, IO::Handle:D $handle --> Mu) {
    my Mu $mixin := $this.^mixin: $handle.t ?? TTY[$handle] !! File[$handle];
    $mixin.^set_name: $this.^name ~ qq/["$handle"]/;
    $mixin
}

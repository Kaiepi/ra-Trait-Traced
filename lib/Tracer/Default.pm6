use v6.d;
use Traced;
use Tracer;
unit class Tracer::Default;

#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:_: --> IO::Handle:D) { ... }

role TTY[IO::Handle:D $handle] does Tracer {
    method handle(::?CLASS:_: --> IO::Handle:D) { $handle }

    multi method stringify(::?CLASS:_: Mu $value is raw --> Str:D) {
        $value.gist
    }
    multi method stringify(::?CLASS:_: Exception:D $exception --> Str:D) {
        sprintf "\e[31m%s\e[0m", $exception.^name
    }
    multi method stringify(::?CLASS:_: Failure:D $failure --> Str:D) {
        sprintf "\e[33m%s\e[0m", $failure.exception.^name
    }

    multi method lines(::?CLASS:_: Traced:D $traced --> Seq:D) {
        gather {
            my Str:D $margin = ' ' x 4 * $traced.calls;
            my Str:D $nl-out = $handle.nl-out;

            # Title
            take sprintf "$margin\e[2m%d\e[0m \e[%d;1;2m%s %s\e[0m \e[2m[%d @ %f]\e[0m",
                         $traced.id,
                         $traced.colour, $traced.category, $traced.type,
                         $traced.thread-id, $traced.timestamp;

            # Header
            take sprintf "$margin\e[2m<==\e[0m \e[1m%s\e[0m", $traced.what;

            # Body
            for my Pair:D @entries = $traced.entries {
                state Int:D $width = @entries.map(*.key.chars).max;
                state Str:D $extra = ' ' x $width + 6;
                my Str:D $key     = .key;
                my Str:D $padding = ' ' x $width - .key.chars;
                my Str:D $value   = self.stringify(.value).subst($nl-out, $nl-out ~ $margin ~ $extra, :g);
                take "$margin    \e[1m$key\e[0m:$padding $value";
            }

            # Footer
            if $traced.died {
                my Str:D $exception = self.stringify($traced.exception).subst($nl-out, $nl-out ~ $margin ~ ' ' x 4);
                take "$margin\e[2m!!!\e[0m $exception";
            } else {
                my Str:D $result = self.stringify($traced.result).subst($nl-out, $nl-out ~ $margin ~ ' ' x 4);
                take "$margin\e[2m==>\e[0m $result";
            }
        }
    }

    multi method say(::?CLASS:_: Traced:D $traced --> Bool:_) {
        $handle.say: self.lines($traced).join($handle.nl-out)
    }
}

role File[IO::Handle:D $handle] does Tracer {
    method handle(::?CLASS:_: --> IO::Handle:D) { $handle }

    method stringify(::?CLASS:_: Mu $value is raw --> Str:D) {
        $value.raku
    }

    multi method lines(::?CLASS:_: Traced:D $traced --> Seq:D) {
        gather {
            my Str:D $margin = ' ' x 4 * $traced.calls;

            # Title
            take sprintf "$margin%d %s %s [%d @ %f]",
                         $traced.id, $traced.category, $traced.type,
                         $traced.thread-id, $traced.timestamp;

            # Header
            my Str:D $what = $traced.what;
            take "$margin\<== $what";

            # Body
            for my Pair:D @entries = $traced.entries {
                state Int:D $width = @entries.map(*.key.chars).max;
                my Str:D $key     = .key;
                my Str:D $padding = ' ' x $width - .key.chars;
                my Str:D $value   = self.stringify: .value;
                take "$margin    $key:$padding $value";
            }

            # Footer
            if $traced.died {
                my Str:D $exception = self.stringify: $traced.exception;
                take "$margin!!! $exception";
            } else {
                my Str:D $result = self.stringify: $traced.result;
                take "$margin==> $result";
            }
        }
    }

    multi method say(::?CLASS:_: Traced:D $traced --> Bool:_) {
        PRE  $handle.lock;
        POST $handle.unlock;
        $handle.say: self.lines($traced).join($handle.nl-out)
    }
}

method ^parameterize(::?CLASS:U $this is raw, IO::Handle:D $handle --> Mu) {
    my Mu $mixin := $this.^mixin: $handle.t ?? TTY[$handle] !! File[$handle];
    $mixin.^set_name: $this.^name ~ qq/["$handle"]/;
    $mixin
}

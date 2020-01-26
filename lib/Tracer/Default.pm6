use v6.d;
use NativeCall;
use Traced;
use Tracer;
unit class Tracer::Default is Tracer;

method title(::?CLASS:U: Traced:D --> Str:D)        { ... }
method header(::?CLASS:U: Traced:D --> Str:D)       { ... }
method entries(::?CLASS:U: Traced:D --> Iterable:D) { ... }
method footer(::?CLASS:U: Traced:D --> Str:D)       { ... }

multi method lines(::?CLASS:U: Traced:D $traced --> Seq:D) {
    gather {
        take self.title: $traced;
        take self.header: $traced;
        take $_ for self.entries: $traced;
        take self.footer: $traced;
    } ==> map({ ' ' x 4 * $traced.calls ~ $_ })
}

multi method say(::?CLASS:U: Traced:D --> Bool:D) { ... }

role TTY[$handle] {
    method handle(::?CLASS:U:) { $handle }

    multi method stringify(::?CLASS:U: Mu $value is raw --> Str:D) {
        $value.gist
    }
    multi method stringify(::?CLASS:U: Failure:D $failure --> Str:D) {
        sprintf "\e[33m%s\e[0m", $failure.exception.^name
    }
    multi method stringify(::?CLASS:U: Exception:D $exception --> Str:D) {
        sprintf "\e[31m%s\e[0m", $exception.^name
    }

    method title(::?CLASS:U: Traced:D $traced --> Str:D) {
        sprintf "\e[2m%s\e[0m \e[%d;1;2m%s %s\e[0m \e[2m[%d @ %f]\e[0m",
                 $traced.id,
                 $traced.colour, $traced.category, $traced.type,
                 $traced.thread-id, $traced.timestamp
    }

    method header(::?CLASS:U: Traced:D $traced --> Str:D) {
        sprintf "\e[2m<==\e[0m \e[1m%s\e[0m", $traced.input
    }

    method entries(::?CLASS:U: Traced:D $traced --> Iterable:D) {
        gather {
            my Pair:D @entries = $traced.entries;
            my Int:D  $width   = @entries ?? @entries.map(*.key.chars).max !! 0;
            for @entries -> Pair:D (Str:D :$key, Mu :value($entry) is raw) {
                my Str:D $value   = self.stringify: $entry;
                my Str:D $padding = ' ' x $key.chars - $width;
                take "    \e[1m$key\e[0m:$padding $value";
            }
        }
    }

    method footer(::?CLASS:U: Traced:D $traced --> Str:D) {
        with $traced.exception {
            sprintf "\e[2m!!!\e[0m %s", self.stringify: $traced.exception;
        } else {
            sprintf "\e[2m==>\e[0m %s", self.stringify: $traced.result;
        }
    }

    my class FILE is repr<CPointer> { }
    sub fdopen(int32, Str --> FILE) is native {*}
    sub fputs(Str, FILE --> int32)  is native {*}
    sub strerror(int32 --> Str)     is native {*}

    my Junction:D $standard = ($*OUT, $*ERR, $*IN).any.native-descriptor;
    multi method say(::?CLASS:U: Traced:D $traced --> Bool:D) {
        my Str:D $output = self.lines($traced).join($handle.nl-out) ~ $handle.nl-out;
        if (my Int:D $fd = $handle.native-descriptor) ~~ $standard {
            my Int:D $errno = fputs $output, fdopen $fd, 'w';
            fail strerror $errno if $errno != 0;
            True
        } else {
            $handle.print: $output;
        }
    }
}

role File[$handle] {
    method handle(::?CLASS:U:) { $handle }

    method stringify(::?CLASS:U: Mu $value is raw --> Str:D) {
        $value.perl
    }

    method title(::?CLASS:U: Traced:D $traced --> Str:D) {
        sprintf "%d %s %s [%d @ %f]",
                 $traced.id,
                 $traced.category, $traced.type,
                 $traced.thread-id, $traced.timestamp
    }

    method header(::?CLASS:U: Traced:D $traced --> Str:D) {
        sprintf "<== %s", $traced.input
    }

    method entries(::?CLASS:U: Traced:D $traced --> Iterable:D) {
        gather {
            my Pair:D @entries = $traced.entries;
            my Int:D  $width   = @entries ?? @entries.map(*.key.chars).max !! 0;
            for @entries -> Pair:D (Str:D :$key, Mu :value($entry) is raw) {
                my Str:D $value   = self.stringify: $entry;
                my Str:D $padding = ' ' x $key.chars - $width;
                take "    $key:$padding $value";
            }
        }
    }

    method footer(::?CLASS:U: Traced:D $traced --> Str:D) {
        with $traced.exception {
            sprintf "!!! %s", self.stringify: $traced.exception;
        } else {
            sprintf "==> %s", self.stringify: $traced.result;
        }
    }

    multi method say(::?CLASS:U: Traced:D $traced --> Bool:D) {
        $handle.say: self.lines($traced).join($handle.nl-out)
    }
}

method ^parameterize(::?CLASS:U $this is raw, $handle --> Mu) {
    my Mu $mixin := $this.^mixin: $handle.does(IO) && $handle.t ?? TTY[$handle] !! File[$handle];
    $mixin.^set_name: $this.^name ~ qq/["$handle"]/;
    $mixin
}

use v6.d;
use NativeCall;
#|[ A role done by classes that handle tracing for a type of event. ]
unit role Traced;

#|[ The ID of the trace. ]
has Int:D     $.id        is required;
#|[ The ID of the thread the trace was taken in. ]
has Int:D     $.thread-id is required;
#|[ The instant the trace was taken at. ]
has Instant:D $.timestamp is required;

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

#|[ The colour to use for the key of the trace's output. ]
method colour(::?CLASS:_: --> Int:D) { ... }
#|[ The key of the trace's output. ]
method key(::?CLASS:_: --> Str:D)    { ... }

#|[ Whether or not the event traced succeeded. ]
method success(::?CLASS:D: --> Bool:D) { ... }

#|[ The title of the trace. ]
method title(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    my Str:D $format = $tty ?? "\e[2m%d [%d @ %f]\e[0m" !! "%d [%d @ %f]";
    sprintf $format, $!id, $!thread-id, $!timestamp.Rat
}

#|[ Produces the header of the trace's output. ]
proto method header(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    $tty
        ?? sprintf("\e[2m<==\e[0m \e[%s;1m[%s]\e[0m \e[1m%s\e[0m", $.colour, $.key, {*})
        !! sprintf("<== [%s] %s", $.key, {*})
}

#|[ Produces the entries of the trace's output, if any. ]
proto method entries(::?CLASS:D: Bool:D :$tty! --> Seq:D) {
    my Pair:D @entries = {*} ==> map({
        state Str:D $format  = $tty ?? "\e[1m%s\e[0m:%s %s" !! "%s:%s %s";
        state Int:D $width   = @entries.map(*.key.chars).max;
        my    Str:D $padding = ' ' x $width - .key.chars;
        sprintf $format, .key, $padding, .value
    })
}
multi method entries(::?CLASS:D: --> Seq:D) { ().Seq }

#|[ Produces the footer of the trace's output. ]
proto method footer(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    my Str:D $format = $tty ?? "\e[2m%s\e[0m %s" !! "%s %s";
    my Str:D $prefix = $.success ?? '==>' !! '!!!';
    sprintf $format, $prefix, {*}
}

multi method lines(::?CLASS:D: Bool:D :$tty = False --> Seq:D) {
    gather {
        take $.title: :$tty;
        take $.header: :$tty;
        take ' ' x 4 ~ $_ for @.entries: :$tty;
        take $.footer: :$tty;
    }
}

my $THREAD-INDENT-LEVELS = %();
#|[ Bumps the indentation level of a trace while executing the given block. ]
method !protect(::?CLASS:_: &block is raw --> Mu) is raw {
    cas $THREAD-INDENT-LEVELS, &increment-indent-level;
    LEAVE cas $THREAD-INDENT-LEVELS, &decrement-indent-level;
    block
}
sub increment-indent-level(%indent) {
    my Int:D $id = $*THREAD.id;
    if %indent{$id}:exists {
        %indent{$id}++;
    } else {
        %indent{$id} = 0;
    }
    %indent
}
sub decrement-indent-level(%indent) {
    my Int:D $id = $*THREAD.id;
    if %indent{$id}:exists {
        %indent{$id}--;
    } else {
        %indent{$id} = 0;
    }
    %indent
}

multi method Str(::?CLASS:D: --> Str:D) {
    @.lines
==> map(&indent)
==> join($?NL)
}
multi method gist(::?CLASS:D: --> Str:D) {
    @.lines(:tty)
==> map(&indent)
==> join($?NL)
}
sub indent(Str:D $line --> Str:D) {
    my Int:D $level = (⚛$THREAD-INDENT-LEVELS){$*THREAD.id};
    ' ' x 4 * $level ~ $line
}

my atomicint $next-id = 1;
#|[ Gets the next trace ID to use. ]
method next-id(::?CLASS:_: --> Int:D) { $next-id⚛++ }

# XXX: $*IN, $*OUT, and $*ERR aren't thread-safe as Raku handles them, and
# IO::Handle.lock/.unlock don't help in this case! Luckily, on Windows an
# POSIX platforms, using fputs instead is. This isn't entirely ideal, but
# it's good enough for now.
my class FILE is repr<CPointer> { }
sub fdopen(int32, Str --> FILE) is native is symbol($*DISTRO.is-win ?? '_fdopen' !! 'fdopen') {*}
sub fputs(Str, FILE --> int32) is native {*}

#|[ Traces an event. ]
method trace(::?CLASS:_: |args --> True) {
    state Junction:D $standard = ($*OUT, $*ERR, $*IN).any.native-descriptor;

    my IO::Handle:D $tracer  = $*TRACER;
    my ::?CLASS:D   $traced .= new: |args;
    my Int:D        $fd     := $tracer.native-descriptor;
    if $fd == $standard {
        fputs $traced.gist ~ $?NL, fdopen $fd, 'w';
    } elsif $tracer.t {
        $tracer.say: $traced;
    } else {
        $tracer.put: $traced;
    }
}

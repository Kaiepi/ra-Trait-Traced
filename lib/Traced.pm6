use v6.d;
use experimental :macros;
use NativeCall;
#|[ A role done by classes that handle tracing for a type of event. ]
unit class Traced;

# If &now were to be used to generate timestamps instead of this, it would
# become the main bottleneck when generating a trace. Since we only care about
# what the numeric value it contains is, not the additional features Instant
# provides on top of that, we do the work &now does to generate a time for an
# Instant ourselves.
#|[ Generates a timestamp. ]
macro timestamp() is export {
    use nqp;
    quasi { nqp::p6box_n(Rakudo::Internals.tai-from-posix: nqp::time_n(), 0) }
}

#|[ The ID of the trace. ]
has Int:D $.id        is required;
#|[ The ID of the thread the trace was taken in. ]
has Int:D $.thread-id is required;
#|[ The instant the trace was taken at. ]
has Num:D $.timestamp is required;
#|[ The number of calls in the traced call stack.  ]
has Int:D $.calls     is required;

method new(::?CLASS:_: | --> ::?CLASS:D) { ... }

#|[ The colour to use for the key of the trace's output. ]
method colour(::?CLASS:D: --> Int:D)   { ... }
#|[ The category of trace the trace belongs to. ]
method category(::?CLASS:D: --> Str:D) { ... }
#|[ The type of trace the trace is. ]
method type(::?CLASS:D: --> Str:D)     { ... }

#|[ Whether or not the event traced succeeded. ]
method success(::?CLASS:D: --> Bool:D) { ... }

#|[ The title of the trace. ]
method title(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    $tty
        ?? sprintf("\e[2m%d \e[%d;1m%s %s\e[0m \e[2m[%d @ %f]\e[0m", $!id, $.colour, $.category, $.type, $!thread-id, $!timestamp)
        !! sprintf("%d %s %s [%d @ %f]", $!id, $.category, $.type, $!thread-id, $!timestamp)
}

#|[ Produces the header of the trace's output. ]
proto method header(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    $tty
        ?? sprintf("\e[2m<==\e[0m \e[1m%s\e[0m", {*})
        !! sprintf("<== %s", {*})
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
multi method entries(::?CLASS:D: Bool:D :$tty! --> Seq:D) { ().Seq }

#|[ Produces the footer of the trace's output. ]
proto method footer(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    my Str:D $format = $tty ?? "\e[2m%s\e[0m %s" !! "%s %s";
    my Str:D $prefix = $.success ?? '==>' !! '!!!';
    sprintf $format, $prefix, {*}
}

multi method lines(::?CLASS:D: Bool:D :$tty = False --> Seq:D) {
    gather {
        take self.title: :$tty;
        take self.header: :$tty;
        take "    $_" for self.entries: :$tty;
        take self.footer: :$tty;
    }
}

multi method Str(::?CLASS:D: --> Str:D) {
    @.lines
==> map({ ' ' x 4 * $!calls ~ $_ })
==> join($?NL)
}
multi method gist(::?CLASS:D: --> Str:D) {
    @.lines(:tty)
==> map({ ' ' x 4 * $!calls ~ $_ })
==> join($?NL)
}

my atomicint $next-id = 1;
#|[ Gets the next trace ID to use. ]
method next-id(::?CLASS:U: --> Int:D) { $next-id⚛++ }

my role CallStack {
    has atomicint $!call-frames = 0;
    method increment-call-frames(::?CLASS:D: --> Int:D) {
        $!call-frames⚛++
    }
    method decrement-call-frames(::?CLASS:D: --> Int:D) {
        $!call-frames⚛--
    }
}

#|[ Increments the number of traced call frames for the given thread. ]
method increment-calls(::?CLASS:U: Thread:D $thread is raw --> Int:D) {
    $thread.HOW.mixin($thread, CallStack) unless $thread.HOW.does($thread, CallStack);
    $thread.increment-call-frames
}
#|[ Decrements the number of traced call frames for the given thread. ]
method decrement-calls(::?CLASS:U: Thread:D $thread is raw --> Int:D) {
    $thread.HOW.does($thread, CallStack)
        ?? $thread.decrement-call-frames
        !! 0
}

# XXX: $*IN, $*OUT, and $*ERR aren't thread-safe as Raku handles them, and
# IO::Handle.lock/.unlock don't help in this case! Luckily, on Windows and
# POSIX platforms, using fputs instead is. This isn't entirely ideal, but
# it's good enough for now.
my class FILE is repr<CPointer> { }
sub fdopen(int32, Str --> FILE) is native is symbol($*DISTRO.is-win ?? '_fdopen' !! 'fdopen') {*}
sub fputs(Str, FILE --> int32)  is native {*}

#|[ Traces an event. ]
method trace(::?CLASS:U: |args --> True) {
    state Junction:D $standard = ($*OUT, $*ERR, $*IN).any.native-descriptor;

    my Mu         $tracer := $*TRACER;
    my ::?CLASS:D $traced := self.new: |args;
    my Int:D      $fd     := $tracer.native-descriptor;
    if $fd == $standard {
        fputs $traced.gist ~ $?NL, fdopen $fd, 'w';
    } else {
        $tracer.lock;
        LEAVE $tracer.unlock;
        my Str:D $method = $tracer.t ?? 'say' !! 'put';
        $tracer."$method"($traced)
    }
}

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

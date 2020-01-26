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
#|[ The result of the traced event. ]
has Mu    $.result    is required;
#|[ The exception thrown when running the traced event, if any. ]
has Mu    $.exception is required;

method new(::?CLASS:_: | --> ::?CLASS:D) { ... }

#|[ The colour to use for the key of the trace's output. ]
method colour(::?CLASS:D: --> Int:D)   { ... }
#|[ The category of trace the trace belongs to. ]
method category(::?CLASS:D: --> Str:D) { ... }
#|[ The type of trace the trace is. ]
method type(::?CLASS:D: --> Str:D)     { ... }

proto method title(::?CLASS:D: --> Str:D) {
    sprintf {*}, $!id, $.category, $.type, $!thread-id, $!timestamp
}

proto method header(::?CLASS:D: --> Str:D)  {*}

proto method entries(::?CLASS:D: --> Seq:D) {*}

method footer(::?CLASS:D: --> Str:D) { ... }

multi method lines(::?CLASS:D: --> Seq:D) {
    gather {
        take $.title;
        take $.header;
        take $_ for @.entries;
        take $.footer;
    } ==> map({ ' ' x 4 * $!calls ~ $_ })
}

multi method gist(::?CLASS:D: --> Str:D) { ... }
multi method say(::?CLASS:D: --> Str:D)  { ... }

# XXX TODO: The logic handled by these roles belongs elsewhere.
my role StandardStream[Int:D $fd] {
    # XXX: $*IN, $*OUT, and $*ERR aren't thread-safe as Raku handles them, and
    # IO::Handle.lock/.unlock don't help in this case! Luckily, on Windows and
    # POSIX platforms, using fputs instead is. This isn't entirely ideal, but
    # it's good enough for now.
    my class FILE is repr<CPointer> { }
    sub fdopen(int32, Str --> FILE) is native is symbol($*DISTRO.is-win ?? '_fdopen' !! 'fdopen') {*}
    sub fputs(Str, FILE --> int32)  is native {*}
    my FILE:D $handle = fdopen $fd, 'w';

    #|[ The title of the trace. ]
    multi method title(::?CLASS:D: --> Str:D)  {
        "\e[2m%s \e[$.colour;1m%s %s\e[0m \e[2m[%d @ %f]\e[0m"
    }

    #|[ Produces the header of the trace's output. ]
    multi method header(::?CLASS:D: --> Str:D) {
        sprintf "\e[2m<==\e[0m \e[1m%s\e[0m", callsame
    }

    #|[ Produces the entries of the trace's output, if any. ]
    multi method entries(::?CLASS:D: --> Seq:D) {
        my Pair:D @entries = callsame() ==> map({
            state Int:D $width = @entries.map(*.key.chars).max;
            my Str:D $padding = ' ' x $width - .key.chars;
            sprintf "    \e[1m%s\e[0m:%s %s", .key, $padding, .value
        })
    }

    #|[ Produces the footer of the trace's output. ]
    method footer(::?CLASS:D: --> Str:D) {
        with $.exception {
            sprintf "\e[2m!!!\e[0m %s", $.exception.^name;
        } else {
            sprintf "\e[2m==>\e[0m %s", $.result.gist;
        }
    }

    multi method gist(::?CLASS:D: --> Str:D) { @.lines.join: $?NL }
    multi method say(::?CLASS:D: --> True)   { fputs self.gist ~ $?NL, $handle }
}

my role Handle[$handle] {
    #|[ The title of the trace. ]
    multi method title(::?CLASS:D: --> '%d %s %s [%d @ %f]') { }

    #|[ Produces the header of the trace's output. ]
    multi method header(::?CLASS:D: --> Str:D) { '<== ' ~ callsame }

    #|[ Produces the entries of the trace's output, if any. ]
    multi method entries(::?CLASS:D: --> Seq:D) {
        my Pair:D @entries = callsame() ==> map({
            state Int:D $width = @entries.map(*.key.chars).max;
            my Str:D $padding = ' ' x $width - .key.chars;
            sprintf "    %s:%s %s", .key, $padding, .value
        })
    }

    #|[ Produces the footer of the trace's output. ]
    method footer(::?CLASS:D: --> Str:D) {
        # XXX: Handle this from Traced instead.
        with $.exception {
            sprintf '!!! %s', $.exception.^name;
        } else {
            sprintf '==> %s', $.result.perl;
        }
    }

    multi method gist(::?CLASS:D: --> Str:D) { @.lines.join: $handle.nl-out }
    multi method say(::?CLASS:D: --> Bool:D) {
        $handle.lock;
        LEAVE $handle.unlock;
        $handle.say: self
    }
}

method ^parameterize(::?CLASS:U $this is raw, $handle --> Mu) {
    state Junction:D $standard = ($*OUT, $*ERR, $*IN).any.native-descriptor;
    my Int:D $fd = $handle.native-descriptor;
    $this but ($fd ~~ $standard ?? StandardStream[$fd] !! Handle[$handle])
}

my atomicint $next-id = 1;
#|[ Gets the next trace ID to use. ]
method next-id(::?CLASS:U: --> Int:D) { $next-id⚛++ }

my role CallStack {
    has atomicint $!call-frames = 0;
    method call-frames(::?CLASS:D: --> Int:D) {
        ⚛$!call-frames
    }
    method increment-call-frames(::?CLASS:D: --> Int:D) {
        $!call-frames⚛++
    }
    method decrement-call-frames(::?CLASS:D: --> Int:D) {
        $!call-frames⚛--
    }
}

#|[ Gets the number of traced call frames for the given thread. ]
method calls(::?CLASS:U: Thread:D $thread is raw --> Int:D) {
    $thread.HOW.does($thread, CallStack)
        ?? $thread.call-frames
        !! 0
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
        !! -1
}

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

my Supplier:D $traces .= new;
# XXX FIXME: This won't be thread-safe until traced events only keep strings
# instead of objects.
$traces.Supply.act({ .say });
#|[ Traces an event. ]
proto method trace(::?CLASS:U: :$thread = $*THREAD, :$tracer = $*TRACER, |rest --> Mu) is raw {
    my Int:D $id        := self.next-id;
    my Int:D $calls     := self.increment-calls: $thread;
    my Num:D $timestamp := timestamp;
    my Mu    $result    := try {{*}};
    self.decrement-calls: $thread;

    $traces.emit: self.^parameterize($tracer).new:
        :$id, :thread-id($thread.id), :$calls, :$timestamp,
        :$result, :exception($!),
        |rest;

    $!.rethrow with $!;
    $result
}

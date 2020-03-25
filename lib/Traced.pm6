use v6.d;
#|[ A role done by classes that handle tracing for a type of event. ]
unit class Traced;

#|[ The ID of the trace. ]
has Int:D $.id        is required;
#|[ The ID of the thread the trace was taken in. ]
has Int:D $.thread-id is required;
#|[ The instant the trace was taken at. ]
has Num:D $.timestamp is required;
#|[ The number of calls in the traced call stack.  ]
has Int:D $.calls     is required;
#|[ The result of the traced event. ]
has Mu    $.result    is required is built(:bind);
#|[ The exception thrown when running the traced event, if any. ]
has Mu    $.exception is required is built(:bind);

method new(::?CLASS:_: | --> ::?CLASS:D) { ... }

#|[ The colour to use for the key of the trace's output. ]
method colour(::?CLASS:D: --> Int:D)   { ... }
#|[ The category of trace the trace belongs to. ]
method category(::?CLASS:D: --> Str:D) { ... }
#|[ The type of trace the trace is. ]
method type(::?CLASS:D: --> Str:D)     { ... }

#|[ Produces a name for the object for which we performed a trace. ]
proto method what(::?CLASS:D: --> Str:D) {*}
multi method what(::?CLASS:D: --> Str:D) { ... }

#|[ Produces the entries of the trace, if any. ]
proto method entries(::?CLASS:D: --> Seq:D)      {*}
multi method entries(::?CLASS:D: --> Iterable:D) { () }

#|[ Whether or not the traced event died. ]
method died(::?CLASS:D: --> Bool:D)   { $!exception.DEFINITE }

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

#|[ Traces an event. ]
proto method trace(::?CLASS:U: :$thread = $*THREAD, :$tracer = $*TRACER, |rest --> Mu) is raw {
    use nqp;
    # Never trace events during precomp. We can find out if we're in precomp
    # mode through $*W, but doing a dynamic lookup for it the normal way has
    # too much overhead.
    nqp::if(nqp::isconcrete(my Mu $W := nqp::getlexdyn('$*W')) && $W.is_precompilation_mode,
            return {*});
    # Grab the metadata for the trace before running the traced event, catching
    # any exceptions thrown so we can clean up afterwards. We grab the
    # numeric value for the trace's timestamp directly since &now has more
    # overhead and Instant's features aren't useful in our case.
    my Int:D $id        := self!next-id;
    my Int:D $calls     := self!increment-calls: $thread;
    my Num:D $timestamp := Rakudo::Internals.tai-from-posix: nqp::time_n(), 0;
    my Mu    $result    := try {{*}};
    self!decrement-calls: $thread;
    # Output a trace for the event.
    $tracer.say: self.new:
        :$id, :thread-id($thread.id), :$calls, :$timestamp,
        :$result, :exception($!),
        |rest;
    # Rethrow any exception thrown by the traced event and return its original
    # result if we managed to survive.
    $!.rethrow with $!;
    $result
}

my atomicint $next-id = 1;
#|[ Gets the next trace ID to use. ]
method !next-id(::?CLASS:U: --> Int:D) { $next-id⚛++ }

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
method !increment-calls(::?CLASS:U: Thread:D $thread is raw --> Int:D) {
    $thread.HOW.mixin($thread, CallStack) unless $thread.HOW.does($thread, CallStack);
    $thread.increment-call-frames
}
#|[ Decrements the number of traced call frames for the given thread. ]
method !decrement-calls(::?CLASS:U: Thread:D $thread is raw --> Int:D) {
    $thread.HOW.does($thread, CallStack)
        ?? $thread.decrement-call-frames
        !! 0
}

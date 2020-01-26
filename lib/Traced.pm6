use v6.d;
use experimental :macros;
use NativeCall;
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

#|[ Produces the input object for which we performed a trace. ]
proto method input(::?CLASS:D: --> Str:D) {*}
multi method input(::?CLASS:D: --> Str:D) { ... }

#|[ Produces the entries of the trace, if any. ]
proto method entries(::?CLASS:D: --> Seq:D)      {*}
multi method entries(::?CLASS:D: --> Iterable:D) { () }

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

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

#|[ Traces an event. ]
proto method trace(::?CLASS:U: :$thread = $*THREAD, :$tracer = $*TRACER, |rest --> Mu) is raw {
    my Int:D      $id        := self!next-id;
    my Int:D      $calls     := self!increment-calls: $thread;
    my Num:D      $timestamp := timestamp;
    my Mu         $result    := try {{*}};
    $tracer.say: self.new:
        :$id, :thread-id($thread.id), :$calls, :$timestamp,
        :$result, :exception($!),
        |rest;
    self!decrement-calls: $thread;
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

use v6.d;
#|[ A role done by classes that handle tracing for a type of event. ]
unit role Traced;

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

#|[ The colour to use for the key of the trace's output. ]
method colour(::?CLASS:D: --> Int:D)   { ... }
#|[ The category of trace the trace belongs to. ]
method category(::?CLASS:D: --> Str:D) { ... }
#|[ The type of trace the trace is. ]
method type(::?CLASS:D: --> Str:D)     { ... }

#|[ Produces a name for the object for which we performed a trace. ]
method what(::?CLASS:D: --> Str:D) { ... }

#|[ Produces the entries of the trace, if any. ]
method entries(::?CLASS:D: --> Iterable:D) { ... }

#|[ Whether or not the traced event died. ]
method died(::?CLASS:D: --> Bool:D) { $!exception.DEFINITE }

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
method wrap(::?CLASS:U: | --> Mu) { ... }

#|[ Keeps track of how many call frames are currently on the call stack for a
    thread. ]
my role CallStack {
    has atomicint $.call-frames is rw;
}

my atomicint $ID = 1;
#|[ Traces an event. ]
proto method trace(::?CLASS:U: |args --> Mu) is raw {
    use nqp;

    # Set up the current thread for tracing.
    my Thread:D $thread := $*THREAD;
    $thread does CallStack unless Metamodel::Primitives.is_type: $thread, CallStack;

    # Grab metadata for the trace and run the traced event. &now has too much
    # overhead to be using here, so we depend on its internals to generate
    # Num:D timestamp instead.
    my Int:D $id        := $ID⚛++;
    my Int:D $thread-id := $thread.id;
    my Int:D $calls     := $thread.call-frames⚛++;
    my Num:D $timestamp := Rakudo::Internals.tai-from-posix: nqp::time_n(), 0;
    my Mu    $result    := try {{*}};
    $thread.call-frames ⚛= $calls;

    # Output the trace.
    $*TRACER.say: self.new:
        :$id, :$thread-id, :$calls, :$timestamp,
        :$result, :exception($!),
        |args;

    # Since we wrap a traced event, rethrow any exceptions caught, returning
    # the result otherwise.
    $!.rethrow with $!;
    $result
}

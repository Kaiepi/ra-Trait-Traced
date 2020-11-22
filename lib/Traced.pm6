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
has Mu    $.result    is built(:bind) is default(Nil);
#|[ The exception thrown when running the traced event, if any. ]
has Mu    $.exception is built(:bind) is default(Nil);

#|[ Whether or not the traced event died. ]
method died(::?CLASS:D: --> Bool:D) { $!exception.DEFINITE }

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

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
method wrap(::?CLASS:U: | --> Mu) { ... }

my atomicint $ID           = 1;
my Int:D     @CALL-FRAMES;
#|[ Traces an event. ]
proto method trace(::?CLASS:U: |args --> Mu) is raw is hidden-from-backtrace {
    # We depend on &now's internals to generate a Num:D timestamp because the
    # overhead of generating an Instant:D is unacceptable here.
    use nqp;

    my Int:D $id        := $ID⚛++;
    my Int:D $thread-id := $*THREAD.id;
    my Int:D $calls     := @CALL-FRAMES[$thread-id]++;
    my Num:D $timestamp := Rakudo::Internals.tai-from-posix: nqp::time_n, 0;
    my Mu    $result    := {*};
    CATCH {
        $*TRACER.say: self.new: :$id, :$thread-id, :$calls, :$timestamp, :exception($_), |args;
        @CALL-FRAMES[$thread-id] = $calls;
        .rethrow;
    }
    $*TRACER.say: self.new: :$id, :$thread-id, :$calls, :$timestamp, :$result, |args;
    @CALL-FRAMES[$thread-id] = $calls;
    $result
}

use v6.d;
my atomicint $ID           = 1;
my Int:D     @CALL-FRAMES;
#|[ Traced wraps events to be rendered by a tracer. ]
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
has Mu    $.result    is built(:bind) is default(Nil) is rw;
#|[ The exception thrown when running the traced event, if any. ]
has Mu    $.exception is built(:bind) is default(Nil);

#|[ Whether or not the traced event died. ]
method died(::?ROLE:D: --> Bool:D) { $!exception.DEFINITE }

#|[ A trace kind name. The shortname of your Traced type is probably good
    enough. ]
method kind(::?CLASS:D: --> Str:D) { ... }

#|[ A trace type enum value. This can be used to index
    different Traced type parameterizations should there be more than one of
    these. ]
method of(::?CLASS:D: --> Enumeration:D) { ... }

#|[ Wraps events to be traced. ]
method wrap(::?CLASS:U: | --> Mu) { ... }

#|[ Generates a trace for an event. Parameters should correspond to
    arguments to eventually give to Traced.new. ]
proto method event(::?CLASS:U: |args --> Mu) is raw is hidden-from-backtrace {
    # We depend on &now's internals to generate a Num:D timestamp because the
    # overhead of generating an Instant:D is unacceptable here.
    use nqp;

    my Int:D $id        := $ID⚛++;
    my Int:D $thread-id := $*THREAD.id;
    my Int:D $calls     := @CALL-FRAMES[$thread-id]++;
    my Num:D $timestamp := Rakudo::Internals.tai-from-posix: nqp::time_n, 0;
    my Mu    $result    := {*};
    @CALL-FRAMES[$thread-id] = $calls;
    CATCH { return self.new: :$id, :$thread-id, :$calls, :$timestamp, :exception($_), |args }
    self.new: :$id, :$thread-id, :$calls, :$timestamp, :$result, |args
}

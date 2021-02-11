use v6;
my atomicint $ID           = 1;
my Int:D     @CALL-FRAMES;
#|[ Traced captures events to be rendered by a tracer. ]
unit role Traced;

#|[ The ID of the trace. ]
has Int:D       $.id        is required;
#|[ The ID of the thread the trace was taken in. ]
has Int:D       $.thread-id is required;
#|[ The (numeric) instant the trace was taken at. ]
has Num:D       $.timestamp is required;
#|[ The number of calls in the traced call stack.  ]
has Int:D       $.calls     is required;
#|[ The result of the traced event. ]
has Mu          $.result    is built(:bind) is rw;
#|[ The exception thrown when running the traced event, if any. ]
has Exception:_ $.exception is built(:bind);

#|[ Whether or not the traced event died. ]
method died(::?ROLE:D: --> Bool:D) { $!exception.DEFINITE }

#|[ The name of this kind of traced event. ]
method kind(::?CLASS:D: --> Str:D) { ... }

#|[ The type of traced event. ]
method of(::?CLASS:D: --> Enumeration:D) { ... }

#|[ Generates a trace for an event. ]
proto method capture(::?CLASS:U: *%args --> Mu) is raw is hidden-from-backtrace {
    # We depend on &now's internals to generate a Num:D timestamp because the
    # overhead of generating an Instant:D is unacceptable here.
    use nqp;

    my Int:D $id        := $ID⚛++;
    my Int:D $thread-id := $*THREAD.id;
    my Int:D $calls     := @CALL-FRAMES[$thread-id]++;
    my Num:D $timestamp := Rakudo::Internals.tai-from-posix: nqp::time_n, 0;
    my Mu    $result    := {*};
    LEAVE @CALL-FRAMES[$thread-id] = $calls;
    CATCH { return self.bless: :$id, :$thread-id, :$calls, :$timestamp, :exception($_), |%args }
    self.bless: :$id, :$thread-id, :$calls, :$timestamp, :$result, |%args
}

#|[ Wraps events to be traced. ]
proto sub TRACING(Traced, | --> Mu) is export(:TRACING) {*}

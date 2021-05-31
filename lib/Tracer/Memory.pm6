use v6;
use Concurrent::Queue;
use Traced;
use Tracee::Standard;
use Tracer;
#|[ An in-memory tracer for standard tracees backed by a concurrent queue. ]
unit role Tracer::Memory[Tracee::Standard:U ::T] does Tracer;

#|[ A standard tracee. ]
has Tracee::Standard:D  $.tracee is required;
#|[ The trace queue. ]
has Concurrent::Queue:D $!traces is required;

submethod BUILD(::?ROLE:D: Str:D :$nl is raw = $?NL --> Nil) {
    $!tracee := T.new: :$nl;
    $!traces := Concurrent::Queue.new;
}

multi method render(::?ROLE:D: Traced:D $event is raw --> True) {
    $!traces.enqueue: $!tracee.fill: $event
}

#|[ Returns a sequence of all collected traces. ]
method collect(::?ROLE:D: --> Seq:D) { $!traces.Seq }

multi method Seq(::?ROLE:D: --> Seq:D) { self.collect }

multi method list(::?ROLE:D: --> List:D) { @.collect }

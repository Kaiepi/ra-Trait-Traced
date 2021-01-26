use v6;
use Traced;
#|[ Tracers render traced events as output (typically with the help of a tracee
    type parameter). ]
unit role Tracer;

#|[ Wraps a traced event transparently, transforming any information
    collected with a tracee. ]
proto method render(::?ROLE:D: Traced:D $event is raw --> Mu:_) is raw {
    {*} orelse .exception.rethrow;
    $event.exception.rethrow if $event.died;
    $event.result
}

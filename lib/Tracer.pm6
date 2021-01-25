use v6;
use Traced;
#|[ Tracers render traced events as output. ]
unit role Tracer;

#|[ Wraps a traced event transparently, transforming any information
    collected. ]
proto method render(::?CLASS:D: Traced:D $event is raw --> Mu:_) is raw {
    {*} orelse .exception.rethrow;
    $event.exception.rethrow if $event.died;
    $event.result
}

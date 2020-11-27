use v6.d;
use Traced;
#|[ Tracers render traced events as output. ]
unit role Tracer;

#|[ Renders a traced event as output. This wraps the traced event
    transparently, so we rethrow any exceptions it made, returning
    its result otherwise. ]
proto method render(::?CLASS:D: Traced:D $event is raw --> Mu:_) is raw {
    {*} orelse .exception.rethrow;
    $event.exception.rethrow if $event.died;
    $event.result
}

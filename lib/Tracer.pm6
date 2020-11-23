use v6.d;
use Traced;
#|[ Types inheriting from this class define a format for outputting traces
    (Traced instances), providing a `say` method for outputting traces. ]
unit role Tracer;

#|[ Outputs a trace. ]
multi method say(::?CLASS:_: Traced:D --> Bool:_) { ... }

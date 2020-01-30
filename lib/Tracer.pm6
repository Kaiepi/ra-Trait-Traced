use v6.d;
use Traced;
#|[ Types inheriting from this class define a format for outputting traces
    (Traced instances), providing a `say` method for outputting traces and,
    optionally, a stringify method for stringifying trace values.]
unit class Tracer;

#|[ Stringifies a trace value. ]
proto method stringify(::?CLASS:_: Mu --> Str:D) {*}
multi method stringify(::?CLASS:_: Mu --> Str:D) { ... }

multi method say(::?CLASS:_: Traced:D --> Bool:D) { ... }

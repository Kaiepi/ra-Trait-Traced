use v6.d;
use Traced;
#|[ Types inheriting from this class define a format for outputting traces
    (Traced instances), wrapping a handle of some sort and providing a `say`
    method for outputting traces to said handle. ]
unit class Tracer;

my constant @HANDLE_METHODS = IO::Handle.^methods(:local).map(*.name).grep(* ne any '<anon>', 'say');
#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:_:) handles @HANDLE_METHODS { ... }

#|[ Stringifies a trace value. ]
proto method stringify(::?CLASS:_: Mu --> Str:D) {*}
multi method stringify(::?CLASS:_: Mu --> Str:D) { ... }

multi method say(::?CLASS:_: Traced:D --> Bool:D) { ... }

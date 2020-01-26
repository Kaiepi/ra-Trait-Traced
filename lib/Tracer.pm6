use v6.d;
use Traced;
unit class Tracer;

my constant @HANDLE_METHODS = IO::Handle.^methods(:local).map(*.name).grep(* ne any '<anon>', 'say');
#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:_:) handles @HANDLE_METHODS { ... }

#|[ Stringifies a trace value. ]
proto method stringify(::?CLASS:_: Mu --> Str:D) {*}
multi method stringify(::?CLASS:_: Mu --> Str:D) { ... }

multi method say(::?CLASS:_: Traced:D --> Bool:D) { ... }

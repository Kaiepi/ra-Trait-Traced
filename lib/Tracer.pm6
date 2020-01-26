use v6.d;
use Traced;
unit class Tracer;

my constant @HANDLE_METHODS = IO::Handle.^methods(:local).map(*.name).grep(* ne any '<anon>', 'say');
#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:U:) handles @HANDLE_METHODS { ... }

#|[ Stringifies a trace value. ]
proto method stringify(::?CLASS:U: Mu --> Str:D) {*}

multi method say(::?CLASS:U: Traced:D --> Bool:D) { ... }

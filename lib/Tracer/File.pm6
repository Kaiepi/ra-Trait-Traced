use v6;
use Traced;
use Tracee::Standard;
use Tracer;
#|[ A tracer for files following the standard format. ]
unit role Tracer::File[Tracee::Standard:U ::T] does Tracer;

#|[ A file handle. ]
has IO::Handle:D       $.handle is required;
#|[ A standard tracee. ]
has Tracee::Standard:D $.tracee is required;

submethod BUILD(::?ROLE:D: IO::Handle:D :$handle!, Str:D :$nl is raw = $handle.nl-out --> Nil) {
    $!handle := $handle<>;
    $!tracee := T.new: :$nl;
}

method new(::?ROLE:_: IO::Handle:D $handle, *%rest --> ::?ROLE:D) {
    self.bless: :$handle, |%rest
}

multi method render(::?ROLE:D: Traced:D $event is raw --> Bool:_) {
    PRE  $!handle.lock;
    POST $!handle.unlock;
    $!handle.print: $!tracee.fill: $event
}

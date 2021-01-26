use v6;
use Traced;
use Tracee::Standard;
use Tracer;
#|[ A tracer for standard streams following the standard format. ]
unit role Tracer::Stream[Tracee::Standard:_ $tracee] does Tracer;

has IO::Handle:D $.handle is required;

method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
    self.bless: :$handle
}

multi method render(::?ROLE:D: Traced:D $event is raw --> Bool:_) {
    $!handle.say: $tracee.fill: $event, :nl($!handle.nl-out)
}

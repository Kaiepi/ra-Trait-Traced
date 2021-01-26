use v6;
use Traced;
use Tracee::Bitty;
use Tracee::Pretty;
use Tracer;

#|[ A standard tracer for files with machine-readable output. ]
role Tracer::File[Tracee::Bitty ::T] does Tracer {
    has IO::Handle:D $.handle is required;

    method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
        self.bless: :$handle
    }

    multi method render(::?ROLE:D: Traced:D $event is raw --> Bool:_) {
        PRE  $!handle.lock;
        POST $!handle.unlock;
        $!handle.say: T.fill: $event, :nl($!handle.nl-out)
    }
}

#|[ A standard tracer for files with human-readable output. ]
role Tracer::File[Tracee::Pretty ::T] does Tracer {
    has IO::Handle:D $.handle is required;

    method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
        self.bless: :$handle
    }

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        PRE  $!handle.lock;
        POST $!handle.unlock;
        $!handle.say: T.fill: $event, :nl($!handle.nl-out)
    }
}

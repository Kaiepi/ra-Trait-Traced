use v6;
use Traced;
use Tracer::Standard;

#|[ A standard tracer for standard streams with machine-readable output. ]
role Tracer::Stream[Bool:D :pretty($) where !* = False] does Tracer::Standard {
    has IO::Handle:D $.handle is required;

    method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
        self.bless: :$handle
    }

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        $!handle.say: self.Str: :$event, :nl($!handle.nl-out)
    }
}

#|[ A standard tracer for standard streams with human-readable output. ]
role Tracer::Stream[Bool:D :pretty($)! where ?*] does Tracer::Standard {
    has IO::Handle:D $.handle is required;

    method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
        self.bless: :$handle
    }

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        $!handle.say: self.gist: :$event, :nl($!handle.nl-out)
    }
}

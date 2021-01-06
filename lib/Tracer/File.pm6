use v6;
use Traced;
use Tracer::Standard;

#|[ A standard tracer for files with machine-readable output. ]
role Tracer::File[Bool:D :pretty($) where !* = False] does Tracer::Standard {
    has IO::Handle:D $.handle is required;

    method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
        self.bless: :$handle
    }

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        PRE  $!handle.lock;
        POST $!handle.unlock;
        $!handle.say: self.Str: :$event, :nl($!handle.nl-out)
    }
}

#|[ A standard tracer for files with human-readable output. ]
role Tracer::File[Bool:D :pretty($)! where ?*] does Tracer::Standard {
    has IO::Handle:D $.handle is required;

    method new(::?ROLE:_: IO::Handle:D $handle --> ::?ROLE:D) {
        self.bless: :$handle
    }

    multi method render(::?CLASS:D: Traced:D $event is raw --> Bool:_) {
        PRE  $!handle.lock;
        POST $!handle.unlock;
        $!handle.say: self.gist: :$event, :nl($!handle.nl-out)
    }
}

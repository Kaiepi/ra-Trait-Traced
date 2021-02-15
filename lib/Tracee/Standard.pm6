use v6;
use Traced;
use Tracee;
#|[ A tracee that transforms traced events to the standard, stringy format for
    Trait::Traced. ]
unit role Tracee::Standard does Tracee[Str:D];

has Str:D $.nl is built(:bind) = $?NL;

#|[ Transforms a traced event to the standard format. ]
method fill(::?CLASS:D: Traced:D $e is raw --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    self.title($e, :$margin) ~
    self.header($e, :$margin) ~
    self.entries($e, :$margin).join ~
    self.footer($e, :$margin)
}

#|[ A trace's title. This contains metadata that distinguishes traces from one another. ]
method title(::?CLASS:D: Traced:D --> Str:D) { ... }

#|[ A trace's header. This represents an input of some sort. ]
method header(::?CLASS:D: Traced:D --> Str:D) { ... }

#|[ A trace's entries. This represents arguments of some sort given alongside an input. ]
method entries(::?CLASS:D: Traced:D --> Seq:D) { ... }

#|[ A trace's footers. This represents an output of some sort. ]
method footer(::?CLASS:D: Traced:D --> Str:D) { ... }

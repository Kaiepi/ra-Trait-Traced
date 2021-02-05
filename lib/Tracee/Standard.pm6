use v6;
use Traced;
use Tracee;
#|[ A tracee that transforms traced events to the standard, stringy format for
    Trait::Traced. ]
unit role Tracee::Standard does Tracee[Str:D];

# This type's fill method should include a named parameter:
#     Str:D :$nl is raw = $?NL

#|[ A trace's title. This contains metadata that distinguishes traces from one another. ]
method title(::?CLASS:_: Traced:D --> Str:D) { ... }

#|[ A trace's header. This represents an input of some sort. ]
method header(::?CLASS:_: Traced:D --> Str:D) { ... }

#|[ A trace's entries. This represents arguments of some sort given alongside an input. ]
method entries(::?CLASS:_: Traced:D --> Seq:D) { ... }

#|[ A trace's footers. This represents an output of some sort. ]
method footer(::?CLASS:_: Traced:D --> Str:D) { ... }

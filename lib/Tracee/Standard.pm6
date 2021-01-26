use v6;
use Tracee;
#|[ A tracee that transforms traced events to the standard, stringy format for
    Trait::Traced. ]
unit role Tracee::Standard does Tracee[Str:D];

# This type's fill method should include a named parameter:
#     Str:D :$nl = $?NL

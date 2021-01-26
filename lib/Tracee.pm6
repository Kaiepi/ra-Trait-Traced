use v6;
use Traced;
#|[ Tracees "fill" traces for rendering by a tracer. ]
unit role Tracee[::T];

#|[ Transforms a traced event to a format that can be output by a tracer. ]
method fill(::?CLASS:D: Traced:D --> T) { ... }

use v6;
use Traced;
#|[ Routine tracing module. ]
unit module Traced::Routine;

#|[ A type of routine trace. ]
enum Type <CALL>;

#|[ A traced routine call. ]
role Event does Traced {
    #|[ The scope the routine was declared in. ]
    has Str:D     $.scope     is required;
    #|[ The multiness of the routine (proto, multi, only). ]
    has Str:D     $.multiness is required;
    #|[ The prefix of the routine's name (!, ^). ]
    has Str:D     $.prefix    is required;
    #|[ The routine in question. ]
    has Routine:D $.routine   is required;
    #|[ The arguments of the routine call. ]
    has Capture:D $.arguments is required;

    #|[ The name of this kind of traced event. ]
    method kind(::?CLASS:D: --> 'ROUTINE') { }

    #|[ The type of traced routine event. ]
    method of(::?CLASS:D: --> CALL) { }

    #|[ The package this routine was declared in. ]
    method package(::?CLASS:D: --> Mu) { $!routine.package }

    #|[ The name of the routine as written. ]
    method name(::?CLASS:D: --> Str:D) { $!routine.name || '::' }

    #|[ The routine declaration as written. ]
    method declarator(::?CLASS:D: --> Str:D) {
        my Str:D $declarator = $!routine.^is_mixin ?? $!routine.^mixin_base.^name.lc !! $!routine.^name.lc;
        $declarator [R~]= "$!multiness " if $!multiness;
        $declarator [R~]= "$!scope " if $!scope;
        "$declarator $!prefix$.name"
    }

    #|[ An iterator mapping routine parameters to call arguments. ]
    my class ParameterToArgumentIterator does Iterator {
        has Iterator:D       $!parameters is required;
        has List:D           $!positional is required;
        has Map:D            $!named      is required;
        has Int:D            $!idx         = 0;
        has SetHash:D[Str:D] $!unseen     .= new: $!named.keys;

        submethod BUILD(::?CLASS:D: Signature:D :$signature! is raw, Capture:D :$arguments! is raw --> Nil) {
            $!parameters := $signature.params.iterator;
            $!positional := @$arguments;
            $!named      := %$arguments;
        }

        method new(::?CLASS:_: Signature:D $signature is raw , Capture:D $arguments is raw --> ::?CLASS:D) {
            self.bless: :$signature, :$arguments
        }

        method pull-one(::?CLASS:D: --> Mu) is raw {
            until ($_ := $!parameters.pull-one) =:= IterationEnd {
                when *.capture {
                    my Int:D $begin  = $!idx;
                    my Int:D $end    = $!idx := $!positional.elems;
                    my       @names := $!unseen{*}:k:delete;
                    return $_ => Capture.new:
                        list => $!positional[$begin..^$end],
                        hash => Map($!named{@names}:p);
                }
                when *.slurpy {
                    return do if .named {
                        my @names      := $!unseen{*}:k:delete;
                        my @parameters := $!named{@names}:p;
                        $_ => .raw ?? Map(@parameters) !! %(@parameters)
                    } else {
                        my Int:D $begin       = $!idx;
                        my Int:D $end         = $!idx := $!positional.elems;
                        my       @parameters := $!positional[$begin..^$end];
                        $_ => .raw ?? @parameters !! [@parameters]
                    };
                }
                when *.named {
                    for .named_names -> Str:D $name {
                        return $_ => $!named{$name} if $!named{$name}:exists and $!unseen{$name}:exists:delete;
                    }
                    # next
                }
                when *.positional {
                    return $_ => $!positional[$!idx++] if $!positional[$!idx]:exists;
                    # next
                }
            }

            IterationEnd
        }
    }

    multi method iterator(::?CLASS:D: --> Iterator:D) {
        ParameterToArgumentIterator.new: $!routine.signature, $!arguments
    }
    multi method list(::?CLASS:D: --> List:D) {
        List.from-iterator: self.iterator
    }
    multi method Seq(::?CLASS:D: --> Seq:D) {
        Seq.new: self.iterator
    }

    #|[ A sequence of parameters mapped to arguments. ]
    method parameters-to-arguments(::?CLASS:D: --> Seq:D) { self.Seq }

    multi method capture(::?CLASS:U:
        Routine:D :$routine is raw, Capture:D :$arguments is raw
    --> Mu) is raw is hidden-from-backtrace {
        $routine(|$arguments)
    }
}

#|[ Marks a traced routine. ]
my role Wrap { method is-traced(--> True) { } }

multi sub TRACING(Event:U, Wrap:D;; *%rest --> Nil) is default is export(:TRACING) { }

multi sub TRACING(Event:U, Routine:D $routine is raw;; *%rest --> Nil) is export(:TRACING) {
    use QAST:from<NQP>;

    my &fixup := { WRAP $routine, |%rest };
    $*W.add_object_if_no_sc: &fixup;
    $*W.add_fixup_task:
        deserialize_ast => QAST::Op.new(:op<call>, QAST::WVal.new(:value(&fixup))),
        fixup_ast       => QAST::Op.new(:op<call>, QAST::WVal.new(:value(&fixup)));

    $routine does Wrap;
}

multi sub TRACING(Event:U \T, Mu $wrapper is raw;; 'multi' :$multiness!, *%rest --> Nil) is export(:TRACING) {
    # Metamodel::MultiMethodContainer wraps multi routines with an internal
    # class; we need this candidate to handle those.
    samewith T, $wrapper.code, :$multiness, |%rest
}

sub WRAP(Routine:D $routine is raw, Str:D :$scope = '', Str:D :$multiness = '', Str:D :$prefix = '' --> Nil) {
    use nqp;

    my Routine:D $cloned := trait_mod:<is> nqp::clone($routine), :hidden-from-backtrace;
    my Mu        $c-do   := nqp::getattr($cloned, Code, '$!do');
    my Mu        $t-do   := nqp::getattr(&TRACED-ROUTINE, Code, '$!do');
    my str       $name    = nqp::getcodename($c-do);
    nqp::setcodeobj($c-do, $cloned);
    nqp::setcodeobj($t-do, $routine);
    nqp::setcodename($t-do, $name);
    nqp::bindattr($routine, Code, '$!do', $t-do);

    sub TRACED-ROUTINE(|arguments --> Mu) is raw is hidden-from-backtrace {
        my constant CallEvent = Event.^pun;

        $/ := nqp::getlexcaller('$/');
        $*TRACER.render: CallEvent.capture:
            routine   => $cloned,
            arguments => arguments,
            scope     => $scope,
            multiness => $multiness,
            prefix    => $prefix
    }
}

use v6.d;
use QAST:from<NQP>;
use Traced;
unit class Traced::Routine does Traced;

enum Type <CALL>;

has Str:D     $.scope     is required;
has Str:D     $.multiness is required;
has Str:D     $.prefix    is required;
has Routine:D $.routine   is required;
has Capture:D $.arguments is required;

method kind(::?CLASS:D: --> 'ROUTINE') { }

method of(::?CLASS:D: --> CALL) { }

method package(::?CLASS:D: --> Mu) { $!routine.package }

method declarator(::?CLASS:D: --> Str:D) {
    my Str:D $declarator = $!routine.^is_mixin ?? $!routine.^mixin_base.^name.lc !! $!routine.^name.lc;
    $declarator [R~]= "$!multiness " if $!multiness;
    $declarator [R~]= "$!scope "     if $!scope;
    $declarator
}

method name(::?CLASS:D: --> Str:D) { $!routine.name || '::' }

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

method parameters-to-arguments(::?CLASS:D: --> Seq:D) { self.Seq }

my role TracedRoutine {
    method is-traced(--> True) { }
}

proto method wrap(::?CLASS:U: Mu --> Nil) {*}
multi method wrap(::?CLASS:U: TracedRoutine:D --> Nil) is default { }
multi method wrap(::?CLASS:U: Routine:D $routine is raw, *%named --> Nil) {
    if $*W {
        my &fixup := { DO-WRAP $routine, |%named };
        $*W.add_object_if_no_sc: &fixup;
        $*W.add_fixup_task:
            deserialize_ast => QAST::Op.new(:op<call>, QAST::WVal.new(:value(&fixup))),
            fixup_ast       => QAST::Op.new(:op<call>, QAST::WVal.new(:value(&fixup)));
        Nil
    } else {
        DO-WRAP $routine, |%named;
    }
    $routine does TracedRoutine;
}
multi method wrap(::?CLASS:U: Mu $wrapper is raw, 'multi' :$multiness!, *%rest --> Nil) {
    # Metamodel::MultiMethodContainer wraps multi routines with an internal
    # class; we need this candidate to handle those.
    samewith $wrapper.code, :$multiness, |%rest
}

sub DO-WRAP(Routine:D $routine is raw, Str:D :$scope = '', Str:D :$multiness = '', Str:D :$prefix = '' --> Nil) {
    use nqp;

    my Routine:D $cloned := trait_mod:<is> nqp::clone($routine), :hidden-from-backtrace;
    my Mu        $c-do   := nqp::getattr($cloned, Code, '$!do');
    my Mu        $t-do   := nqp::getattr(&TRACED-ROUTINE, Code, '$!do');
    my str       $name    = nqp::getcodename($c-do);
    nqp::setcodeobj($c-do, $cloned);
    nqp::setcodeobj($t-do, $routine);
    nqp::setcodename($t-do, $name);
    nqp::bindattr($routine, Code, '$!do', $t-do);
    if $*W {
        $*W.add_object_if_no_sc: $cloned;
        $*W.add_object_if_no_sc: &TRACED-ROUTINE;
    }

    sub TRACED-ROUTINE(|arguments --> Mu) is raw is hidden-from-backtrace {
        $/ := nqp::getlexcaller('$/');
        $*TRACER.render: Traced::Routine.event:
            routine   => $cloned,
            arguments => arguments,
            scope     => $scope,
            multiness => $multiness,
            prefix    => $prefix
    }
}

multi method event(::?CLASS:U:
    Routine:D :$routine is raw, Capture:D :$arguments is raw
--> Mu) is raw is hidden-from-backtrace {
    $routine(|$arguments)
}

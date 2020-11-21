use v6.d;
use QAST:from<NQP>;
use Traced;
unit class Traced::Routine does Traced;

has Routine:D $.routine   is required;
has Capture:D $.arguments is required;
has Str:D     $.scope     = '';
has Str:D     $.multiness = '';
has Str:D     $.prefix    = '';

method new(::?CLASS:_: Routine:D  $routine is raw, Capture:D $arguments is raw, *%rest --> ::?CLASS:D) {
    self.bless: :$routine, :$arguments, |%rest
}

method colour(::?CLASS:D: --> 31)          { }
method category(::?CLASS:D: --> 'ROUTINE') { }
method type(::?CLASS:D: --> 'CALL')        { }

method package(::?CLASS:D: --> Mu) { $!routine.package.^name }

method declarator(::?CLASS:D: --> Str:D)  {
    my Str:D $declarator = $!routine.^is_mixin ?? $!routine.^mixin_base.^name.lc !! $!routine.^name.lc;
    $declarator [R~]= "$!multiness " if $!multiness;
    $declarator [R~]= "$!scope "     if $!scope;
    $declarator
}

method name(::?CLASS:D: --> Str:D) { $!routine.name || '::' }

multi method what(::?CLASS:D: --> Str:D) { "$.declarator $!prefix$.name ($.package)" }

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather for self -> Pair:D (Parameter:D :key($parameter), Mu :value($argument) is raw) {
        # TODO: This regex will no longer be necessary in v6.e, due to the
        # existence of the new Parameter.prefix and Parameter.suffix methods.
        my Str:D $name = ~$parameter.raku.match: / ^ [ '::' \S+ \s ]* [ \S+ \s ]? <(\S+)> /;
        once $name = 'self' if $parameter.invocant && !$parameter.name;
        take $name => $argument;
    }
}

my class ParameterToArgumentIterator does Iterator {
    has Iterator:D       $!parameters is required;
    has List:D           $!positional is required;
    has Map:D            $!named      is required;
    has Int:D            $!idx         = 0;
    has SetHash:D[Str:D] $!unseen     .= new: $!named.keys;

    submethod BUILD(::?CLASS:D: Signature:D :$signature!, Capture:D :$arguments! --> Nil) {
        $!parameters := $signature.params.iterator;
        $!positional := @$arguments;
        $!named      := %$arguments;
    }

    method new(::?CLASS:_: Signature:D $signature, Capture:D $arguments --> ::?CLASS:D) {
        self.bless: :$signature, :$arguments
    }

    method pull-one(::?CLASS:D: --> Mu) is raw {
        until ($_ := $!parameters.pull-one) =:= IterationEnd {
            when .capture {
                return $_ => Capture.new:
                    list => $!positional[(my Int:D $ = $!idx)..^($!idx = +$!positional)],
                    hash => %($!named{$!unseen{*}:k:delete}:p);
            }
            when .slurpy {
                if .named {
                    return $_ => %($!named{$!unseen{*}:k:delete}:p)
                } else {
                    return $_ => $!positional[(my Int:D $ = $!idx)..^($!idx = +$!positional)];
                }
            }
            when .named {
                if $!unseen{.named_names // ()}:k:delete.grep: *.defined -> [Str:D $named-name, **@unacceptable] {
                    return $_ => $!named{$named-name} unless @unacceptable;
                } # else next
            }
            when .positional {
                if $!positional[$!idx]:exists {
                    return $_ => $!positional[$!idx++];
                } # else next
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

multi method wrap(::?CLASS:U: Routine:D $routine is raw, *%named --> Nil) {
    WRAP $routine, |%named
}
# Metamodel::MultiMethodContainer wraps multi routines with an internal class;
# we need another candidate to handle these.
multi method wrap(::?CLASS:U: Mu $wrapper is raw, 'multi' :$multiness! --> Nil) {
    WRAP $wrapper.code, :$multiness
}

proto sub WRAP(&, *% --> Nil) {*}
multi sub WRAP(TracedRoutine, *%) { #`[ Already wrapped; nothing doing. ] }
multi sub WRAP(&routine is raw, Str:D :$scope = '', Str:D :$multiness = '', Str:D :$prefix = '') {
    if $*W {
        my &fixup := { DO-WRAP &routine, :$scope, :$multiness, :$prefix };
        $*W.add_object_if_no_sc: &fixup;
        $*W.add_fixup_task:
            deserialize_ast => QAST::Op.new(:op<call>, QAST::WVal.new(:value(&fixup))),
            fixup_ast       => QAST::Op.new(:op<call>, QAST::WVal.new(:value(&fixup)));
        Nil
    } else {
        DO-WRAP &routine, :$scope, :$multiness, :$prefix;
    }
    &routine does TracedRoutine;
}

sub DO-WRAP(&routine is raw, Str:D :$scope!, Str:D :$multiness!, Str:D :$prefix! --> Nil) {
    use nqp;

    my     &cloned := nqp::clone(&routine);
    my Mu  $c-do   := nqp::getattr(&cloned, Code, '$!do');
    my Mu  $t-do   := nqp::getattr(&TRACED-ROUTINE, Code, '$!do');
    my str $name    = nqp::getcodename($c-do);
    nqp::setcodeobj($c-do, &cloned);
    nqp::setcodeobj($t-do, &routine);
    nqp::setcodename($t-do, $name);
    nqp::bindattr(&routine, Code, '$!do', $t-do);
    if $*W {
        $*W.add_object_if_no_sc: &cloned;
        $*W.add_object_if_no_sc: &TRACED-ROUTINE;
    }

    sub TRACED-ROUTINE(|arguments --> Mu) is raw is hidden-from-backtrace {
        $/ := nqp::getlexcaller('$/');
        Traced::Routine.trace: &cloned, arguments, :$scope, :$multiness, :$prefix
    }
}

multi method trace(::?CLASS:U: &routine, Capture:D \arguments --> Mu) is raw {
    routine |arguments
}

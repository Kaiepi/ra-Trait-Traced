use v6.d;
use QAST:from<NQP>;
use Traced;
unit class Traced::Routine is Traced;

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
    gather for @.parameters-to-arguments -> Pair:D (Parameter:D :key($parameter), Mu :value($argument) is raw) {
        my Str:D $name = ~$parameter.raku.match: / ^ [ '::' \S+ \s ]* [ \S+ \s ]? <(\S+)> /;
        once $name = 'self' if $parameter.invocant && !$parameter.name.defined;
        take $name => $argument;
    }
}

method parameters-to-arguments(::?CLASS:D: --> Seq:D) {
    gather {
        my Mu               @positional  = $!arguments.list;
        my Int:D            $idx         = 0;
        my Int:D            $total       = +@positional;
        my Mu               %named       = $!arguments.hash;
        my SetHash:D[Str:D] $unseen     .= new: %named.keys;
        for $!routine.signature.params {
            when .capture {
                my Str:D @remaining = $unseen.keys;
                take $_ => \(|($idx < $total ?? @positional[$idx..$total-1] !! ()), |%(%named{@remaining}:p));
                $idx = $total;
                $unseen{@remaining}:delete;
            }
            when .slurpy {
                if .named {
                    my Str:D @remaining = $unseen.keys;
                    take $_ => %(%named{@remaining}:p);
                    $unseen{@remaining}:delete;
                } else {
                    take $_ => $idx < $total ?? @positional[$idx..$total-1] !! ();
                    $idx = $total;
                }
            }
            when .named {
                my Str:D $name = .usage-name;
                if $unseen{$name}:exists {
                    take $_ => %named{$name};
                    $unseen{$name}:delete;
                }
            }
            when .positional {
                take $_ => @positional[$idx++] unless $idx == $total;
            }
        }
    }
}

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

sub WRAP(&routine is raw, Str:D :$scope = '', Str:D :$multiness = '', Str:D :$prefix = '' --> Nil) {
    my role TracedRoutine { method is-traced(--> True) { } }

    return if &routine ~~ TracedRoutine;
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

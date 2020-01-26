use v6.d;
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

method name(::?CLASS:D: --> Str:D) { $!routine.name }

multi method what(::?CLASS:D: --> Str:D) { "$.declarator $!prefix$.name ($.package)" }

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather for @.parameters-to-arguments -> Pair:D (Parameter:D :key($parameter), Mu :value($argument) is raw) {
        my Str:D $name = ~$parameter.perl.match: / ^ [ '::' \S+ \s ]* [ \S+ \s ]? <(\S+)> /;
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

# You would think Routine.wrap would be useful here, but Rakudo often expects
# routines to be Code instances, and this is no longer the case after wrapping
# a routine this way. This will get a bit ugly!
multi method wrap(
    ::?CLASS:U:
    Routine:D $routine is raw,
    Str:D     :$scope     = '',
    Str:D     :$multiness = '',
    Str:D     :$prefix    = ''
    --> Mu
) {
    use nqp;
    return if $routine.?is-traced;

    # The same logic that's used for NativeCall's "is native" trait is used
    # here. There's some extra work we need to do if this is being called
    # at compile-time:
    with $*W {
        # Finish compiling the routine...
        my Mu $compstuff := nqp::getattr($routine, Code, '@!compstuff');
        $compstuff[1]() with $compstuff;
        # ...and prevent the compiler from undoing the changes we're about to
        # make:
        my str $cuid = nqp::getcodecuid(nqp::getattr($routine, Code, '$!do'));
        nqp::deletekey($*W.context.sub_id_to_code_object, $cuid);
    }

    # Override the routine's code with its traced version's code:
    my Routine:D $traced := MAKE-TRACED-ROUTINE $routine.clone, :$scope, :$multiness, :$prefix;
    my Str:D     $name    = $routine.name;
    my Mu        $do     := nqp::getattr($traced, Code, '$!do');
    nqp::bindattr($routine, Code, '$!do', $do);
    nqp::setcodename($do, $name);
    $routine does role { method is-traced(::?CLASS:D: --> True) { } }
}
# Metamodel::MultiMethodContainer wraps multi routines with an internal class;
# we need another candidate to handle these.
multi method wrap(::?CLASS:U: Mu $wrapper is raw, 'multi' :$multiness! --> Mu) {
    use nqp;
    return if $wrapper.code.?is-traced;

    my Routine:D $tracer := MAKE-TRACED-ROUTINE $wrapper.code, :$multiness;
    nqp::bindattr($wrapper, $wrapper.WHAT, '$!code', $tracer);
    $tracer does role { method is-traced(::?CLASS:D: --> True) { } }
}
sub MAKE-TRACED-ROUTINE(&routine is raw, Str:D :$scope = '', Str:D :$multiness = '', Str:D :$prefix = '' --> Sub:D) {
    sub TRACED-ROUTINE(|arguments --> Mu) is raw {
        Traced::Routine.trace: &routine, arguments, :$scope, :$multiness, :$prefix
    }
}

multi method trace(::?CLASS:U: &routine, Capture:D \arguments --> Mu) is raw {
    routine |arguments
}

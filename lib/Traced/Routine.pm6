use v6.d;
use Traced;
unit class Traced::Routine does Traced;

role Proto {
    method declarator(::?CLASS:D: --> Str:D) { 'proto ' ~ callsame }
}
role Multi {
    method declarator(::?CLASS:D: --> Str:D) { 'multi ' ~ callsame }
}

has Routine:D $.routine   is required;
has Capture:D $.arguments is required;

has Int:D            $!idx     = 0;
has SetHash:D[Str:D] $!unseen .= new: $!arguments.hash.keys;

method new(::?CLASS:_: Routine:D $routine is raw, Capture:D $arguments is raw --> ::?CLASS:D) {
    self.bless: :$routine, :$arguments
}

method parameters(::?CLASS:D: --> List:D) { $!routine.signature.params }
method name(::?CLASS:D: --> Str:D)        { $!routine.name }
method package(::?CLASS:D: --> Mu)        { $!routine.package.^name }
method declarator(::?CLASS:D: --> Str:D)  {
    my Mu $base := $!routine.^is_mixin ?? $!routine.^mixin_base !! $!routine.WHAT;
    $base.^name.lc
}

multi method wrap(::?CLASS:U: Routine:D $routine is raw --> Mu) {
    $routine.wrap: &TRACED-ROUTINE
}
sub TRACED-ROUTINE(|arguments --> Mu) is raw {
    $?CLASS.new(nextcallee, arguments).trace
}

multi method wrap(::?CLASS:U: Routine:D $routine is raw where *.is_dispatcher --> Mu) {
    $routine.wrap: &TRACED-PROTO-ROUTINE
}
sub TRACED-PROTO-ROUTINE(|arguments --> Mu) is raw {
    $?CLASS.^mixin(Proto).new(nextcallee, arguments).trace
}

# Rakudo expects multi routines to be Code instances (which is no longer the
# case for routines after they've been wrapped) so we can't deal with them the
# same way we have been so far. This will get a bit ugly!
multi method wrap(::?CLASS:U: Routine:D $routine is raw, Bool:D :$multi! where ?* --> Mu) {
    use nqp;

    # The same logic that's used for NativeCall's "is native" trait is used
    # here. There's some extra work we need to do if this is being called
    # at compile-time:
    if DYNAMIC::<$*W>:exists {
        # Finish compiling the routine...
        nqp::getattr($routine, Code, '@!compstuff')[1]();
        # ...and prevent the compiler from undoing the changes we're about to
        # make:
        my str $cuid = nqp::getcodecuid(nqp::getattr($routine, Code, '$!do'));
        nqp::deletekey($*W.context.sub_id_to_code_object, $cuid);
    }

    # Override the routine's code with its traced version's code:
    my Routine:D $traced := MAKE-TRACED-MULTI-ROUTINE $routine.clone;
    my Mu        $do     := nqp::getattr($traced, Code, '$!do');
    nqp::bindattr($routine, Code, '$!do', $do);
    nqp::setcodename($do, $routine.name);
}
# Metamodel::MultiMethodContainer wraps multi routines with an internal class;
# we need another candidate to handle these.
multi method wrap(::?CLASS:U: Mu $wrapper is raw, Bool:D :$multi! where ?* --> Mu) {
    use nqp;
    my Routine:D $tracer := MAKE-TRACED-MULTI-ROUTINE $wrapper.code;
    nqp::bindattr($wrapper, $wrapper.WHAT, '$!code', $tracer);
}
sub MAKE-TRACED-MULTI-ROUTINE(Routine:D $routine is raw --> Sub:D) {
    sub TRACED-MULTI-ROUTINE(|arguments --> Mu) is raw {
        $?CLASS.^mixin(Multi).new($routine, arguments).trace
    }
}

proto method parameter-to-argument(::?CLASS:D: Parameter:D --> Mu) {*}
multi method parameter-to-argument(::?CLASS:D: Parameter:D $ where { .capture } --> Capture:D) {
    my Str:D @remaining = $!unseen.keys;
    LEAVE {
        $!idx = +$!arguments;
        $!unseen{@remaining}:delete;
    }
    \(|($!idx < +$!arguments.list ?? $!arguments.list[$!idx..*] !! ()),
      |%($!arguments.hash{@remaining}:p // ()))
}
multi method parameter-to-argument(::?CLASS:D: Parameter:D $ where { .slurpy & .named } --> Hash:D[Mu]) {
    my Str:D @remaining = $!unseen.keys;
    LEAVE $!unseen{@remaining}:delete;
    %($!arguments.hash{@remaining}:p // ())
}
multi method parameter-to-argument(::?CLASS:D: Parameter:D $ where { .slurpy } --> List:D) {
    LEAVE $!idx = +$!arguments;
    $!idx < +$!arguments.list ?? $!arguments.list[$!idx..*] !! ()
}
multi method parameter-to-argument(::?CLASS:D: Parameter:D $parameter where { .named } --> Mu) {
    LEAVE $!unseen.hash{$parameter.usage-name}:delete;
    $!arguments.hash{$parameter.usage-name}
}
multi method parameter-to-argument(::?CLASS:D: Parameter:D $ where { .positional } --> Mu) {
    $!arguments.list[$!idx++]
}

multi method trace(::?CLASS:D: --> Mu) is raw {
    my Mu \result = try $!routine.(|$!arguments);
    $*TRACER.say: gather {
        my Bool:D $colour = $*TRACER.t;
        my Str:D  $format = $colour ?? "\e[1;31m[CALL]\e[0m \e[1m(%s) %s %s\e[0m" !! "[CALL] (%s) %s %s";
        take sprintf $format, $.package, $.declarator, $.name;

        $format = $colour ?? "\e[1m%s\e[0m:%s %s" !! "%s:%s %s";
        my Pair:D @params = @.parameters.map({
            my Str:D $parameter = ~.gist.match: / ^ [ '::' \S+ \s ]* [ \S+ \s ]? <(\S+)> /;
            my Str:D $argument  = self.parameter-to-argument($_).gist;
            once $parameter = 'self' if .invocant && !.name.defined;
            $parameter => $argument
        });
        my Int:D  $width  = @params ?? @params.map(*.key.chars).max !! 0;
        for @params -> Pair:D (Str:D :key($parameter), Str:D :value($argument)) {
            my Str:D $padding = ' ' x $width - $parameter.chars;
            take sprintf $format, $parameter, $padding, $argument;
        }

        with $! {
            $format = $colour ?? "\e[1m!!!\e[0m %s" !! "!!! %s";
            take sprintf $format, $!.^name;
        } else {
            $format = $colour ?? "\e[1m-->\e[0m %s" !! "--> %s";
            take sprintf $format, result.gist;
        }
    }.map({ self!indent: $_ }).join($?NL);
    $!.rethrow with $!;
    result
}

use v6.d;
use Traced;
unit class Traced::Routine does Traced;

has Routine:D $.routine   is required;
has Capture:D $.arguments is required;
has Mu        $.result    is required;
has Mu        $.exception is required;
has Bool:D    $.multi     is required;

multi method wrap(::?CLASS:U: Routine:D $routine is raw --> Mu) {
    $routine.wrap: &TRACED-ROUTINE
}
sub TRACED-ROUTINE(|arguments --> Mu) is raw {
    my Routine:D $routine := nextcallee;
    $?CLASS!protect({
        my Instant:D $moment = ENTER now;
        my Mu        \result = try $routine.(|arguments);
        LEAVE $?CLASS.trace: $routine, arguments, result, $!, :$moment;
        $!.rethrow with $!;
        result
    })
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
        $?CLASS!protect({
            my Instant:D $moment = ENTER now;
            my Mu        \result = try $routine.(|arguments);
            LEAVE $?CLASS.trace: $routine, arguments, result, $!, :multi, :$moment;
            $!.rethrow with $!;
            result
        })
    }
}

method colour(::?CLASS:_: --> 31)  { }
method key(::?CLASS:_: --> 'CALL') { }

method new(
    ::?CLASS:_:
    Routine:D  $routine   is raw,
    Capture:D  $arguments is raw,
    Mu         $result    is raw,
    Mu         $exception is raw,
    Bool:D    :$multi     = False,
              *%rest
    --> ::?CLASS:D
) {
    self.bless:
        :$routine, :$arguments, :$result, :$exception, :$multi,
        |%rest
}

method package(::?CLASS:D: --> Mu) { $!routine.package.^name }

method declarator(::?CLASS:D: --> Str:D)  {
    my Mu $base := $!routine.^is_mixin ?? $!routine.^mixin_base !! $!routine.WHAT;
    $!routine.is_dispatcher
        ?? 'proto ' ~ $base.^name.lc
        !! $!multi
            ?? 'multi ' ~ $base.^name.lc
            !! $base.^name.lc
}

method name(::?CLASS:D: --> Str:D) { $!routine.name }

method parameters(::?CLASS:D: --> List:D) { $!routine.signature.params }

method arguments-from-parameters(::?CLASS:D: --> Seq:D) {
    gather {
        my Mu               @positional  = $!arguments.list;
        my Mu               %named       = $!arguments.hash;
        my Int:D            $idx         = 0;
        my SetHash:D[Str:D] $unseen     .= new: %named.keys;
        for @.parameters {
            when .capture {
                my Str:D @remaining = $unseen.keys;
                take \(|($idx < +@positional ?? @positional[$idx..*] !! ()),
                       |%(%named{@remaining}:p // ()));
                $idx = +@positional;
                $unseen{@remaining}:delete;
            }
            when .slurpy & .named {
                my Str:D @remaining = $unseen.keys;
                take %(%named{@remaining}:p // ());
                $unseen{@remaining}:delete;
            }
            when .slurpy {
                take $idx < +@positional ?? @positional[$idx..*] !! ();
                $idx = +@positional;
            }
            when .named {
                my Str:D $name = .usage-name;
                take %named{$name};
                %named{$name}:delete;
            }
            when .positional {
                take @positional[$idx++]
            }
        }
    }
}

method success(::?CLASS:D: --> Bool:D) { ! $!exception.DEFINITE }

multi method header(::?CLASS:D: --> Str:D) {
    sprintf "(%s) %s %s", $.package, $.declarator, $.name
}

multi method entries(::?CLASS:D: --> Seq:D) {
    gather for @.parameters Z=> @.arguments-from-parameters {
        my Str:D $parameter = ~.key.gist.match: / ^ [ '::' \S+ \s ]* [ \S+ \s ]? <(\S+)> /;
        my Str:D $argument  = .value.gist;
        once $parameter = 'self' if .key.invocant && !.key.name.defined;
        take $parameter => $argument;
    }
}

multi method footer(::?CLASS:D: --> Str:D) {
    $!exception.DEFINITE
        ?? $!exception.^name
        !! $!result.gist
}

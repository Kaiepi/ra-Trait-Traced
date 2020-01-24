use v6.d;
use Traced;
unit class Traced::Routine is Traced;

has Routine:D $.routine   is required;
has Capture:D $.arguments is required;
has Mu        $.result    is required;
has Mu        $.exception is required;
has Str:D     $.scope     = '';
has Str:D     $.multiness = '';
has Str:D     $.prefix    = '';

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
        my Int:D     $id        := Traced::Routine.next-id;
        my Thread:D  $thread    := $*THREAD;
        my Int:D     $calls     := Traced::Routine.increment-calls: $thread;
        my Instant:D $timestamp := now;
        my Mu        \result    := try routine |arguments;
        Traced::Routine.decrement-calls: $thread;
        Traced::Routine.trace:
            &routine, arguments, result, $!,
            :$id, :thread-id($thread.id), :$timestamp, :$calls,
            :$scope, :$multiness, :$prefix;
        $!.rethrow with $!;
        result
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
              *%rest
    --> ::?CLASS:D
) {
    self.bless:
        :$routine, :$arguments, :$result, :$exception,
        |%rest
}

method package(::?CLASS:D: --> Mu) { $!routine.package.^name }

method declarator(::?CLASS:D: --> Str:D)  {
    my Str:D $declarator = $!routine.^is_mixin ?? $!routine.^mixin_base.^name.lc !! $!routine.^name.lc;
    $declarator [R~]= "$!multiness " if $!multiness;
    $declarator [R~]= "$!scope "     if $!scope;
    $declarator
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
    "($.package) $.declarator $!prefix$.name"
}

multi method entries(::?CLASS:D: Bool:D :$tty! --> Seq:D) {
    gather {
        my Str:D $method = $tty ?? 'gist' !! 'perl';
        for @.parameters Z=> @.arguments-from-parameters {
            my Str:D $parameter = ~.key."$method"().match: / ^ [ '::' \S+ \s ]* [ \S+ \s ]? <(\S+)> /;
            my Str:D $argument  = .value."$method"();
            once $parameter = 'self' if .key.invocant && !.key.name.defined;
            take $parameter => $argument;
        }
    }
}

multi method footer(::?CLASS:D: Bool:D :$tty! --> Str:D) {
    $!exception.DEFINITE
        ?? $!exception.^name
        !! $tty
            ?? $!result.gist
            !! $!result.perl
}

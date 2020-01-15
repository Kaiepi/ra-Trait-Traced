use v6.d;
use Test;
use Traced::Routine;
use Trait::Traced;

plan 2;

subtest 'mapping parameters to arguments', {
    plan 5;

    sub make-is-arg(&routine, Capture:D $arguments is raw --> Sub:D) {
        my Traced::Routine:D $traced .= new: &routine, $arguments;
        sub is-arg(Int:D $idx, Mu $expected is raw, Str:D $message) {
            my Mu $got := $traced.parameter-to-argument($traced.parameters.[$idx]);
            my    &cmp  = $expected ~~ Positional | Associative | Capture ?? &[eqv] !! &[===];
            cmp-ok $got, &cmp, $expected, $message;
        }
    }

    my Capture:D $args   := \(1, 2, 3, :4foo, :5bar, :6baz);
    my           &is-arg;

    &is-arg = make-is-arg sub (|foo) { }, $args;
    is-arg 0, $args, 'capture parameters get mapped OK';

    &is-arg = make-is-arg sub (*@foo, *%bar) { }, $args;
    is-arg 0, $args.List, 'slurpy positional parameters get mapped OK';
    is-arg 1, $args.Hash, 'slurpy named parameters get mapped OK';

    &is-arg = make-is-arg sub ($foo, :$bar, |) { }, $args;
    is-arg 0, $args[0],   'positional parameters get mapped OK';
    is-arg 1, $args<bar>, 'named parameters get mapped OK';
};

subtest 'tracing', {
    sub wrap-tests(&block) {
        my Str:D      $filename  = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
        my IO::Pipe:D $*TRACER  := $*TMPDIR.child($filename).open(:w);
        LEAVE {
            $*TRACER.close;
            $*TRACER.path.unlink;
        }
        block
    }

    plan 11;

    wrap-tests {
        lives-ok {
            sub traced($foo) is traced { $foo }(1)
        }, 'traced subroutines do not throw while tracing...';
        ok $*TRACER.path.slurp, '...and produce output';
    };

    wrap-tests {
        lives-ok {
            my method traced() is traced { self }(1)
        }, 'traced methods do not throw while tracing...';
        ok $*TRACER.path.slurp, '...and produce output';
    };

    wrap-tests {
        lives-ok {
            proto sub multi-sub() is traced {*}
            multi sub multi-sub()           { }
            multi-sub
        }, 'traced proto routines do not throw while tracing...';
        ok $*TRACER.path.slurp, '...and produce output';
    };

    wrap-tests {
        lives-ok {
            proto sub multi-sub() {*}
            multi sub multi-sub() is traced { }
            multi-sub
        }, 'traced multi routines do not throw while tracing...';
        ok $*TRACER.path.slurp, '...and produce output';
    };

    wrap-tests {
        dies-ok {
            sub throws() is traced { die }()
        }, 'traced routines rethrow exceptions...';
        ok $*TRACER.path.slurp, '...but still produce output';
    };

    wrap-tests {
        lives-ok {
            sub classified(--> Str:D) is raw is traced {
                state Str:D $info = 'DIBU DUBU DABA LUBA DABA DU DA BI JI KI CBLABLALABLALAB ITS A SECRET';
                Proxy.new:
                    FETCH => sub FETCH($ --> '[REDACTED]')         { },
                    STORE => sub STORE($, Str:D $update --> Str:D) { $info = $update }
            }() ~= ' PABUDUBU CIBUDU PAPABU CIBUDUD PAPUBABU CIBUBU BLULULU BLULULU';
        }, 'traced routines handle containers OK';
    };
}

# vim: ft=perl6 sw=4 ts=4 sts=4 et

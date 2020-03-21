use v6.d;
use Test;
use Traced;
use Traced::Routine;
use Tracer::Default;
use Trait::Traced;

plan 2;

subtest 'mapping parameters to arguments', {
    plan 5;

    sub make-is-arg(&routine, Capture:D $arguments is raw --> Sub:D) {
        my Mu @params-to-args = do {
            my Traced::Routine:D $traced .= new:
                &routine, $arguments,
                id => 0, thread-id => $*THREAD.id, timestamp => now.Num, calls => $++,
                result => (try routine |$arguments), exception => $!;
            $traced.parameters-to-arguments
        };
        sub is-arg(Int:D $idx, Mu $expected is raw, Str:D $message) {
            my Mu $got := @params-to-args[$idx].value;
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
        my Str:D $filename = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
        my $*TRACER := Tracer::Default[$*TMPDIR.child($filename).open: :w];
        LEAVE {
            $*TRACER.handle.close;
            $*TRACER.handle.path.unlink;
        }
        block
    }

    plan 25;

    wrap-tests {
        lives-ok {
            sub traced($foo) is traced { $foo }(1)
        }, 'traced subroutines do not throw while tracing...';
        $*TRACER.handle.flush;
        ok $*TRACER.handle.path.slurp(:close), '...and produce output';
    };

    wrap-tests {
        lives-ok {
            my method traced() is traced { self }(1)
        }, 'traced methods do not throw while tracing...';
        $*TRACER.handle.flush;
        ok $*TRACER.handle.path.slurp(:close), '...and produce output';
    };

    wrap-tests {
        lives-ok {
            proto sub multi-sub() is traced {*}
            multi sub multi-sub()           { }
            multi-sub
        }, 'traced proto routines do not throw while tracing...';
        $*TRACER.handle.flush;
        ok (my Str:D $output = $*TRACER.handle.path.slurp(:close)), '...and produce output...';
        cmp-ok $output, '~~', / proto /, '...which contains "proto"';
    };

    wrap-tests {
        lives-ok {
            proto sub multi-sub()           {*}
            multi sub multi-sub() is traced { }
            multi-sub
        }, 'traced multi routines do not throw while tracing...';
        $*TRACER.handle.flush;
        ok (my Str:D $output = $*TRACER.handle.path.slurp(:close)), '...and produce output...';
        cmp-ok $output, '~~', / multi /, '...which contains "multi"';
    };

    wrap-tests {
        lives-ok {
            proto sub multi-sub() is traced {*}
            multi sub multi-sub() is traced { }
            multi-sub;
        }, 'a combination of traced proto and multi routines do not throw while tracing...';
        $*TRACER.handle.flush;
        ok (my Str:D $output = $*TRACER.handle.path.slurp(:close)), '...and produce output...';
        cmp-ok $output, '~~', / proto /, '...which contains "proto"...';
        cmp-ok $output, '~~', / multi /, '...as well as "multi"';
    };

    wrap-tests {
        dies-ok {
            sub throws() is traced { die }()
        }, 'traced routines rethrow exceptions...';
        $*TRACER.handle.flush;
        ok $*TRACER.handle.path.slurp(:close), '...but still produce output';
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

    wrap-tests {
        sub foo is traced { }();
        $*TRACER.handle.flush;
        ok $*TRACER.handle.path.slurp(:close) ~~ / <after '<== '> 'sub foo' » /,
          'unscoped routines have the correct declarator';
    };

    wrap-tests {
        my sub foo is traced { }();
        $*TRACER.handle.flush;
        ok $*TRACER.handle.path.slurp(:close) ~~ / <after '<== '> 'my sub foo' » /,
          'scoped routines have the correct declarator';
    };

    wrap-tests {
        lives-ok {
            my class Foo {
                method ^foo(\this) is traced { this.foo }
                proto method foo is traced {*}
                multi method foo is traced { self!foo }
                method !foo is traced { foo self }
                my method foo is traced { 1 }
            }.^foo
        }, 'can trace the various types of methods a class can contain...';
        $*TRACER.handle.flush;

        my Str:D $result = $*TRACER.handle.IO.slurp: :close;
        ok $result ~~ / <after '<== '> 'proto method foo' » /,
          '...and trace output includes regular methods...';
        ok $result ~~ / <after '<== '> 'multi method foo' » /,
          '...multi methods...';
        ok $result ~~ / <after '<== '> 'method !foo' » /,
          '...private methods...';
        ok $result ~~ / <after '<== '> 'method ^foo' » /,
          '...metamethods...';
        ok $result ~~ / <after '<== '> 'my method foo' » /,
          '...and scoped methods';
    };
}

# vim: ft=perl6 sw=4 ts=4 sts=4 et

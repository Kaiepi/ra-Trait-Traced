use v6;
use lib $?FILE.IO.sibling: 'lib';
use Traced::Routine;
use Trait::Traced;
use Test;
use Test::Trait::Traced;

plan 2;

subtest 'mapping parameters to arguments', {
    plan 6;

    sub make-is-arg(&routine, Capture:D $arguments is raw --> Sub:D) {
        my Traced::Routine::Event:D $traced .= capture:
            scope     => '',
            multiness => '',
            prefix    => '',
            routine   => &routine,
            arguments => $arguments;
        my @params-to-args := @$traced;
        sub is-arg(Int:D $idx, Mu $expected is raw, Str:D $message) {
            my Mu $got := @params-to-args[$idx].value;
            cmp-ok $got, &[~~], $expected, $message;
        }
    }

    my Capture:D $args   := \(1, 2, 3, :4foo, :5bar, :6baz);
    my           &is-arg  = make-is-arg sub (|foo) { }, $args;
    is-arg 0, $args, 'capture parameters get mapped OK';

    &is-arg = make-is-arg sub (*@foo, *%bar) { }, $args;
    is-arg 0, $args.List, 'slurpy positional parameters get mapped OK';
    is-arg 1, $args.Hash, 'slurpy named parameters get mapped OK';

    &is-arg = make-is-arg sub ($foo, :$bar, :foo($qux), |) { }, $args;
    is-arg 0, $args[0],   'positional parameters get mapped OK';
    is-arg 1, $args<bar>, 'named parameters get mapped OK...';
    is-arg 2, $args<foo>, '...even if they are aliased';
};

subtest 'tracing', {
    plan 26;

    trace {
        lives-ok {
            sub traced($foo) is traced { $foo }(1)
        }, 'traced subroutines do not throw while tracing...';
    }, {
        ok $^output, '...and produce output';
    };

    trace {
        lives-ok {
            my method traced() is traced { self }(1)
        }, 'traced methods do not throw while tracing...';
    }, {
        ok $^output, '...and produce output';
    };

    trace {
        lives-ok {
            proto sub multi-sub() is traced { {*}; Nil }
            multi sub multi-sub()           { }
            multi-sub
        }, 'traced proto routines do not throw while tracing...';
    }, {
        ok $^output, '...and produce output...';
        ok $^output ~~ / proto /, '...which contains "proto"';
    };

    trace {
        lives-ok {
            proto sub multi-sub()           {*}
            multi sub multi-sub() is traced { }
            multi-sub
        }, 'traced multi routines do not throw while tracing...';
    }, {
        ok $^output, '...and produce output...';
        ok $^output ~~ / multi /, '...which contains "multi"';
    };

    trace {
        lives-ok {
            proto sub multi-sub() is traced { {*} }
            multi sub multi-sub() is traced { }
            multi-sub;
        }, 'a combination of traced proto and multi routines do not throw while tracing...';
    }, {
        ok $^output, '...and produce output...';
        ok $^output ~~ / proto /, '...which contains "proto"...';
        ok $^output ~~ / multi /, '...as well as "multi"';
    };

    trace {
        dies-ok {
            sub throws() is traced { die }()
        }, 'traced routines rethrow exceptions...';
    }, {
        ok $^output, '...but still produce output';
    };

    trace {
        lives-ok {
            sub classified(--> Str:D) is raw is traced {
                state Str:D $info = 'DIBU DUBU DABA LUBA DABA DU DA BI JI KI CBLABLALABLALAB ITS A SECRET';
                Proxy.new:
                    FETCH => sub FETCH($ --> '[REDACTED]')         { },
                    STORE => sub STORE($, Str:D $update --> Str:D) { $info = $update }
            }() ~= ' PABUDUBU CIBUDU PAPABU CIBUDUD PAPUBABU CIBUBU BLULULU BLULULU';
        }, 'traced routines handle containers OK';
    };

    trace {
        sub foo is traced { }();
    }, {
        has-header $^output, 'sub foo', 'unscoped routines have the correct declarator';
    };

    trace {
        my sub foo is traced { }();
    }, {
        has-header $^output, 'my sub foo', 'scoped routines have the correct declarator';
    };

    trace {
        lives-ok {
            my class Foo {
                method ^foo(\this) is traced { this.foo }

                proto method foo is traced { {*} }
                multi method foo is traced { self!foo }

                method !foo is traced { self.&foo }

                my method foo is traced { 1 }
            }.^foo;
        }, 'can trace the various types of methods a class can contain...';
    }, {
        has-header $^output, 'proto method foo', '...and trace output includes regular methods...';
        has-header $^output, 'multi method foo', '...multi methods...';
        has-header $^output, 'method !foo', '...private methods...';
        has-header $^output, 'method ^foo', '...metamethods...';
        has-header $^output, 'my method foo', '...and scoped methods';
    };

    trace {
        my Int:D $lexical = 1;
        sub with-outer-lexical() is traced { $lexical }();
    }, {
        has-footer $^output, '1', 'traced routines handles their outer lexical variables alright';
    }
}

# vim: ft=perl6 sw=4 ts=4 sts=4 et

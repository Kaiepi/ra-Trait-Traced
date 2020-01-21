use v6.d;
use Test;
use Trait::Traced;

plan 2;

sub wrap-tests(&block) {
    my Str:D      $filename  = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
    my IO::Pipe:D $*TRACER  := $*TMPDIR.child($filename).IO.open: :w;
    LEAVE {
        $*TRACER.close;
        $*TRACER.path.unlink;
    }
    block
}

subtest 'Metamodel::MethodContainer', {
    plan 6;

    wrap-tests {
        lives-ok {
            my class WithMethod is traced {
                method method(::?CLASS:U: --> 1) { }
            }.method;
        }, 'can call methods of traced classes...';
        ok $*TRACER.path.slurp, '...which produces output';
    };

    wrap-tests {
        lives-ok {
            my class WithTracedMethod is traced {
                method method(|) is traced {*}
            }.method;
        }, 'can call multi methods of traced classes...';
        ok (my Str:D $output = $*TRACER.path.slurp), '...which produces output...';
        nok $output ~~ / 'TRACED-ROUTINE' /, '...and does not rewrap themselves';
    };

    wrap-tests {
        lives-ok {
            my class WithProxyMethod is traced {
                method proxy(::?CLASS:U: --> Int:D) is raw {
                    Proxy.new:
                        FETCH => sub FETCH($ --> 0)    { },
                        STORE => sub STORE($, $ --> 0) { }
                }
            }.proxy++;
        }, 'methods of traced classes handle containers OK';
    };
};

subtest 'Metamodel::MultiMethodContainer', {
    plan 6;

    wrap-tests {
        lives-ok {
            my class WithMultiMethod is traced {
                proto method multi-method(|)     {*}
                multi method multi-method(--> 1) { }
            }.multi-method;
        }, 'can call multi methods of traced classes...';
        ok $*TRACER.path.slurp, '...which produces output';
    };

    wrap-tests {
        lives-ok {
            my class WithTracedMultiMethod is traced {
                proto method multi-method(|)     is traced {*}
                multi method multi-method(--> 1) is traced { }
            }.multi-method;
        }, 'can call traced multi methods of traced classes...';
        ok my Str:D $output = $*TRACER.path.slurp, '...which produces output...';
        nok $output ~~ / 'TRACED-ROUTINE' /, '...and do not rewrap themselves';
    };

    wrap-tests {
        lives-ok {
            my class WithProxyMultiMethod is traced {
                proto method proxy(|)                     is raw {*}
                multi method proxy(::?CLASS:U: --> Int:D) is raw {
                    Proxy.new:
                        FETCH => sub FETCH($ --> 0)    { },
                        STORE => sub STORE($, $ --> 0) { }
                }
            }.proxy++;
        }, 'multi methods of traced classes handle containers OK';
    };
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

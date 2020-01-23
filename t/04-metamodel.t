use v6.d;
use Test;
use Trait::Traced;

plan 4;

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
    plan 7;

    wrap-tests {
        lives-ok {
            my class WithMethod is traced {
                method method(::?CLASS:U: --> 1) { }
            }.method;
        }, 'can call methods of traced classes...';
        $*TRACER.flush;
        ok my Str:D $output = $*TRACER.path.slurp(:close), '...which produces output...';
        ok $output ~~ / <after ') '> 'method method' $$ /,
          '...that claims methods have the correct declarator';
    };

    wrap-tests {
        lives-ok {
            my class WithTracedMethod is traced {
                method method(|) is traced {*}
            }.method;
        }, 'can call multi methods of traced classes...';
        $*TRACER.flush;
        ok my Str:D $output = $*TRACER.path.slurp(:close), '...which produces output...';
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
    plan 8;

    wrap-tests {
        lives-ok {
            my class WithMultiMethod is traced {
                proto method multi-method(|)     {*}
                multi method multi-method(--> 1) { }
            }.multi-method;
        }, 'can call multi methods of traced classes...';
        $*TRACER.flush;
        ok my Str:D $output = $*TRACER.path.slurp(:close), '...which produces output...';
        ok $output ~~ / <after ') '> 'proto method multi-method' $$ /,
          '...that claims proto methods have the correct declarator...';
        ok $output ~~ / <after ') '> 'multi method multi-method' $$ /,
          '...and likewise for multi methods';
    };

    wrap-tests {
        lives-ok {
            my class WithTracedMultiMethod is traced {
                proto method multi-method(|)     is traced {*}
                multi method multi-method(--> 1) is traced { }
            }.multi-method;
        }, 'can call traced multi methods of traced classes...';
        $*TRACER.flush;
        ok my Str:D $output = $*TRACER.path.slurp(:close), '...which produces output...';
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

subtest 'Metamodel::PrivateMethodContainer', {
    plan 3;

    wrap-tests {
        lives-ok {
            my class WithTracedPrivateMethod is traced {
                method !private-method(|) is traced { }
            }.^find_private_method('private-method').(WithTracedPrivateMethod)
        }, 'can call traced private methods of traced classes...';
        $*TRACER.flush;
        ok my Str:D $output = $*TRACER.path.slurp(:close), '...which produces output...';
        ok $output ~~ / <after ') '> 'method !private-method' $$ /,
          '...that claims private methods have the correct declarator';
    };
};


subtest 'Metamodel::MetaMethodContainer', {
    plan 3;

    wrap-tests {
        lives-ok {
            my class WithTracedMetaMethod is traced {
                method ^meta-method(|) { }
            }.^meta-method;
        }, 'can call traced metamethods of traced classes...';
        $*TRACER.flush;
        ok my Str:D $output = $*TRACER.path.slurp(:close), '...which produces output...';
        ok $output ~~ / <after ') '> 'method ^meta-method' $$ /,
          '...that claims metamethods have the correct declarator';
    };
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

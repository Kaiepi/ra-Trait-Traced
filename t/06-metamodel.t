use v6;
use lib $?FILE.IO.sibling: 'lib';
use Trait::Traced;
use Test;
use Test::Trait::Traced;

plan 5;

subtest 'Metamodel::MethodContainer', {
    plan 7;

    trace {
        lives-ok {
            my class WithMethod is traced {
                method method(::?CLASS:U: --> 1) { }
            }.method;
        }, 'can call methods of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'method method',
            '...that claims methods have the correct declarator';
    };

    trace {
        lives-ok {
            my class WithTracedMethod is traced {
                method method(|) is traced {*}
            }.method;
        }, 'can call traced methods of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output.none, 'sub TRACED-ROUTINE',
            '...and do not rewrap themselves';
    };

    trace {
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

    trace {
        lives-ok {
            my class WithMultiMethod is traced {
                proto method multi-method(|)     {*}
                multi method multi-method(--> 1) { }
            }.multi-method;
        }, 'can call multi methods of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'proto method multi-method',
            '...that claims proto methods have the correct declarator...';
        has-header $^output, 'multi method multi-method',
            '...and likewise for multi methods';
    };

    trace {
        lives-ok {
            my class WithTracedMultiMethod is traced {
                proto method multi-method(|)     is traced {*}
                multi method multi-method(--> 1) is traced { }
            }.multi-method;
        }, 'can call traced multi methods of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output.none, 'sub TRACED-ROUTINE',
            '...and do not rewrap themselves';
    };

    trace {
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
    plan 4;

    trace {
        lives-ok {
            my class WithTracedPrivateMethod is traced {
                method !private-method(|) is traced { }
            }.^find_private_method('private-method').(WithTracedPrivateMethod)
        }, 'can call traced private methods of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'method !private-method',
            '...that claims private methods have the correct declarator';
    };

    trace {
        my role WithTracedPrivateMethod { method !private-method(|) { } }

        my class WithoutTracedPrivateMethod does WithTracedPrivateMethod is traced {
            method public-method(|args) { self!private-method: |args }
        }.public-method;
    }, {
        has-header $^output.none, 'method !private-method',
          'private methods of roles done by traced classes do not get traced';
    };
};


subtest 'Metamodel::MetaMethodContainer', {
    plan 3;

    trace {
        lives-ok {
            my class WithTracedMetaMethod is traced {
                method ^meta-method(|) { }
            }.^meta-method;
        }, 'can call traced metamethods of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'method ^meta-method',
            '...that claims metamethods have the correct declarator';
    };
};

subtest 'Metamodel::AttributeContainer', {
    plan 12;

    trace {
        lives-ok {
            my class WithTracedPublicAttribute is traced {
                has $.attribute;
            }.new: attribute => 'ok';
        }, 'can assign to public attributes of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'has $.attribute',
            '...that claims theys have the correct symbol';
    };

    trace {
        lives-ok {
            my class WithTracedPrivateAttribute is traced {
                has $!attribute;
                method set-attribute($!attribute) { }
            }.new.set-attribute: 1;
        }, 'can assign to private attributes of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'has $!attribute',
            '...that claims they have the correct symbol';
    };

    trace {
        lives-ok {
            my class WithTracedLexicalAttribute is traced {
                has $attribute;
                method set-attribute($!attribute) { }
            }.new.set-attribute: 1;
        }, 'can assign to lexical attributes of traced classes...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'has $attribute',
            '...that claims they have the correct symbol';
    };

    trace {
        lives-ok {
            my role WithTracedAttribute is traced {
                has $.attribute;
            }.new: attribute => 'ok';
        }, 'can assign to attributes of traced roles...';
    }, {
        ok $^output, '...which produce output...';
        has-header $^output, 'has $.attribute (WithTracedAttribute)',
            '...that claims attributes belong to the role, not $?CLASS';
    };
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

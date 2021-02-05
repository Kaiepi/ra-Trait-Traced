use v6;
use lib $?FILE.IO.sibling: 'lib';
use Trait::Traced;
use Test;
use Test::Trait::Traced;

plan 28;

trace {
    lives-ok {
        my class WithTracedScalar {
            has $!traced is traced;
            method set-traced($!traced) { }
        }.new.set-traced: 'ok';
    }, 'can assign to traced ro attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has $!traced',
        '...that claims the attribute has the correct symbol...';
    has-footer $^output, 'ok'.raku,
        '...and has the correct result';
};

trace {
    lives-ok {
        my class WithTracedScalar {
            has $.traced is rw is traced;
        }.new.traced = 'ok';
    }, 'can assign to traced rw attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has $.traced',
        '...that claims the attribute has the correct symbol...';
    has-footer $^output, 'ok'.raku,
        '...and has the correct result';
};

trace {
    lives-ok {
        my class WithTracedPositional {
            has @!traced is traced;
            method set-traced(+@!traced) { }
        }.new.set-traced: 1, 2, 3;
    }, 'can STORE in traced ro attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has @!traced',
        '...that claims the attribute has the correct symbol...';
    has-footer $^output, [1, 2, 3].raku,
        '...and has the correct result';
};

trace {
    lives-ok {
        my class WithTracedPositional {
            has @.traced is rw is traced;
        }.new.traced = 1, 2, 3;
    }, 'can STORE in traced rw attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has @.traced',
        '...that claims the attribute has the correct symbol...';
    has-footer $^output, [1, 2, 3].raku,
        '...and has the correct result';
};

trace {
    lives-ok {
        my class WithTracedLexical {
            has $traced is traced;
            method set-traced($!traced) { }
        }.new.set-traced: 1;
    }, 'can trace attributes with lexical symbols...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has $traced',
        '...that claims the attribute has the correct symbol';
};

trace {
    lives-ok {
        my class WithTracedTypedScalar {
            has Int:D $!answer is traced = 42;
        }.new;
    }, 'can trace typed scalar attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has Int:D $!answer',
        '...containing the attribute typing';
};

trace {
    lives-ok {
        my class WithTracedTypedPositional {
            has Int:D @!answers is traced = 42 xx 42;
        }.new;
    }, 'can trace typed positional attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has Int:D @!answers',
        '...containing the attribute typing';
};

trace {
    lives-ok {
        my class WithTracedTypedAssociative {
            has Int:D %!lexicon{Str:D} is traced = :answer<42>;
        }.new;
    }, 'can trace typed associative attributes...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'has Int:D %!lexicon{Str:D}',
        '...containing the attribute typing';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

use v6;
use lib $?FILE.IO.sibling: 'lib';
use Trait::Traced;
use Test;
use Test::Trait::Traced;

plan 19;

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
    ok $^output, '...which produces output...';
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
    ok $^output, '...which produces output...';
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
    ok $^output, '...which produces output...';
    has-header $^output, 'has $traced',
        '...that claims the attribute has the correct symbol';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

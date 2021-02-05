use v6;
use lib $?FILE.IO.sibling: 'lib';
use Trait::Traced;
use Test;
use Test::Trait::Traced;

plan 32;

trace {
    lives-ok {
        my $foo is traced = 0;
    }, 'can trace $ variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my $foo',
        '...that claims the assignment is for the correct symbol...';
    has-footer $^output, '0',
        '...and has the correct result';
};

trace {
    lives-ok {
        my Int:D $n is traced = 42;
    }, 'can trace typed $ variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my Int:D $n', '...that includes their typing';
};

trace {
    lives-ok {
        my @foo is traced = 1, 2, 3;
    }, 'can trace @ variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my @foo',
        '...that claims the assignment is for the correct symbol...';
    has-footer $^output, [1, 2, 3].raku,
        '...and has the correct output';
};

trace {
    lives-ok {
        my Int:D @ns is traced = 42,;
    }, 'can trace typed @ variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my Int:D @ns', '...that includes their typing';
};

trace {
    lives-ok {
        my %foo is traced = :1a, :2b, :3c;
    }, 'can trace % variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my %foo',
        '...that claims the assignment is for the correct symbol';
    # @ tests handle whether or not STORE works OK
};

trace {
    lives-ok {
        my Int:D %ns{Str:D} is traced = :42answer;
    }, 'can trace typed % variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my Int:D %ns{Str:D}', '...that includes their typing';
    # @ tests handle the no-key-type case OK
};

trace {
    lives-ok {
        my &foo is traced = { $_ };
    }, 'can trace & variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my &foo',
        '...that claims the assignment is for the correct symbol';
    # $ tests handle whether or not assignment works OK
};

trace {
    lives-ok {
        my Int:D &answer is traced = sub (--> Int:D) { 42 };
    }, 'can trace typed & variables...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my Int:D &answer',
        '...that claims the assignment is for the correct symbol';
}

trace {
    lives-ok {
        module { our $foo is traced = 1 }
    }, 'can trace our-scoped variables...';
}, {
    ok $^output, '...producing output on assignment...';
    has-header $^output, 'our $foo',
        '...that claims the variable has the correct scope';
};

trace {
    lives-ok {
        sub skreeonk($g8r is rw) {
            $g8r = Q:to/G8R/.chomp;
            ─────▄▄████▀█▄
            ───▄██████████████████▄
            ─▄█████.▼.▼.▼.▼.▼.▼.▼
             ██████
             ██████
             ██████ ＳＫＲＥＥＥＯＯＯＮＮＮＫＫＫＫ
             ██████
             ██████
            ▄███████▄.▲.▲.▲.▲.▲.▲
            █████████████████████▀▀
            G8R
        }(my $g8r is traced)
    }, 'traced scalars can be assigned to elsewhere...';
}, {
    ok $^output, '...producing output...';
    has-header $^output, 'my $g8r',
        '...that claims the assignment is for the original variable';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

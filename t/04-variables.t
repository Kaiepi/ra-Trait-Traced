use v6;
use Tracer::Default;
use Trait::Traced;
use Test;

sub trace(&run, &parse?) {
    my Str:D $filename = 'Trait-Traced-testing-' ~ 1_000_000.rand.floor ~ '.txt';
    my $*TRACER := Tracer::Default[$*TMPDIR.child($filename).open: :w];
    LEAVE {
        $*TRACER.handle.close;
        $*TRACER.handle.path.unlink;
    }
    run;
    $*TRACER.handle.flush;
    parse $*TRACER.handle.path.slurp(:close) with &parse;
}

plan 32;

trace {
    lives-ok {
        my $foo is traced = 0;
    }, 'can trace $ variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my $foo ' /,
      '...that claims the assignment is for the correct symbol...';
    ok $output ~~ / <after '==> '> 0 » /,
      '...and has the correct result';
};

trace {
    lives-ok {
        my Int:D $n is traced = 42;
    }, 'can trace typed $ variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my Int:D $n ' /,
      '...that includes its type';
};

trace {
    lives-ok {
        my @foo is traced = 1, 2, 3;
    }, 'can trace @ variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my @foo ' /,
      '...that claims the assignment is for the correct symbol...';
    ok $output ~~ / <after '==> '> { (my @ = 1, 2, 3).raku } /,
      '...and has the correct output';
};

trace {
    lives-ok {
        my Int:D @ns is traced = 42,;
    }, 'can trace typed @ variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my Int:D @ns ' /,
      '...that includes its type';
};

trace {
    lives-ok {
        my %foo is traced = :1a, :2b, :3c;
    }, 'can trace % variables...';
}, -> Str:D $output {
    ok $output, '...producing outpu...';
    ok $output ~~ / <after '<== '> 'my %foo ' /,
      '...that claims the assignment is for the correct symbol';
    # @ tests handle whether or not STORE works OK
};

trace {
    lives-ok {
        my Int:D %ns{Str:D} is traced = :42answer;
    }, 'can trace typed % variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my Int:D %ns{Str:D}' /,
      '...that claims the assignment is for the correct symbol';
    # @ tests handle the no-key-type case OK
};

trace {
    lives-ok {
        my &foo is traced = { $_ };
    }, 'can trace & variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my &foo ' /,
      '...that claims the assignment is for the correct symbol';
    # $ tests handle whether or not assignment works OK
};

trace {
    lives-ok {
        my Int:D &answer is traced = sub (--> Int:D) { 42 };
    }, 'can trace typed & variables...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my Int:D &answer ' /,
      '...that claims the assignment is for the correct symbol';
}

trace {
    lives-ok {
        module { our $foo is traced = 1 }
    }, 'can trace our-scoped variables...';
}, -> Str:D $output {
    ok $output, '...producing output on assignment...';
    ok $output ~~ / <after '<== '> 'our $foo' » /,
      '...that claims the variable has the correct scope';
};

trace {
    lives-ok {
        sub skreeeonk($g8r is rw) {
            $g8r = Q:to/G8R/.chomp
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
        }(my $wew is traced)
    }, 'traced scalars can be bound and assigned to elsewhere...';
}, -> Str:D $output {
    ok $output, '...producing output...';
    ok $output ~~ / <after '<== '> 'my $wew' /,
      '...that claims the assignment is for the original variable';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

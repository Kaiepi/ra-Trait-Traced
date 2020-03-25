use v6.d;
use Traced;
use Traced::Variable;
use Tracer::Default;
use Trait::Traced;
use Test;

sub wrap-tests(&block) {
    my Str:D $filename = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
    my $*TRACER := Tracer::Default[$*TMPDIR.child($filename).open: :w];
    LEAVE {
        $*TRACER.handle.close;
        $*TRACER.handle.path.unlink;
    }
    block
}

plan 17;

wrap-tests {
    lives-ok {
        my $foo is traced = 0;
    }, 'can trace $ variables...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...producing output on assignment';
    ok $result ~~ / <after '<== '> '$foo' /,
      '...that claims the assignment is for the correct symbol...';
    ok $result ~~ / <after '==> '> 0 /,
      '...and has the correct result';
};

wrap-tests {
    lives-ok {
        my @foo is traced = 1, 2, 3;
    }, 'can trace @ variables...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...producing output on assignment...';
    ok $result ~~ / <after '<== '> '@foo' /,
      '...that claims the assignment is for the correct symbol...';
    ok $result ~~ / <after '==> '> { (my @ = 1, 2, 3).raku } /,
      '...and has the correct result';

};

wrap-tests {
    lives-ok {
        my %foo is traced = :1a, :2b, :3c;
    }, 'can trace % variables...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...producing output on assignment...';
    ok $result ~~ / <after '<== '> '%foo' /,
      '...that claims the assignment is for the correct symbol';
    # @ tests handle whether or not STORE works OK
};

wrap-tests {
    lives-ok {
        my &foo is traced = { $_ };
    }, 'can trace & variables...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...producing output on assignment...';
    ok $result ~~ / <after '<== '> '&foo' /,
      '...that claims the assignment is for the correct symbol';
    # $ tests handle whether or not assignment works OK
};

wrap-tests {
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
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...producing output...';
    ok $result ~~ / <after '<== '> '$wew' /,
      '...that claims the assignment is for the original variable';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

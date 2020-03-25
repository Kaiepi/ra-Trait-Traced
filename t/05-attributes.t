use v6.d;
use Trait::Traced;
use Tracer::Default;
use Test;

sub wrap-tests(&block) {
    my Str:D $filename = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
    my $*TRACER := Tracer::Default[$*TMPDIR.child($filename).IO.open: :w];
    LEAVE {
        $*TRACER.handle.close;
        $*TRACER.handle.path.unlink;
    }
    block
}

plan 14;

wrap-tests {
    lives-ok {
        my class WithTracedScalar {
            has $!traced is traced;
            method set-traced($!traced) { }
        }.new.set-traced: 'ok';
    }, 'can assign to traced ro attributes...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...which produce output...';
    ok $result ~~ / <after '<== '> '$!traced' /,
      '...that claims the attribute has the correct symbol...';
    ok $result ~~ / <after '==> '> '"ok"' /,
      '...and has the correct result';
};

wrap-tests {
    lives-ok {
        my class WithTracedScalar {
            has $.traced is rw is traced;
        }.new.traced = 'ok';
    }, 'can assign to traced rw attributes...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '==> '> '"ok"' /,
      '...that has the correct result';
};

wrap-tests {
    lives-ok {
        my class WithTracedPositional {
            has @!traced is traced;
            method set-traced(+@!traced) { }
        }.new.set-traced: 1, 2, 3;
    }, 'can STORE in traced ro attributes...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...which produce output...';
    ok $result ~~ / <after '<== '> '@!traced' /,
      '...that claims the attribute has the correct symbol...';
    ok $result ~~ / <after '==> '> '[1, 2, 3]' /,
      '...and has the correct result';
};

wrap-tests {
    lives-ok {
        my class WithTracedPositional {
            has @.traced is rw is traced;
        }.new.traced = 1, 2, 3;
    }, 'can STORE in traced rw attributes...';
    $*TRACER.handle.flush;
    ok my Str:D $result = $*TRACER.handle.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '==> '> '[1, 2, 3]' /,
      '...that has the correct result';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

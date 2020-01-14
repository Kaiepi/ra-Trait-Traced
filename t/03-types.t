use v6.d;
use Test;
use Trait::Traced;

plan 4;

sub wrap-tests(&block) {
    my Str:D      $filename  = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
    my IO::Pipe:D $*TRACER  := $filename.IO.open: :w;
    LEAVE {
        $*TRACER.close;
        $*TRACER.path.unlink;
    }
    block
}

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
        my class WithMultiMethod is traced {
            proto method multi-method(|)     {*}
            multi method multi-method(--> 1) { }
        }.multi-method;
    }, 'can call multiple dispatch methods of traced classes...';
    ok $*TRACER.path.slurp, '...which produces output';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

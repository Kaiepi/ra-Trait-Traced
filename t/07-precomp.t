use v6;
use lib $?FILE.IO.sibling: 'lib';
use Tracee::Bitty;
use Tracer::File;
use Test;

sub trace(&trace, &parse?) {
    my Str:D $filename = 'Trait-Traced-testing-' ~ 1_000_000.rand.floor ~ '.txt';
    my $*TRACER = Tracer::File[Tracee::Bitty].new: $*TMPDIR.child($filename).open: :w;
    LEAVE {
        $*TRACER.handle.close;
        $*TRACER.handle.path.unlink;
    }
    trace;
    $*TRACER.handle.flush;
    parse $*TRACER.handle.path.slurp(:close) with &parse;
}

plan 3;

use-ok 'Test::Trait::Traced::Module', 'can import traced modules';
trace {
    use Test::Trait::Traced::Module;
    lives-ok { Test::Trait::Traced::Module.traced }, 'can call traced methods of traced modules...';
}, -> Str:D $output {
    ok $output, '...which produces output';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et

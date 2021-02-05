use v6;
use Tracee::Bitty;
use Tracer::File;
use Test;
unit module Test::Trait::Traced;

sub trace(&go, &parse? --> Nil) is export {
    my Str:D          $filename  = 'Trait-Traced-testing-' ~ 1_000_000.rand.floor ~ '.txt';
    my IO::Handle:D   $handle    = $*TMPDIR.child($filename).open: :w;
    my Tracer::File:D $*TRACER  := Tracer::File[Tracee::Bitty].new: $handle;
    go;
    $handle.flush;
    parse $handle.path.slurp with &parse;
    LEAVE $handle.close;
    LEAVE $handle.path.unlink;
}

sub has-header(Str:D $output, Str:D $header, Str:D $message) is test-assertion is export {
    ok $output ~~ / ^^ '    '* '<== ' $header /, $message;
}

sub has-entry(Str:D $output, Str:D $entry, Str:D $message) is test-assertion is export {
    ok $output ~~ / ^^ '    '+ $entry /, $message;
}

sub has-footer(Str:D $output, Str:D $footer, Str:D $message) is test-assertion is export {
    ok $output ~~ / ^^ '    '* '==> ' $footer /, $message;
}

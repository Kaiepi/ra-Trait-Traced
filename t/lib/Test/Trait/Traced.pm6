use v6;
use Tracee::Bitty;
use Tracer::Memory;
use Test;
unit module Test::Trait::Traced;

sub trace(&go, &parse? --> Nil) is export {
    my $*TRACER := Tracer::Memory[Tracee::Bitty].new;
    go;
    parse @$*TRACER.join: $*TRACER.tracee.nl with &parse;
}

sub has-header(Mu $output is raw, Str:D $header, Str:D $message) is test-assertion is export {
    cmp-ok $output, &[~~], / ^^ '    '* '<== ' $header /, $message;
}

sub has-entry(Mu $output is raw, Str:D $entry, Str:D $message) is test-assertion is export {
    cmp-ok $output, &[~~], / ^^ '    '+ $entry /, $message;
}

sub has-footer(Mu $output is raw, Str:D $footer, Str:D $message) is test-assertion is export {
    cmp-ok $output, &[~~], / ^^ '    '* '==> ' $footer /, $message;
}

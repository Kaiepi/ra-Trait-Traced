use v6;
use Perl6::Grammar:from<NQP>;
unit module Trait::Traced::Utils;

multi sub postcircumfix:<{ }>(Perl6::Grammar:D $/ is raw, Str:D $key --> Mu) is raw is export {
    use nqp;

    nqp::hllize(nqp::atkey($/, nqp::decont_s($key)))
}
multi sub postcircumfix:<{ }>(Perl6::Grammar:D $/ is raw, Str:D $key, Bool:D :exists($)! where ?* --> Mu) is export {
    use nqp;

    nqp::hllbool(nqp::existskey($/, nqp::decont_s($key)))
}

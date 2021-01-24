use v6;
use Perl6::Grammar:from<NQP>;
use Traced::Attribute;
unit package MetamodelX::Traced;

role AdHocAttribute[Attribute:D :$attribute!, Str:D :$name!, Bool:D :$repr! where !*] {
    method compose(::?CLASS:D: | --> Mu) {
        my Mu $package := callsame;
        $package.&trace-attribute($attribute, $name);
        $package
    }
}

role AdHocAttribute[Attribute:D :$attribute!, Str:D :$name!, Bool:D :$repr! where ?*] {
    method compose_repr(::?CLASS:D: Mu $package is raw, | --> Mu) {
        $package.&trace-attribute($attribute, $name);
        callsame
    }
}

# 🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉
# 🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉　ＨＥＲＥ ＢＥ ＤＲＡＧＯＮＳ　🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉
# 🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉
#
# We can't invent the key and value types of attributes easily for the same
# reason we can't with variables, but we also don't have access to the key type
# of Associative attributes from Trait::Traced!
sub trace-attribute(Mu $package is raw, Attribute:D $attribute, Str:D $name --> Nil) {
    $/ := $*LEAF;
    $/ := $<blockoid> if $<blockoid>:exists;
    $/ := $<statementlist><statement>\
          .map(*.<EXPR>.<scope_declarator>)\
          .grep([&] ?*, *.<sym>.Str eq 'has')\
          .map(*.<scoped>)\
          .grep(*.&declarator.<variable_declarator>.<variable>.Str eq $name)\
          .head; # XXX: first broken with Mu as of v2020.12

    my %rest = :$package, :$name;
    %rest<key>   := .[0].<statement>.[0].ast.value if .[0]:exists given $/.&declarator.<variable_declarator>.<semilist>;
    %rest<value> := .[0].ast if .[0]:exists given $<typename>;
    Traced::Attribute.wrap: $attribute, |%rest
}

sub declarator(Perl6::Grammar:D $/ is raw --> Perl6::Grammar:D) {
    my Perl6::Grammar:D $declarator := $/;
    $declarator := $declarator<DECL> if $declarator<DECL>:exists;
    $declarator := $declarator<declarator> if $declarator<declarator>:exists;
    $declarator
}

multi sub postcircumfix:<{ }>(Perl6::Grammar:D $/ is raw, Str:D $key --> Mu) is raw {
    use nqp;

    nqp::hllize(nqp::atkey($/, nqp::decont_s($key)))
}
multi sub postcircumfix:<{ }>(Perl6::Grammar:D $/ is raw, Str:D $key, Bool:D :exists($)! where ?* --> Mu) is raw {
    use nqp;

    nqp::hllbool(nqp::existskey($/, nqp::decont_s($key)))
}

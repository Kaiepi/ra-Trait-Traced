use v6;
use Perl6::Grammar:from<NQP>;
use Trait::Traced::Utils;
use Traced::Attribute;
unit package MetamodelX::Traced;

role AdHocAttribute[Attribute:D :$attribute!, :%symbols!, Bool:D :$repr! where !*] {
    method compose(::?CLASS:D: | --> Mu) {
        my Mu $package := callsame;
        $package.&trace-attribute($attribute, %symbols);
        $package
    }
}

role AdHocAttribute[Attribute:D :$attribute!, :%symbols!, Bool:D :$repr! where ?*] {
    method compose_repr(::?CLASS:D: Mu $package is raw, | --> Mu) {
        $package.&trace-attribute($attribute, %symbols);
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
sub trace-attribute(Mu $package is raw, Attribute:D $attribute, %symbols --> Nil) {
    my Str:D $name = $attribute.name;
    if $attribute.has_accessor {
        $name .= subst: '!', '.';
    } elsif %symbols{my Str:D $symbol = $name.subst: '!', ''}:exists {
        $name = $symbol;
    }

    $/ := $*LEAF;
    $/ := $<blockoid> if $<blockoid>:exists;
    $/ := $<statementlist><statement>\
          .map(*.<EXPR>.<scope_declarator>)\
          .grep([&] ?*, *.<sym>.Str eq 'has')\
          .map(*.<scoped>)\
          .grep(*.&declarator.<variable_declarator>.<variable>.Str eq $name)\
          .head;

    my %rest = :$package, :$name;
    %rest<value> := .[0].ast if .[0]:exists given $<typename>;
    if $name.starts-with: '%' {
        $/ := $/.&declarator;
        %rest<key> := .[0].<statement>.[0].ast.value if .[0]:exists given $<variable_declarator><semilist>;
    }
    Traced::Attribute.wrap: $attribute, |%rest
}

sub declarator(Perl6::Grammar:D $/ is raw --> Perl6::Grammar:D) {
    my Perl6::Grammar:D $declarator := $/;
    $declarator := $declarator<DECL> if $declarator<DECL>:exists;
    $declarator := $declarator<declarator> if $declarator<declarator>:exists;
    $declarator
}

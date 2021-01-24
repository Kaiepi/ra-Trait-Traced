use v6;
use Perl6::Grammar:from<NQP>;
use Traced::Attribute;
unit package MetamodelX::Traced;

role AttributeContainer[:%symbols!, Bool:D :repr($)! where !*] {
    method compose(::?CLASS:D: | --> Mu) {
        my Mu $package := callsame;
        $package.&trace-attributes(self.attributes($package, :local), %symbols);
        $package
    }
}

role AttributeContainer[:%symbols!, Bool:D :repr($) where ?*] {
    method compose_repr(::?CLASS:D: Mu $package is raw, | --> Mu) {
        $package.&trace-attributes(self.attributes($package, :local), %symbols);
        callsame
    }
}

# 🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉
# 🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉　ＨＥＲＥ ＢＥ ＤＲＡＧＯＮＳ　🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉
# 🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉
#
# We can't invent the key and value types of attributes easily for the same
# reason we can't with variables, only now we can't easily gain direct access
# to the attributes either since type traits are applied before its attributes
# actually exist! 
sub trace-attributes(Mu $package is raw, @attributes, %symbols --> Nil) {
    $/ := $*LEAF;
    $/ := $<blockoid> if $<blockoid>:exists;
    for @attributes Z (
        $<statementlist><statement>\
            .map(*.<EXPR>.<scope_declarator>)\
            .grep([&] ?*, *.<sym>.Str eq 'has')\
            .map(*.<scoped>)
    ) -> [Mu $attribute is raw, Perl6::Grammar:D $leaf is raw] {
        if Metamodel::Primitives.is_type: $attribute, Attribute {
            my Str:D $name = $attribute.name;
            if $attribute.has_accessor {
                $name .= subst: '!', '.';
            } elsif %symbols{my Str:D $symbol = $name.subst: '!', ''}:exists {
                $name = $symbol;
            }

            my Perl6::Grammar:D $declarator := $leaf;
            $declarator := $declarator<DECL> if $declarator<DECL>:exists;
            $declarator := $declarator<declarator> if $declarator<declarator>:exists;

            my %rest = :$package, :$name;
            %rest<key>   := .[0].<statement>.[0].ast.value if .[0]:exists given $declarator<variable_declarator><semilist>;
            %rest<value> := .[0].ast if .[0]:exists given $leaf<typename>;
            Traced::Attribute.wrap: $attribute, |%rest
        }
    }
}

multi sub postcircumfix:<{ }>(Perl6::Grammar:D $/ is raw, Str:D $key --> Mu) is raw {
    use nqp;

    nqp::hllize(nqp::atkey($/, nqp::decont_s($key)))
}
multi sub postcircumfix:<{ }>(Perl6::Grammar:D $/ is raw, Str:D $key, Bool:D :exists($)! where ?* --> Mu) is raw {
    use nqp;

    nqp::hllbool(nqp::existskey($/, nqp::decont_s($key)))
}

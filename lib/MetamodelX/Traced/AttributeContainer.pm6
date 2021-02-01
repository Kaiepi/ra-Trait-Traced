use v6;
use Perl6::Grammar:from<NQP>;
use Trait::Traced::Utils;
use Traced::Attribute;
unit package MetamodelX::Traced;

role AttributeContainer[:%symbols!, Bool:D :repr($)! where !*] {
    method compose(::?CLASS:D: | --> Mu) {
        my Mu $package := callsame;
        self.&trace-attributes($package, %symbols);
        $package
    }
}

role AttributeContainer[:%symbols!, Bool:D :repr($)! where ?*] {
    method compose_repr(::?CLASS:D: Mu $package is raw, | --> Mu) {
        self.&trace-attributes($package, %symbols);
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
sub trace-attributes(Mu $how is raw, Mu $package is raw, %symbols --> Nil) {
    $/ := $*LEAF;
    $/ := $<blockoid> if $<blockoid>:exists;
    for $how.attributes($package, :local) Z (
        $<statementlist><statement>\
            .map(*.<EXPR>.<scope_declarator>)\
            .grep([&] ?*, *.<sym>.Str eq 'has')\
            .map(*.<scoped>)
    ) -> [Mu $attribute is raw, Perl6::Grammar:D $/ is raw] {
        if Metamodel::Primitives.is_type: $attribute, Attribute {
            my Str:D $name = $attribute.name;
            if $attribute.has_accessor {
                $name .= subst: '!', '.';
            } elsif %symbols{my Str:D $symbol = $name.subst: '!', ''}:exists {
                $name = $symbol;
            }

            my %rest = :$package, :$name;
            %rest<value> := .[0].ast if .[0]:exists given $<typename>;
            if $name.starts-with: '%' {
                $/ := $<DECL> if $<DECL>:exists;
                $/ := $<declarator> if $<declarator>:exists;
                %rest<key> := .[0].<statement>.[0].ast.value if .[0]:exists given $<variable_declarator><semilist>;
            }
            Traced::Attribute.wrap: $attribute, |%rest
        }
    }
}

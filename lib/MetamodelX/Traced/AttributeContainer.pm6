use v6;
use Trait::Traced::Utils;
use Traced :TRACING;
use Traced::Attribute :TRACING;
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

sub trace-attributes(Mu $how is raw, Mu $package is raw, %symbols --> Nil) {
    for $how.attributes: $package, :local -> Mu $attribute is raw {
        if Metamodel::Primitives.is_type: $attribute, Attribute {
            my Str:D $name = $attribute.name;
            if $attribute.has_accessor {
                $name .= subst: '!', '.';
            } elsif %symbols{my Str:D $symbol = $name.subst: '!', ''}:exists {
                $name = $symbol;
            }

            my %rest := {:$package, :$name};
            given $name.substr: 0, 1 { # Sigil
                my Mu $container := $attribute.container.VAR;
                when '$' {
                    %rest<value> := $_ unless $_ =:= Mu given $container.of;
                }
                when '@' {
                    %rest<value> := $_ unless $_ =:= Mu given $container.of;
                }
                when '%' {
                    %rest<value> := $_ unless $_ =:= Mu given $container.of;
                    %rest<key>   := $_ unless $_ =:= Str(Any) given $container.keyof;
                }
                when '&' {
                    %rest<value> := $_ unless $_ =:= Mu given $container.of.of;
                }
            }
            TRACING Traced::Attribute::Event, $attribute, |%rest
        }
    }
}

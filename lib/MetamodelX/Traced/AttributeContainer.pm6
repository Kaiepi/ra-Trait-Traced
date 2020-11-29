use v6;
use Traced::Attribute;
unit package MetamodelX::Traced;

role AttributeContainer[:%symbols! is raw, Bool:D :repr($) where !*] {
    method compose(::?CLASS:D: | --> Mu) {
        my Mu $package := callsame;
        for self.attributes: $package, :local -> Mu $attribute is raw {
            my Str:D $name = $attribute.name;
            if $attribute.has_accessor {
                $name .= subst: '!', '.';
            } elsif %symbols{my Str:D $symbol = $name.subst: '!', ''}:exists {
                $name = $symbol;
            }
            Traced::Attribute.wrap: $attribute, :$package, :$name
                if Metamodel::Primitives.is_type: $attribute, Attribute;
        }
        %symbols := {};
        $package
    }
}

role AttributeContainer[:%symbols! is raw, Bool:D :repr($) where ?*] {
    method compose_repr(::?CLASS:D: Mu $package is raw, | --> Mu) {
        for self.attributes: $package, :local -> Mu $attribute is raw {
            my Str:D $name = $attribute.name;
            if $attribute.has_accessor {
                $name .= subst: '!', '.';
            } elsif %symbols{my Str:D $symbol = $name.subst: '!', ''}:exists {
                $name = $symbol;
            }
            Traced::Attribute.wrap: $attribute, :$package, :$name
                if Metamodel::Primitives.is_type: $attribute, Attribute;
        }
        %symbols := {};
        callsame
    }
}

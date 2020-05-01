use v6.e.PREVIEW;
use Traced::Attribute;
unit role MetamodelX::Traced::AttributeContainer[:%symbols! is raw];

method compose(::?CLASS:D: | --> Mu) {
    my Mu $type := callsame;
    trace_attributes self, $type unless Metamodel::Primitives.is_type: self, Metamodel::REPRComposeProtocol;
    $type
}

method compose_repr(::?CLASS:D: Mu $obj is raw, | --> Mu) {
    trace_attributes self, $obj;
    callsame
}

# Can't be a private method, as NQP classes don't know about those.
my method trace_attributes(::?CLASS:D: Mu $package is raw --> Mu) {
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

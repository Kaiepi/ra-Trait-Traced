use v6.d;
use Traced;
unit class Traced::Attribute is Traced;

enum Access <Assign Store>;

has Access:D    $.access    is required;
has Attribute:D $.attribute is required;

method new(::?CLASS:_: Access:D $access, Attribute:D $attribute, *%rest --> ::?CLASS:D) {
    self.bless: :$access, :$attribute, |%rest
}

method colour(::?CLASS:D: --> 34)            { }
method category(::?CLASS:D: --> 'ATTRIBUTE') { }
method type(::?CLASS:D: --> Str:D)           { $!access.key.uc }

multi method what(::?CLASS:D: --> Str:D) {
    my Str:D $name    = $!attribute.name;
    my Str:D $package = $!attribute.package.^name;
    $name .= trans: '!' => '.' if $!attribute.has_accessor;
    "$name ($package)"
}

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather { }
}

# Handles tracing for scalar (and callable) attributes. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedAttributeContainerDescriptor {
    has Mu          $!descriptor is required;
    has Attribute:D $!attribute  is required;

    submethod BUILD(::?CLASS:D: Mu :$descriptor! is raw, Attribute:D :$!attribute! --> Nil) {
        $!descriptor := $descriptor;
    }

    method new(::THIS ::?CLASS:_: Mu $descriptor is raw, Attribute:D $attribute --> ::?CLASS:D) {
        self.bless: :$descriptor, :$attribute
    }

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> Str:D) {
        "traced attribute $!attribute.name()"
    }

    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        Traced::Attribute.trace: Access::Assign, $!attribute, :$value
    }
}

# Handles tracing for positional and associative variables.
my role TracedAttributeContainer[Attribute:D $attribute] {
    method STORE(|args) {
        Traced::Attribute.trace:
            Access::Store, $attribute,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

multi method wrap(::?CLASS:_: Attribute:D $attribute --> Mu) {
    use nqp;
    my Str:D $sigil = $attribute.name.substr: 0, 1;
    if $sigil eq any '$', '&' {
        my Mu $descriptor := nqp::getattr($attribute<>, Attribute, '$!container_descriptor');
        $descriptor := TracedAttributeContainerDescriptor.new: $descriptor, $attribute;
        my Mu $container := nqp::p6scalarfromdesc($descriptor);
        nqp::bindattr($container, Scalar, '$!value', $attribute.container);
        nqp::bindattr($attribute<>, Attribute, '$!auto_viv_container', $container);
    } elsif $sigil eq any '@', '%' {
        $attribute.container.^mixin: TracedAttributeContainer.^parameterize: $attribute;
    }
}

multi method trace(::?CLASS:U: Access::Assign, Attribute:D, Mu :$value is raw --> Mu) is raw {
    $value
}
multi method trace(::?CLASS:U: Access::Store, Attribute:D, :&callback is raw, Capture:D :$arguments is raw --> Mu) is raw {
    callback |$arguments
}

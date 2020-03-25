use v6.d;
use Traced;
unit class Traced::Attribute is Traced;

enum Type <Assign Store>;

has Type:D $.type      is required;
has Mu     $.package   is required;
has Str:D  $.name      is required;

method new(::?CLASS:_: Type:D $type, Mu $package is raw, Str:D $name, *%rest --> ::?CLASS:D) {
    self.bless: :$type, :$package, :$name, |%rest
}

method colour(::?CLASS:D: --> 34)            { }
method category(::?CLASS:D: --> 'ATTRIBUTE') { }
method type(::?CLASS:D: --> Str:D)           { $!type.key.uc }

multi method what(::?CLASS:D: --> Str:D) {
    "$!name ($!package.^name())"
}

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather { }
}

# Handles tracing for scalar (and callable) attributes. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedAttributeContainerDescriptor {
    has Mu    $!descriptor is required;
    has Mu    $!package    is required;
    has Str:D $!name       is required;

    submethod BUILD(::?CLASS:D: Mu :$descriptor is raw, Mu :$package is raw, Str:D :$!name --> Nil) {
        $!descriptor := $descriptor;
        $!package    := $package;
    }

    method new(::THIS ::?CLASS:_: Mu $descriptor is raw, Mu $package is raw, Str:D $name --> ::?CLASS:D) {
        self.bless: :$descriptor, :$package, :$name
    }

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> Str:D) {
        "traced attribute $!name"
    }

    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        Traced::Attribute.trace:
            Type::Assign, $!package, $!name,
            value => $value
    }
}

# Handles tracing for positional and associative variables.
my role TracedAttributeContainer[Attribute:D $attribute] {
    method STORE(|args) {
        Traced::Attribute.trace:
            Type::Store, $attribute.package, $attribute.name,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

multi method wrap(::?CLASS:_: Attribute:D $attribute --> Mu) {
    use nqp;
    my Str:D $sigil = $attribute.name.substr: 0, 1;
    if $sigil eq any '$', '&' {
        my Mu $descriptor := TracedAttributeContainerDescriptor.new:
            nqp::getattr($attribute<>, Attribute, '$!container_descriptor'),
            $attribute.package, $attribute.name;
        my Mu $container := nqp::p6scalarfromdesc($descriptor);
        nqp::bindattr($container, Scalar, '$!value', $attribute.container);
        nqp::bindattr($attribute<>, Attribute, '$!auto_viv_container', $container);
    } elsif $sigil eq any '@', '%' {
        $attribute.container.^mixin: TracedAttributeContainer.^parameterize: $attribute;
    }
}

multi method trace(::?CLASS:U: Type::Assign, Mu, Str:D, Mu :$value is raw --> Mu) is raw {
    $value
}
multi method trace(::?CLASS:U: Type::Store, Mu, Str:D, :&callback is raw, Capture:D :$arguments is raw --> Mu) is raw {
    callback |$arguments
}

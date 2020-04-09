use v6.d;
use Traced;
unit class Traced::Attribute is Traced;

enum Access <Assign Store>;

has Access:D    $.access    is required;
has Attribute:D $.attribute is required;
has Mu          $.package   is required is built(:bind);
has Str:D       $.name      is required;

method new(::?CLASS:_: Access:D $access, Attribute:D $attribute, Mu $package is raw, Str:D $name, *%rest --> ::?CLASS:D) {
    self.bless: :$access, :$attribute, :$package, :$name, |%rest
}

method colour(::?CLASS:D: --> 34)            { }
method category(::?CLASS:D: --> 'ATTRIBUTE') { }
method type(::?CLASS:D: --> Str:D)           { $!access.key.uc }

multi method what(::?CLASS:D: --> Str:D) {
    "$!name ($!package.^name())"
}

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather { }
}

# Handles tracing for scalar (and callable) attributes. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedAttributeContainerDescriptor {
    has Mu          $!descriptor is required;
    has Attribute:D $!attribute  is required;
    has Mu          $!package    is required;
    has Str:D       $!name       is required;

    submethod BUILD(
        ::?CLASS:D:
        Mu          :$descriptor! is raw,
        Attribute:D :$!attribute!,
        Mu          :$package! is raw,
        Str:D       :$!name!
        --> Nil
    ) {
        $!descriptor := $descriptor;
        $!package    := $package;
    }

    method new(::?CLASS:_: Mu $descriptor is raw, Attribute:D $attribute, *%meta --> ::?CLASS:D) {
        self.bless: :$descriptor, :$attribute, |%meta
    }

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> Str:D) {
        "traced attribute $!name"
    }

    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        Traced::Attribute.trace: Access::Assign, $!attribute, $!package, $!name, :$value
    }
}

# Handles tracing for positional and associative variables.
my role TracedAttributeContainer[Attribute:D $attribute, Mu :$package! is raw, Str:D :$name!] {
    method STORE(|args) {
        Traced::Attribute.trace:
            Access::Store, $attribute, $package, $name,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

my role TracedAttribute {
    method is-traced(--> True) { }
}

multi method wrap(::?CLASS:_: Attribute:D $attribute, Mu :$package! is raw, Str:D :$name! --> Nil) {
    use nqp;
    return if $attribute.?is-traced;

    my Str:D $sigil = $attribute.name.substr: 0, 1;
    if $sigil eq any <$ &> {
        my Mu $descriptor := nqp::getattr($attribute<>, Attribute, '$!container_descriptor');
        $descriptor := TracedAttributeContainerDescriptor.new: $descriptor, $attribute, :$package, :$name;
        my Mu $container := nqp::p6scalarfromdesc($descriptor);
        nqp::bindattr($container, Scalar, '$!value', $attribute.container);
        nqp::bindattr($attribute<>, Attribute, '$!auto_viv_container', $container);
    } elsif $sigil eq any <@ %> {
        $attribute.container.^mixin: TracedAttributeContainer.^parameterize: $attribute, :$package, :$name;
    }

    $attribute does TracedAttribute;
}

multi method trace(::?CLASS:U: Access::Assign;; Attribute:D, Mu, Str:D, Mu :$value is raw --> Mu) is raw {
    $value
}
multi method trace(::?CLASS:U: Access::Store;; Attribute:D, Mu, Str:D, :&callback is raw, Capture:D :$arguments is raw --> Mu) is raw {
    callback |$arguments
}

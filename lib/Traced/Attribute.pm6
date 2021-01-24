use v6;
use Traced;
unit class Traced::Attribute does Traced;

enum Type <ASSIGN STORE>;

constant VOID = Mu.new;

has Mu          $.package   is required is built(:bind);
has Str:D       $.name      is required;
has Attribute:D $.attribute is required;
has Mu          $.key       is built(:bind) = VOID;
has Mu          $.value     is built(:bind) = VOID;

method kind(::?CLASS:D: --> 'ATTRIBUTE') { }

method of(::?CLASS:D: --> Type:D) { ... }

method declarator(::?CLASS:D: --> Str:D) {
    my Str:D $declarator = 'has ';
    $declarator ~= Qs/$!value.^name() / unless $!value =:= VOID;
    $declarator ~= Qs/$!name/;
    $declarator ~= Qs/{$!key.^name()}/ unless $!key =:= VOID;
    $declarator
}

# Handles tracing for scalar (and callable) attributes. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedAttributeContainerDescriptor { ... }

# Handles tracing for positional and associative variables.
my role TracedAttributeContainer { ... }

my role TracedAttribute {
    method is-traced(--> True) { }
}

proto method wrap(::?CLASS:U: Attribute:D --> Nil) {*}
multi method wrap(::?CLASS:U: TracedAttribute:D --> Nil) { }
multi method wrap(::?CLASS:_: Attribute:D $attribute, *%rest --> Nil) {
    use nqp;

    my Str:D $sigil := $attribute.name.substr: 0, 1;
    if $sigil eq <$ &>.any {
        my Mu $descriptor := nqp::getattr($attribute<>, Attribute, '$!container_descriptor');
        $descriptor := TracedAttributeContainerDescriptor.new: :$descriptor, :$attribute, |%rest;
        my Mu $container := nqp::p6scalarfromdesc($descriptor);
        nqp::bindattr($container, Scalar, '$!value', $attribute.container);
        nqp::bindattr($attribute<>, Attribute, '$!auto_viv_container', $container);
    } else { # @ and %
        $attribute.container.^mixin: TracedAttributeContainer.^parameterize: :$attribute, |%rest;
    }

    $attribute does TracedAttribute;
}

my role Impl { ... }

method ^parameterize(::?CLASS:U $this is raw, Type:D $type is raw --> ::?CLASS:U) {
    my ::?CLASS:U $mixin := self.mixin: $this, Impl.^parameterize: $type;
    $mixin.^set_name: self.name($this) ~ qq/[$type]/;
    $mixin
}

my class TracedAttributeContainerDescriptor {
    has Mu          $.descriptor is required is built(:bind);
    has Mu          $.package    is required;
    has Str:D       $.name       is required;
    has Attribute:D $.attribute  is required;
    has Mu          $.key        is built(:bind) = VOID;
    has Mu          $.value      is built(:bind) = VOID;

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> Str:D) { "traced attribute $!name" }

    my \TracedAttributeAssign = CHECK Traced::Attribute.^parameterize: ASSIGN;
    method assigned(::?CLASS:D: Mu $result is raw --> Mu) is raw {
        $*TRACER.render: TracedAttributeAssign.event:
            :$!attribute, :$!package, :$!name, :$!key, :$!value, :$result
    }
}

my role Impl[ASSIGN] {
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method event(::?CLASS:U: Mu :$result is raw --> Mu) is raw { $result }
}

my role TracedAttributeContainer[Attribute:D :$attribute, *%rest] {
    my \TracedAttributeStore = CHECK Traced::Attribute.^parameterize: STORE;
    method STORE(|args) {
        $*TRACER.render: TracedAttributeStore.event:
            attribute => $attribute,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args),
            |%rest
    }
}

my role Impl[STORE] {
    method of(::?CLASS:D: --> STORE) { }

    multi method event(::?CLASS:U: :&callback is raw, Capture:D :$arguments is raw --> Mu) is raw {
        callback |$arguments
    }
}

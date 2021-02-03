use v6;
use Traced;
unit module Traced::Attribute;

constant VOID = Mu.new;

enum Type <ASSIGN STORE>;

role Event does Traced {
    has Mu          $.package   is required is built(:bind);
    has Str:D       $.name      is required;
    has Attribute:D $.attribute is required;
    has Mu          $.key       is built(:bind) = VOID;
    has Mu          $.value     is built(:bind) = VOID;

    method kind(::?CLASS:D: --> 'ATTRIBUTE') { }

    method declarator(::?CLASS:D: --> Str:D) {
        my Str:D $declarator = 'has ';
        $declarator ~= Qs/$!value.^name() / without $!value;
        $declarator ~= Qs/$!name/;
        $declarator ~= Qs/{$!key.^name()}/ without $!key;
        $declarator
    }
}

role Event[ASSIGN] does Event {
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method capture(::?CLASS:U: Mu :$result is raw --> Mu) is raw { $result }
}

role Event[STORE] does Event {
    method of(::?CLASS:D: --> STORE) { }

    multi method capture(::?CLASS:U: :&callback is raw, Capture:D :$arguments is raw --> Mu) is raw {
        callback |$arguments
    }
}

my role Wrap { method is-traced(--> True) { } }

multi sub TRACING(Event:U, Wrap:D;; *%rest --> Nil) is export(:TRACING) { }

# Handles tracing for scalar (and callable) attributes. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class ContainerDescriptor { ... }

# Handles tracing for positional and associative variables.
my role Container { ... }

multi sub TRACING(Event:U, Attribute:D $attribute;; *%rest --> Nil) is export(:TRACING) {
    use nqp;

    my Str:D $sigil := $attribute.name.substr: 0, 1;
    if $sigil eq <$ &>.any {
        my Mu $descriptor := nqp::getattr($attribute<>, Attribute, '$!container_descriptor');
        $descriptor := ContainerDescriptor.new: :$descriptor, :$attribute, |%rest;
        my Mu $container := nqp::p6scalarfromdesc($descriptor);
        nqp::bindattr($container, Scalar, '$!value', $attribute.container);
        nqp::bindattr($attribute<>, Attribute, '$!auto_viv_container', $container);
    } else { # @ and %
        $attribute.container.^mixin: Container.^parameterize: :$attribute, |%rest;
    }

    $attribute does Wrap;
}

my class ContainerDescriptor {
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

    method assigned(::?CLASS:D: Mu $result is raw --> Mu) is raw {
        my constant AssignEvent = Event[ASSIGN].^pun;
        $*TRACER.render: AssignEvent.capture:
            :$!attribute, :$!package, :$!name, :$!key, :$!value, :$result
    }
}

my role Container[*%rest] {
    method STORE(|args) {
        my constant StoreEvent = Event[STORE].^pun;
        $*TRACER.render: StoreEvent.capture:
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args),
            |%rest
    }
}

use v6;
use Traced;
#|[ Attribute tracing module. ]
unit module Traced::Attribute;

#|[ The absence of a type. ]
constant VOID = Mu.new;

#|[ A type of attribute trace. ]
enum Type <ASSIGN STORE>;

#|[ A traced attribute event template. ]
role Event does Traced {
    #|[ The package this attribute belongs to. ]
    has Mu          $.package   is built(:bind) is required;
    #|[ The name of the attribute as written. ]
    has Str:D       $.name      is required;
    #|[ The attribute in question. ]
    has Attribute:D $.attribute is required;
    #|[ Any attribute key typing. ]
    has Mu          $.key       is built(:bind) = VOID;
    #|[ Any attribute value typing. ]
    has Mu          $.value     is built(:bind) = VOID;

    #|[ The name of this kind of traced event. ]
    method kind(::?CLASS:D: --> 'ATTRIBUTE') { }

    #|[ The attribute declaration as written. ]
    method declarator(::?CLASS:D: --> Str:D) {
        my Str:D $declarator = 'has ';
        $declarator ~= Qs/$!value.^name() / without $!value;
        $declarator ~= Qs/$!name/;
        $declarator ~= Qs/{$!key.^name()}/ without $!key;
        $declarator
    }
}

#|[ A traced scalar attribute assignment. ]
role Event[ASSIGN] does Event {
    #|[ The type of traced attribute event. ]
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method capture(::?CLASS:U:
        Mu :$result is raw
    --> Mu) is raw is hidden-from-backtrace { $result }
}

#|[ A traced positional or associative attribute assignment (STORE method call). ]
role Event[STORE] does Event {
    #|[ The type of traced attribute event. ]
    method of(::?CLASS:D: --> STORE) { }

    multi method capture(::?CLASS:U:
        :&callback is raw, Capture:D :$arguments is raw
    --> Mu) is raw is hidden-from-backtrace {
        callback |$arguments
    }
}

#|[ Marks a traced attribute. ]
my role Wrap { method is-traced(--> True) { } }

multi sub TRACING(Event:U, Wrap:D;; *%rest --> Nil) is export(:TRACING) { }

my class ContainerDescriptor { ... }

my role Container { ... }

multi sub TRACING(Event:U, Attribute:D $attribute;; *%rest --> Nil) is export(:TRACING) {
    use nqp;

    if Metamodel::Primitives.is_type: $attribute.container.VAR, Scalar {
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

#|[ A container descriptor for traced scalar attributes. ]
my class ContainerDescriptor {
    has Mu          $.descriptor is built(:bind) is required;
    has Mu          $.package    is built(:bind) is required;
    has Str:D       $.name       is required;
    has Attribute:D $.attribute  is required;
    has Mu          $.key        is built(:bind) = VOID;
    has Mu          $.value      is built(:bind) = VOID;

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> Str:D) { "traced attribute $!name" }

    method assigned(::?CLASS:D: Mu $result is raw --> Mu) is raw is hidden-from-backtrace {
        my constant AssignEvent = Event[ASSIGN].^pun;
        $*TRACER.render: AssignEvent.capture:
            :$!attribute, :$!package, :$!name, :$!key, :$!value, :$result
    }
}

#|[ A traced positional or associative attribute container. ]
my role Container[*%rest] {
    method STORE(|args) is raw is hidden-from-backtrace {
        my constant StoreEvent = Event[STORE].^pun;
        $*TRACER.render: StoreEvent.capture:
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args),
            |%rest
    }
}

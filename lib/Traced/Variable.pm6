use v6;
use Traced;
unit module Traced::Variable;

constant VOID = Mu.new;

enum Type <ASSIGN STORE>;

role Event does Traced {
    has Mu         $.package  is required;
    has Str:D      $.scope    is required;
    has Variable:D $.variable is required;
    has Mu         $.key      is built(:bind) = VOID;
    has Mu         $.value    is built(:bind) = VOID;

    method kind(::?CLASS:D: --> 'VARIABLE') { }

    method declarator(::?CLASS:D: --> Str:D) {
        my Str:D $declarator = $!scope;
        $declarator ~= Qs/ $!value.^name()/ without $!value;
        $declarator ~= Qs/ $!variable.name()/;
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

    multi method capture(::?CLASS:U: :&callback, Capture:D :$arguments is raw --> Mu) is raw {
        callback |$arguments
    }
}

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class ContainerDescriptor { ... }

# Handles tracing for positional and associative variables.
my role Container { ... }

multi sub TRACING(Event:U, Variable:D $variable;; *%rest --> Mu) is export(:TRACING) {
    use nqp;

    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR;
    if Metamodel::Primitives.is_type: $container, Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, $container.WHAT, '$!descriptor');
        $descriptor := ContainerDescriptor.new: :$descriptor, :$variable, |%rest;
        nqp::bindattr($var, $container.WHAT, '$!descriptor', $descriptor);
    } else { # @ and %
        $container.^mixin: Container.^parameterize: :$variable, |%rest;
    }
}

my class ContainerDescriptor {
    has Mu         $.descriptor is required is built(:bind);
    has Mu         $.package    is required is built(:bind);
    has Str:D      $.scope      is required;
    has Variable:D $.variable   is required;
    has Mu         $.key        is built(:bind) = VOID;
    has Mu         $.value      is built(:bind) = VOID;

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) { "traced variable $!variable.name()" }

    method assigned(::?CLASS:D: Mu $result is raw --> Mu) is raw {
        my constant AssignEvent = Event[ASSIGN].^pun;
        $*TRACER.render: AssignEvent.capture:
            :$!package, :$!scope, :$!variable, :$!key, :$!value, :$result
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

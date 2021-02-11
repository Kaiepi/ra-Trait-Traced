use v6;
use Traced;
#|[ Variable tracing module. ]
unit module Traced::Variable;

#|[ The absence of a type. ]
constant VOID = Mu.new;

#|[ A type of variable trace. ]
enum Type <ASSIGN STORE>;

#|[ A traced variable event template. ]
role Event does Traced {
    #|[ The package this variable was declared in. ]
    has Mu         $.package  is built(:bind) is required;
    #|[ The scope of the variable. ]
    has Str:D      $.scope    is required;
    #|[ The variable in question. ]
    has Variable:D $.variable is required;
    #|[ Any variable key typing. ]
    has Mu         $.key      is built(:bind) = VOID;
    #|[ Any variable value typing. ]
    has Mu         $.value    is built(:bind) = VOID;

    #|[ The name of the kind of traced event. ]
    method kind(::?CLASS:D: --> 'VARIABLE') { }

    #|[ The variable declaration as written. ]
    method declarator(::?CLASS:D: --> Str:D) {
        my Str:D $declarator = $!scope;
        $declarator ~= Qs/ $!value.^name()/ without $!value;
        $declarator ~= Qs/ $!variable.name()/;
        $declarator ~= Qs/{$!key.^name()}/ without $!key;
        $declarator
    }
}

#|[ A traced scalar variable assignment. ]
role Event[ASSIGN] does Event {
    #|[ The type of traced variable event. ]
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method capture(::?CLASS:U:
        Mu :$result is raw
    --> Mu) is raw is hidden-from-backtrace {
        $result
    }
}

#|[ A traced positional or associative variable assignment. ]
role Event[STORE] does Event {
    #|[ The type of traced variable event. ]
    method of(::?CLASS:D: --> STORE) { }

    multi method capture(::?CLASS:U:
        :&callback, Capture:D :$arguments is raw
    --> Mu) is raw is hidden-from-backtrace {
        callback |$arguments
    }
}

my class ContainerDescriptor { ... }

my role Container { ... }

multi sub TRACING(Event:U, Variable:D $variable;; *%rest --> Mu) is export(:TRACING) {
    use nqp;

    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR;
    if Metamodel::Primitives.is_type: $container, Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, Scalar, '$!descriptor');
        $descriptor := ContainerDescriptor.new: :$descriptor, :$variable, |%rest;
        nqp::bindattr($var, Scalar, '$!descriptor', $descriptor);
    } else { # @ and %
        $container.^mixin: Container.^parameterize: :$variable, |%rest;
    }
}

#|[ A container descriptor for traced scalar variables. ]
my class ContainerDescriptor {
    has Mu         $.descriptor is built(:bind) is required;
    has Mu         $.package    is built(:bind) is required;
    has Str:D      $.scope      is required;
    has Variable:D $.variable   is required;
    has Mu         $.key        is built(:bind) = VOID;
    has Mu         $.value      is built(:bind) = VOID;

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) { "traced variable $!variable.name()" }

    method assigned(::?CLASS:D: Mu $result is raw --> Mu) is raw is hidden-from-backtrace {
        my constant AssignEvent = Event[ASSIGN].^pun;
        $*TRACER.render: AssignEvent.capture:
            :$!package, :$!scope, :$!variable, :$!key, :$!value, :$result
    }
}

#|[ A traced positional or associative variable container. ]
my role Container[*%rest] {
    method STORE(|args) is raw is hidden-from-backtrace {
        my constant StoreEvent = Event[STORE].^pun;
        $*TRACER.render: StoreEvent.capture:
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args),
            |%rest
    }
}

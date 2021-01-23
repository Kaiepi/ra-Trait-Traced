use v6;
use Traced;
unit class Traced::Variable does Traced;

enum Type <ASSIGN STORE>;

constant VOID = Mu.new;

has Mu         $.package  is required;
has Str:D      $.scope    is required;
has Variable:D $.variable is required;
has Mu         $.key      is built(:bind) = VOID;
has Mu         $.value    is built(:bind) = VOID;

method kind(::?CLASS:D: --> 'VARIABLE') { }

method of(::?CLASS:D: --> Type:D) { ... }

method declarator(::?CLASS:D: --> Str:D) {
    my Str:D $declarator = $!scope;
    $declarator ~= Qs/ $!value.^name()/ unless $!value =:= VOID;
    $declarator ~= Qs/ $!variable.name()/;
    $declarator ~= Qs/{$!key.^name()}/ unless $!key =:= VOID;
    $declarator
}

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedVariableContainerDescriptor { ... }

# Handles tracing for positional and associative variables.
my role TracedVariableContainer { ... }

method wrap(::?CLASS:_: Variable:D $variable, *%rest --> Mu) {
    use nqp;

    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR;
    if Metamodel::Primitives.is_type: $container, Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, $container.WHAT, '$!descriptor');
        $descriptor := TracedVariableContainerDescriptor.new: :$descriptor, :$variable, |%rest;
        nqp::bindattr($var, $container.WHAT, '$!descriptor', $descriptor);
    } else { # @ and %
        $container.^mixin: TracedVariableContainer.^parameterize: :$variable, |%rest;
    }
}

my role Impl { ... }

method ^parameterize(::?CLASS:U $this is raw, Type:D $type is raw --> ::?CLASS:U) {
    my ::?CLASS:U $mixin := self.mixin: $this, Impl.^parameterize: $type;
    $mixin.^set_name: self.name($this) ~ qq/[$type]/;
    $mixin
}

my class TracedVariableContainerDescriptor {
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

    my \TracedVariableAssign = CHECK Traced::Variable.^parameterize: ASSIGN;
    method assigned(::?CLASS:D: Mu $result is raw --> Mu) is raw {
        $*TRACER.render: TracedVariableAssign.event:
            :$!package, :$!scope, :$!variable, :$!key, :$!value, :$result
    }
}

my role Impl[ASSIGN] {
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method event(::?CLASS:U: Mu :$result is raw --> Mu) is raw { $result }
}

my role TracedVariableContainer[*%rest] {
    my \TracedVariableStore = CHECK Traced::Variable.^parameterize: STORE;
    method STORE(|args) {
        $*TRACER.render: TracedVariableStore.event:
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args),
            |%rest
    }
}

my role Impl[STORE] {
    method of(::?CLASS:D: --> STORE) { }

    multi method event(::?CLASS:U: :&callback, Capture:D :$arguments is raw --> Mu) is raw {
        callback |$arguments
    }
}

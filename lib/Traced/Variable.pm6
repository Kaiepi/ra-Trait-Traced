use v6.d;
use Traced;
unit class Traced::Variable does Traced;

enum Type <ASSIGN STORE>;

constant EMPTY = Mu.new;

has Mu         $.package  is required;
has Mu         $.value-of is built(:bind) is required;
has Mu         $.key-of   is built(:bind) = EMPTY;
has Str:D      $.scope    is required;
has Variable:D $.variable is required;

method kind(::?CLASS:D: --> 'VARIABLE') { }

method of(::?CLASS:D: --> Type:D) { ... }

method declarator(::?CLASS:D: --> Str:D) {
    my Str:D $declarator = $!scope;
    $declarator ~= " $!value-of.^name()"  unless $!value-of =:= Mu;
    $declarator ~= " $!variable.name()";
    $declarator ~= Qs/{$!key-of.^name()}/ unless $!key-of =:= EMPTY;
    $declarator
}

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedVariableContainerDescriptor { ... }

# Handles tracing for positional and associative variables.
my role TracedVariableContainer { ... }

method wrap(::?CLASS:_: Variable:D $variable, Mu :$package! is raw, Str:D :$scope! --> Mu) {
    use nqp;

    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR;
    if Metamodel::Primitives.is_type: $container, Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, $container.WHAT, '$!descriptor');
        my Mu $value-of   := $descriptor.of;
        $value-of := $value-of.of if Metamodel::Primitives.is_type: $value-of, Callable;
        $descriptor := TracedVariableContainerDescriptor.new:
            :$descriptor, :$package, :$scope, :$value-of, :$variable;
        nqp::bindattr($var, $container.WHAT, '$!descriptor', $descriptor);
    } else { # @ and %
        my Mu $value-of := $container.of;
        my Mu $key-of   := Metamodel::Primitives.is_type($container, Associative) && $container.keyof !=:= Str(Any)
                        ?? $container.keyof
                        !! EMPTY;
        $var.VAR.^mixin: TracedVariableContainer.^parameterize:
            :$package, :$scope, :$value-of, :$variable, :$key-of
    }
}

my role Impl { ... }

method ^parameterize(::?CLASS:U $this is raw, Type:D $type is raw --> ::?CLASS:U) {
    my ::?CLASS:U $mixin := self.mixin: $this, Impl.^parameterize: $type;
    $mixin.^set_name: self.name($this) ~ qq/[$type]/;
    $mixin
}

my class TracedVariableContainerDescriptor {
    has Mu         $!descriptor is required is built(:bind);
    has Mu         $!package    is required is built(:bind);
    has Str:D      $!scope      is required is built;
    has Mu         $!value-of   is required is built(:bind);
    has Variable:D $!variable   is required is built;

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) { "traced variable $!variable.name()" }

    my \TracedVariableAssign = CHECK Traced::Variable.^parameterize: ASSIGN;
    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        $*TRACER.render: TracedVariableAssign.event:
            :$!package, :$!scope, :$!value-of, :$!variable, :$value
    }
}

my role Impl[ASSIGN] {
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method event(::?CLASS:U: Mu :$value is raw --> Mu) is raw { $value }
}

my role TracedVariableContainer[
    Mu :$package! is raw, Str:D :$scope!, Mu :$value-of! is raw, Variable:D :$variable!, Mu :$key-of is raw = EMPTY
] {
    my \TracedVariableStore = CHECK Traced::Variable.^parameterize: STORE;
    method STORE(|args) {
        $*TRACER.render: TracedVariableStore.event:
            package    => $package,
            scope      => $scope,
            value-of   => $value-of,
            variable   => $variable,
            key-of     => $key-of,
            callback   => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments  => \(self, |args)
    }
}

my role Impl[STORE] {
    method of(::?CLASS:D: --> STORE) { }

    multi method event(::?CLASS:U: :&callback, Capture:D :$arguments is raw --> Mu) is raw {
        callback |$arguments
    }
}

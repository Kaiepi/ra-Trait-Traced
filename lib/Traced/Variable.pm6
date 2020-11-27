use v6.d;
use Traced;
unit class Traced::Variable does Traced;

enum Type <ASSIGN STORE>;

has Str:D      $.scope    is required;
has Variable:D $.variable is required;

method new(::?CLASS:_: Variable:D $variable, *%rest --> ::?CLASS:D) {
    self.bless: :$variable, |%rest
}

method kind(::?CLASS:D: --> 'VARIABLE') { }

method of(::?CLASS:D: --> Type:D) { ... }

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedVariableContainerDescriptor { ... }

# Handles tracing for positional and associative variables.
my role TracedVariableContainer { ... }

method wrap(::?CLASS:_: Variable:D $variable, Str:D :$scope! --> Mu) {
    use nqp;

    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR.WHAT;
    if $container ~~ Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, $container, '$!descriptor');
        $descriptor := TracedVariableContainerDescriptor.new: :$descriptor, :$variable, :$scope;
        nqp::bindattr($var, $container, '$!descriptor', $descriptor);
    } elsif $container ~~ Positional | Associative { # @ and %
        $var.VAR.^mixin: TracedVariableContainer.^parameterize: $variable, $scope;
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
    has Variable:D $!variable   is required is built;
    has Str:D      $!scope      is required is built;

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) { "traced variable $!variable.name()" }

    my \TracedVariableAssign = CHECK Traced::Variable.^parameterize: ASSIGN;
    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        $*TRACER.render: TracedVariableAssign.event: $!variable, :$!scope, :$value
    }
}

my role Impl[ASSIGN] {
    method of(::?CLASS:D: --> ASSIGN) { }

    multi method event(::?CLASS:U: Variable:D, Mu :$value is raw --> Mu) is raw { $value }
}

my role TracedVariableContainer[Variable:D $variable, Str:D $scope] {
    my \TracedVariableStore = CHECK Traced::Variable.^parameterize: STORE;
    method STORE(|args) {
        $*TRACER.render: TracedVariableStore.event:
            $variable, :$scope,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

my role Impl[STORE] {
    method of(::?CLASS:D: --> STORE) { }

    multi method event(::?CLASS:U: Variable:D, :&callback, Capture:D :$arguments is raw --> Mu) is raw {
        callback |$arguments
    }
}

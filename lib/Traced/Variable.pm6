use v6.d;
use Traced;
unit class Traced::Variable is Traced;

enum Access <Assign Store>;

has Access:D   $.access   is required;
has Str:D      $.scope    is required;
has Variable:D $.variable is required;

method new(::?CLASS:_: Access:D $access, Variable:D $variable, *%rest --> ::?CLASS:D) {
    self.bless: :$access, :$variable, |%rest
}

method colour(::?CLASS:D: --> 33)           { }
method category(::?CLASS:D: --> 'VARIABLE') { }
method type(::?CLASS:D: --> Str:D)          { $!access.key.uc }

multi method what(::?CLASS:D: --> Str:D) {
    "$!scope $!variable.name()"
}

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather { }
}

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedVariableContainerDescriptor {
    has Mu         $!descriptor is required;
    has Variable:D $!variable   is required;
    has Str:D      $!scope      is required;

    submethod BUILD(::?CLASS:D: Mu :$descriptor! is raw, Variable:D :$!variable!, Str:D :$!scope! --> Nil) {
        $!descriptor := $descriptor;
    }

    method new(::?CLASS:_: Mu $descriptor is raw, Variable:D $variable, Str:D $scope --> ::?CLASS:D) {
        self.bless: :$descriptor, :$variable, :$scope
    }

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) {
        "traced variable $!variable.name()"
    }

    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        Traced::Variable.trace: Access::Assign, $!variable, :$!scope, :$value
    }
}

# Handles tracing for positional and associative variables.
my role TracedVariableContainer[Variable:D $variable, Str:D $scope] {
    method STORE(|args) {
        Traced::Variable.trace:
            Access::Store, $variable, :$scope,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

multi method wrap(::?CLASS:_: Variable:D $variable, Str:D :$scope! --> Mu) {
    use nqp;
    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR.WHAT;
    if $container ~~ Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, $container, '$!descriptor');
        $descriptor := TracedVariableContainerDescriptor.new: $descriptor, $variable, $scope;
        nqp::bindattr($var, $container, '$!descriptor', $descriptor);
    } elsif $container ~~ Positional | Associative { # @ and %
        $var.VAR.^mixin: TracedVariableContainer.^parameterize: $variable, $scope;
    }
}

multi method trace(::?CLASS:U: Access::Assign;; Variable:D, Mu :$value is raw --> Mu) is raw {
    $value
}
multi method trace(::?CLASS:U: Access::Store;; Variable:D, :&callback, Capture:D :$arguments is raw --> Mu) is raw {
    callback |$arguments
}

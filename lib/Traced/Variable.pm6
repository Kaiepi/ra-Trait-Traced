use v6.d;
use Traced;
unit class Traced::Variable is Traced;

enum Type <Assign Store>;

has Type:D     $.type     is required;
has Variable:D $.variable is required;

method new(::?CLASS:_: Type:D $type, Variable:D $variable, *%rest --> ::?CLASS:D) {
    self.bless: :$type, :$variable, |%rest
}

method colour(::?CLASS:D: --> 33)           { }
method category(::?CLASS:D: --> 'VARIABLE') { }
method type(::?CLASS:D: --> Str:D)          { $!type.key.uc }

multi method what(::?CLASS:D: --> Str:D) { $!variable.name }

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather { }
}

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedVariableContainerDescriptor {
    has Mu         $!descriptor is required;
    has Variable:D $!variable   is required;

    submethod BUILD(::?CLASS:D: Mu :$descriptor! is raw, Variable:D :$!variable! --> Nil) {
        $!descriptor := $descriptor;
    }

    method new(::?CLASS:_: Mu $descriptor is raw, Variable:D $variable --> ::?CLASS:D) {
        self.bless: :$descriptor, :$variable
    }

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) {
        "traced variable $!variable.name()"
    }

    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        Traced::Variable.trace: Type::Assign, $!variable, :$value
    }
}

# Handles tracing for positional and associative variables.
my role TracedVariableContainer[Variable:D $variable] {
    method STORE(|args) {
        Traced::Variable.trace:
            Type::Store, $variable,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

multi method wrap(::?CLASS:_: Variable:D $variable --> Mu) {
    use nqp;
    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR.WHAT;
    if $container ~~ Scalar { # $ and &
        my Mu $descriptor := nqp::getattr($var, $container, '$!descriptor');
        $descriptor := TracedVariableContainerDescriptor.new: $descriptor, $variable;
        nqp::bindattr($var, $container, '$!descriptor', $descriptor);
    } elsif $container ~~ Positional | Associative { # @ and %
        $var.VAR.^mixin: TracedVariableContainer.^parameterize: $variable;
    }
}

multi method trace(::?CLASS:U: Type::Assign, Variable:D, Mu :$value is raw --> Mu) is raw {
    $value
}
multi method trace(::?CLASS:U: Type::Store, Variable:D, :&callback, Capture:D :$arguments is raw --> Mu) is raw {
    callback |$arguments
}

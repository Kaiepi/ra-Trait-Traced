use v6.d;
use Traced;
unit class Traced::Variable is Traced;

enum Type <Assign Store>;

has Type:D $.type is required;
has Str:D  $.name is required;

method new(::?CLASS:_: Type:D $type, Str:D $name, *%rest --> ::?CLASS:D) {
    self.bless: :$type, :$name, |%rest
}

method colour(::?CLASS:D: --> 33)           { }
method category(::?CLASS:D: --> 'VARIABLE') { }
method type(::?CLASS:D: --> Str:D)          { $!type.key.uc }

multi method what(::?CLASS:D: --> Str:D) { $!name }

multi method entries(::?CLASS:D: --> Iterable:D) {
    gather { }
}

# Handles tracing for scalar (and callable) variables. This is done instead of
# using Proxy because Scalar supports atomic ops, while Proxy doesn't.
my class TracedVariableContainerDescriptor {
    has Mu    $!descriptor is required;
    has Str:D $!name       is required;

    submethod BUILD(::?CLASS:D: Mu :$descriptor! is raw, Str:D :$!name! --> Nil) {
        $!descriptor := $descriptor;
    }

    method new(::?CLASS:_: Mu $descriptor is raw, Str:D $name --> ::?CLASS:D) {
        self.bless: :$descriptor, :$name
    }

    method of(::?CLASS:D: --> Mu)      { $!descriptor.of }
    method dynamic(::?CLASS:D: --> Mu) { $!descriptor.dynamic }
    method default(::?CLASS:D: --> Mu) { $!descriptor.default }
    method next(::?CLASS:D: --> Mu)    { self }

    method name(::?CLASS:D: --> str) {
        "traced variable $!name"
    }

    method assigned(::?CLASS:D: Mu $value is raw --> Mu) is raw {
        Traced::Variable.trace: Type::Assign, $!name, :$value
    }
}

# Handles tracing for positional and associative variables.
my role TracedVariableContainer[Variable:D $variable] {
    method STORE(|args) {
        Traced::Variable.trace:
            Type::Store, $variable.name,
            callback  => self.^mixin_base.^find_method('STORE'), # XXX: nextcallee doesn't work here as of v2020.03
            arguments => \(self, |args)
    }
}

multi method wrap(::?CLASS:_: Variable:D $variable --> Mu) {
    use nqp;
    my Mu $var       := $variable.var;
    my Mu $container := $var.VAR.WHAT;
    if $container ~~ Scalar { # $ and &
        nqp::bindattr($var, $container, '$!descriptor',
            TracedVariableContainerDescriptor.new:
                nqp::getattr($var, $container, '$!descriptor'),
                nqp::p6box_s($variable.name));
    } elsif $container ~~ Positional | Associative { # @ and %
        $var.VAR.^mixin: TracedVariableContainer.^parameterize: $variable;
    }
}

multi method trace(::?CLASS:U: Type::Assign, Str:D $name, Mu :$value is raw --> Mu) is raw {
    $value
}
multi method trace(::?CLASS:U: Type::Store, Str:D $name, :&callback, Capture:D :$arguments is raw --> Mu) is raw {
    callback |$arguments
}

use v6.d;
use Kind;
use Traced::Routine;
use MetamodelX::Traced::MethodContainer;
use MetamodelX::Traced::MultiMethodContainer;
sub EXPORT(--> Map:D) {
    PROCESS::<$TRACER> := $*OUT;
    Map.new
}
unit module Trait::Traced:ver<0.0.1>:auth<github:Kaiepi>:api<1>;

#|[ Exception thrown by the "is traced" trait when a feature is not yet implemented. ]
my class X::Trait::Traced::NYI is Exception is export {
    #|[ The feature that is not yet implemented. ]
    has Str:D $.what is required;
    #|[ The exception's message. ]
    method message(::?CLASS:D: --> Str:D) {
        "Support for tracing $!what NYI"
    }
}

multi sub trait_mod:<is>(Variable:D $variable, Bool:D :$traced! where ?*) is export {
    X::Trait::Traced::NYI.new(:what<variables>).throw
}

multi sub trait_mod:<is>(Parameter:D $parameter, Bool:D :$traced! where ?*) is export {
    X::Trait::Traced::NYI.new(:what<parameters>).throw
}

multi sub trait_mod:<is>(Routine:D $routine is raw, Bool:D :$traced! where ?*) is export {
    Traced::Routine.wrap: $routine, multi => $routine.dispatcher.DEFINITE;
}

multi sub trait_mod:<is>(Method:D $method is raw, Bool:D :$traced! where ?*) is export {
    Traced::Routine.wrap: $method, multi => $method.dispatcher.DEFINITE;
}

multi sub trait_mod:<is>(Attribute:D $attribute, Bool:D :$traced! where ?*) is export {
    X::Trait::Traced::NYI.new(:what<attributes>).throw
}

multi sub trait_mod:<is>(Mu \T, Bool:D :$traced! where ?*) is export {
    # Do nothing. This candidate exists so tracing for types can be composable.
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::MethodContainer], Bool:D :$traced! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::MethodContainer;
    nextsame;
}
# TODO: private method support
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::MultiMethodContainer], Bool:D :$traced! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::MultiMethodContainer;
    nextsame;
}
# TODO: metamethod support

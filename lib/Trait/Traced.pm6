use v6.d;
use Kind;
use Traced::Routine;
use MetamodelX::Traced::AdHocMethod;
use MetamodelX::Traced::MethodContainer;
use MetamodelX::Traced::MultiMethodContainer;
use MetamodelX::Traced::PrivateMethodContainer;
sub EXPORT(--> Map:D) {
    PROCESS::<$TRACER> := $*OUT;
    Map.new
}
unit module Trait::Traced:ver<0.1.2>:auth<github:Kaiepi>:api<0>;

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
    Traced::Routine.wrap:
        $routine,
        scope     => $*SCOPE,
        multiness => $*MULTINESS;
        prefix    => '';
}

multi sub trait_mod:<is>(Method:D $method is raw, Bool:D :$traced! where ?*) is export {
    use nqp;
    if my str $scope = $*SCOPE {
        Traced::Routine.wrap:
            $method,
            scope     => $scope eq 'has' ?? '' !! $scope,
            multiness => $*MULTINESS,
            prefix    => '';
    } elsif nqp::can($method.package.HOW, 'compose') {
        # We know this is a method belonging to a class/role/etc., but we can't
        # possibly know if it's a regular method, private method, or metamethod
        # at this point during compilation. We can find out when the method's
        # package gets composed though!
        $method.package.HOW.^mixin:
            MetamodelX::Traced::AdHocMethod.^parameterize:
                $method;
    }
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
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::MultiMethodContainer], Bool:D :$traced! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::MultiMethodContainer;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::PrivateMethodContainer], Bool:D :$traced! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::PrivateMethodContainer;
    nextsame;
}
# TODO: metamethod support

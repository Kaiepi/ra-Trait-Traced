use v6;
use Kind;
use Traced :TRACING;
use Traced::Attribute :TRACING;
use Traced::Routine :TRACING;
use Traced::Stash :TRACING;
use Traced::Variable :TRACING;
use Tracee::Pretty;
use Tracer::Stream;
use MetamodelX::Traced::AdHocMethod;
use MetamodelX::Traced::AttributeContainer;
use MetamodelX::Traced::MethodContainer;
use MetamodelX::Traced::MultiMethodContainer;
use MetamodelX::Traced::PrivateMethodContainer;
use MetamodelX::Traced::MetaMethodContainer;
unit module Trait::Traced:ver<1.0.3>:auth<github:Kaiepi>:api<2>;

INIT PROCESS::<$TRACER> := Tracer::Stream[Tracee::Pretty].new: $*OUT unless PROCESS::<$TRACER>:exists;

################################################################################
#                                 Exceptions                                   #
################################################################################

#|[ An exception thrown by Trait::Traced explicitly. ]
role X::Trait::Traced { }

#|[ An exception thrown when a feature is not yet implemented by Trait::Traced. ]
class X::Trait::Traced::NYI is Exception does X::Trait::Traced {
    #|[ The feature that is not yet implemented. ]
    has Str:D $.what is required;
    #|[ The exception's message. ]
    method message(::?CLASS:D: --> Str:D) {
        "Support for tracing $!what NYI"
    }
}

#|[ An exception thrown when the "is traced" trait is applied during runtime. ]
class X::Trait::Traced::Runtime is Exception does X::Trait::Traced {
    #|[ The exception's message. ]
    method message(::?CLASS:D: --> 'Please do not apply the "is traced" trait during runtime.') { }
}

################################################################################
#                                   Traits                                     #
################################################################################

my &ASSERT-COMPILING := { X::Trait::Traced::Runtime.new.throw without $*LANG | $*W };

multi sub trait_mod:<is>(Routine:D $routine is raw, Bool:D :traced($)! where ?*) is export {
    ASSERT-COMPILING;
    TRACING Traced::Routine::Event, $routine,
        scope     => $*SCOPE,
        multiness => $*MULTINESS;
}

multi sub trait_mod:<is>(Method:D $method is raw, Bool:D :traced($)! where ?*) is export {
    use nqp;

    ASSERT-COMPILING;
    if my str $scope = $*SCOPE {
        TRACING Traced::Routine::Event, $method,
            scope     => $scope eq 'has' ?? '' !! $scope,
            multiness => $*MULTINESS;
    } elsif nqp::can($method.package.HOW, 'compose') {
        # We know this is a method belonging to a class/role/etc., but we can't
        # possibly know if it's a regular method, private method, or metamethod
        # at this point during compilation. We can find out when the method's
        # package gets composed though!
        $method.package.HOW.^mixin: MetamodelX::Traced::AdHocMethod.^parameterize: $method;
    }
}

multi sub trait_mod:<is>(Variable:D $variable, Bool:D :traced($)! where ?*) is export {
    ASSERT-COMPILING;
    my %rest := {:package($*PACKAGE), :scope($*SCOPE)};
    given $variable.name.substr: 0, 1 { # Sigil
        my Mu $container := $variable.var.VAR;
        when '$' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of;
        }
        when '@' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of;
        }
        when '%' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of;
            %rest<key>   := $_ unless $_ =:= Str(Any) given $container.keyof;
        }
        when '&' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of.of;
        }
    }
    TRACING Traced::Variable::Event, $variable, |%rest;
}

multi sub trait_mod:<is>(Attribute:D $attribute, Bool:D :traced($)! where ?*) is export {
    ASSERT-COMPILING;
    my Mu    $package := $attribute.package;
    my Str:D $name     = $attribute.name;
    my Str:D $symbol  := $name.subst: '!', '';
    if $*W.cur_lexpad.symbol: $symbol {
        $name = $symbol;
    } elsif $attribute.has_accessor {
        $name .= subst: '!', '.';
    }

    my %rest := {:$package, :$name};
    given $name.substr: 0, 1 { # Sigil
        my Mu $container := $attribute.container.VAR;
        when '$' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of;
        }
        when '@' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of;
        }
        when '%' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of;
            %rest<key>   := $_ unless $_ =:= Str(Any) given $container.keyof;
        }
        when '&' {
            %rest<value> := $_ unless $_ =:= Mu given $container.of.of;
        }
    }
    TRACING Traced::Attribute::Event, $attribute, |%rest
}

multi sub trait_mod:<is>(Parameter:D $parameter, Bool:D :traced($)! where ?*) is export {
    X::Trait::Traced::NYI.new(:what<parameters>).throw
}

multi sub trait_mod:<is>(Mu \T where *, Bool:D :traced($)! where ?*) is default is export {
    ASSERT-COMPILING;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::MethodContainer], Bool:D :traced($)! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::MethodContainer;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::MultiMethodContainer], Bool:D :traced($)! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::MultiMethodContainer;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::PrivateMethodContainer], Bool:D :traced($)! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::PrivateMethodContainer;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::MetaMethodContainer], Bool:D :traced($)! where ?*) is export {
    T.HOW.^mixin: MetamodelX::Traced::MetaMethodContainer;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::AttributeContainer], Bool:D :traced($)! where ?*) is export {
    my        %symbols := $*W.cur_lexpad.symtable;
    my Bool:D $repr    := Metamodel::Primitives.is_type: T.HOW, Metamodel::REPRComposeProtocol;
    T.HOW.^mixin: MetamodelX::Traced::AttributeContainer.^parameterize: :%symbols, :$repr;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T where Kind[Metamodel::Stashing], Bool:D :traced($)! where ?*) is export {
    TRACING Traced::Stash::Event, T.WHO;
    nextsame;
}
multi sub trait_mod:<is>(Mu \T, Bool:D :traced($)! where ?*) is export {
    # Do nothing. This candidate exists so tracing for types can be composable.
}

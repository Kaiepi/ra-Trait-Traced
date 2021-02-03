use v6;
use Traced :TRACING;
use Traced::Routine :TRACING;
unit role MetamodelX::Traced::AdHocMethod[Method:D $method is raw];

method compose(Mu $obj is raw, |) {
    my Bool:D $multi-found = False;
    if Metamodel::Primitives.is_type: self, Metamodel::MultiMethodContainer {
        for self.multi_methods_to_incorporate: $obj {
            next unless .code =:= $method;
            TRACING Traced::Routine::Event, $_, :multiness<multi>;
            $multi-found = True;
            last;
        }
    }
    return callsame if $multi-found;

    if Metamodel::Primitives.is_type(self, Metamodel::MethodContainer)
    && self.method_table($obj).{$method.name} =:= $method {
        TRACING Traced::Routine::Event, $method, multiness => $method.is_dispatcher ?? 'proto' !! '';
        callsame
    } elsif Metamodel::Primitives.is_type(self, Metamodel::PrivateMethodContainer)
         && self.private_method_table($obj).{$method.name} =:= $method {
        TRACING Traced::Routine::Event, $method, :prefix<!>;
        callsame
    } elsif Metamodel::Primitives.is_type(self, Metamodel::MetaMethodContainer)
         && self.meta_method_table($obj).{$method.name} =:= $method {
        my Mu $type := callsame;
        TRACING Traced::Routine::Event, self.^find_method($method.name), :prefix<^>;
        $type
    }
}

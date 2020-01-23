use v6.d;
use Traced::Routine;
unit role MetamodelX::Traced::AdHocMethod[Method:D $method is raw];

method compose(Mu $obj is raw, |) {
    my Bool:D $multi-found = False;
    if Metamodel::Primitives.is_type: self, Metamodel::MultiMethodContainer {
        for self.multi_methods_to_incorporate: $obj {
            next unless .code =:= $method;
            Traced::Routine.wrap: $_, multiness => 'multi';
            $multi-found = True;
            last;
        }
    }
    return callsame if $multi-found;

    if Metamodel::Primitives.is_type(self, Metamodel::MethodContainer)
    && self.method_table($obj).{$method.name} =:= $method {
        Traced::Routine.wrap: $method, multiness => $method.is_dispatcher ?? 'proto' !! '';
    } elsif Metamodel::Primitives.is_type(self, Metamodel::PrivateMethodContainer)
         && self.private_method_table($obj).{$method.name} =:= $method {
        Traced::Routine.wrap: $method, prefix => '!';
    } elsif Metamodel::Primitives.is_type(self, Metamodel::MetaMethodContainer)
         && self.meta_method_table($obj).{$method.name} =:= $method {
        Traced::Routine.wrap: $method, prefix => '^';
    }
    callsame
}

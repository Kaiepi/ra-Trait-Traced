use v6.d;
use Traced::Routine;
unit role MetamodelX::Traced::MethodContainer;

method compose(|) {
    my Mu $obj := callsame;
    for self.methods: $obj, :local -> Mu $method is raw {
        Traced::Routine.wrap: $method
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    $obj
}

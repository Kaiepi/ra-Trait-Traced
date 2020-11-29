use v6;
use Traced::Routine;
unit role MetamodelX::Traced::PrivateMethodContainer;

method compose(|) {
    my Mu $type := callsame;
    for self.private_methods: $type -> Mu $method is raw {
        Traced::Routine.wrap: $method, prefix => '!'
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    $type
}

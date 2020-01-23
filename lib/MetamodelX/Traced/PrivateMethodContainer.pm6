use v6.d;
use Traced::Routine;
unit role MetamodelX::Traced::PrivateMethodContainer;

method compose(|) {
    my Mu $obj := callsame;
    for self.private_methods: $obj -> Mu $method is raw {
        Traced::Routine.wrap: $method, prefix => '!'
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    $obj
}

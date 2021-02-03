use v6;
use Traced :TRACING;
use Traced::Routine :TRACING;
unit role MetamodelX::Traced::PrivateMethodContainer;

method compose(|) {
    my Mu $type := callsame;
    for self.private_methods: $type -> Mu $method is raw {
        TRACING Traced::Routine::Event, $method, :prefix<!>
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    $type
}

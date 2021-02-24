use v6;
use Traced :TRACING;
use Traced::Routine :TRACING;
unit role MetamodelX::Traced::PrivateMethodContainer;

method compose(::?CLASS:D: Mu $package is raw --> Mu) {
    for self.private_methods: $package -> Mu $method is raw {
        TRACING Traced::Routine::Event, $method, :prefix<!>
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    callsame
}

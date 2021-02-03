use v6;
use Traced :TRACING;
use Traced::Routine :TRACING;
unit role MetamodelX::Traced::MetaMethodContainer;

method compose(|) {
    my Mu $type := callsame;
    for self.meta_method_table($type).kv -> Str:D $name, Mu $method is raw {
        TRACING Traced::Routine::Event, self.^find_method($name), :prefix<^>
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    $type
}

use v6.d;
use Traced::Routine;
unit role MetamodelX::Traced::MetaMethodContainer;

method compose(|) {
    my Mu $obj := callsame;
    for self.meta_method_table($obj).kv -> Str:D $name, Mu $method is raw {
        Traced::Routine.wrap: self.^find_method($name), prefix => '^'
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    $obj
}

package haxescript;

#if macro
import haxe.macro.Context;
import haxe.macro.TypeTools;
#end

class ClassTools
{
    static final thisName:String = 'haxescript.ClassTools';

    macro static function build() 
    {
        Context.onGenerate(function(types) 
        {
            var names = [], self = TypeTools.getClass(Context.getType(thisName));
                
            for (t in types)
                switch t 
                {
                    case TInst(_.get() => c, _):
                        var name: Array<String> = c.pack.copy();
                        name.push(c.name);
                        names.push(Context.makeExpr(name.join("."), c.pos));
                    default:
                }

            self.meta.remove('classes');
            self.meta.add('classes', names, self.pos);
        });
        return macro cast haxe.rtti.Meta.getType($p{thisName.split('.')});
    }

    #if !macro
    static final names:Map<String, Class<Dynamic>> = {
        function returnMap()
        {
            var r = build().classes;
            var a:Array<String> = r;
            var map = new Map<String, Class<Dynamic>>();

            for (i in a) 
            {
                if (i.indexOf('_Impl_') == -1) // Private class
                {
                    var c = Type.resolveClass(i);
                    if (c != null)
                        map[i] = c;
                }
            }

            return map;
        }
        returnMap();
    }
    #end
}
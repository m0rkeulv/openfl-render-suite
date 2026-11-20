package rendertest;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
#end

/** The report page (common/template.html), read when the code is compiled so a report needs no files beside it. **/
class Template
{
	public static macro function page():haxe.macro.Expr
	{
		var here = Path.directory(Context.resolvePath("rendertest/Template.hx"));
		var file = Path.normalize(Path.join([here, "..", "..", "template.html"]));
		Context.registerModuleDependency("rendertest.Template", file);
		return macro $v{sys.io.File.getContent(file)};
	}
}

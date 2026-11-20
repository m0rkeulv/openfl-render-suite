package rendertest;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
	Classes a test uses that not every openfl has (GradientGlowFilter and GradientBevelFilter came
	later than develop, for instance). The suite builds against any openfl, so such a class is
	created through this macro: where the openfl being compiled lacks it, the expression is null
	instead of a compile error, and the test can report the case as not available.

		var glow = Optional.filter("openfl.filters.GradientGlowFilter", 4, 45, colours, alphas, ratios, 8, 8);
**/
class Optional
{
	/** `new <path>(args)` as a BitmapFilter when the class exists in this build, else null. **/
	public static macro function filter(path:String, args:Array<Expr>):ExprOf<openfl.filters.BitmapFilter>
	{
		try
		{
			Context.getType(path);
		}
		catch (e:Dynamic)
		{
			return macro(null : openfl.filters.BitmapFilter);
		}
		var parts = path.split(".");
		var type:TypePath = {name: parts.pop(), pack: parts};
		return macro(new $type($a{args}) : openfl.filters.BitmapFilter);
	}
}

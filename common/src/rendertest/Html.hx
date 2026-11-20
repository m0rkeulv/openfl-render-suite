package rendertest;

/**
	Building blocks for the reports, in the style of the OpenFL blend-mode report
	(common/template.html): numbered headings with a table of contents, sortable tables, chips
	coloured by "lower is better", figures that open in the page's image viewer.

	Table cells are JSON values, so the same tables can be stored in results.json and rendered
	later: a String, a number, null (a dash), or {v: number, t: text} for a number shown as text
	(sorts by v). A String that starts with "<td" is used as it is (see chip()).
**/
class Html
{
	public static function escape(text:String):String
	{
		return StringTools.htmlEscape(text == null ? "" : text, true);
	}

	/** A number shown as text, sorted by the number. **/
	public static function value(v:Float, ?text:String):Dynamic
	{
		return {v: v, t: text != null ? text : Std.string(v)};
	}

	/** A percentage, with the largest channel difference beside it when given. **/
	public static function percent(v:Float, ?maximum:Int):Dynamic
	{
		var text = fixed(v, 1) + "%" + (maximum != null ? ' (max $maximum)' : "");
		return value(round(v, 3), text);
	}

	/** `v` with `digits` decimals, rounded like C's printf (and Python's "%.1f"): on the exact value, halves to even. **/
	public static function fixed(v:Float, digits:Int):String
	{
		if (Math.isNaN(v)) return "NaN";
		var scaled = scaledInteger(Math.abs(v), digits);
		var text = Std.string(scaled);
		if (digits > 0)
		{
			while (text.length <= digits) text = "0" + text;
			text = text.substr(0, text.length - digits) + "." + text.substr(text.length - digits);
		}
		return (v < 0 && scaled != 0 ? "-" : "") + text;
	}

	/** `v` rounded to `digits` decimals the way fixed() rounds it (as Python's round() does). **/
	public static function round(v:Float, digits:Int):Float
	{
		var scaled = scaledInteger(Math.abs(v), digits);
		var result = scaled / Math.pow(10, digits);
		return v < 0 ? -result : result;
	}

	/**
		round(v * 10^digits) for v >= 0, decided on the exact product: the product's rounding error is
		kept (Dekker's two-product), so a value just under a half is not taken for one, and an exact
		half goes to the even neighbour.
	**/
	static function scaledInteger(v:Float, digits:Int):Float
	{
		var factor = Math.pow(10, digits);
		var product = v * factor;
		var error = productError(v, factor, product);
		var whole = Math.ffloor(product);
		var aboveHalf = (product - (whole + 0.5)) + error;
		if (aboveHalf > 0 || (aboveHalf == 0 && whole % 2 == 1)) whole++;
		return whole;
	}

	/** The exact a * b minus its floating-point product (Veltkamp split, no fused multiply-add needed). **/
	static function productError(a:Float, b:Float, product:Float):Float
	{
		var splitter = 134217729.0; // 2^27 + 1
		var ca = splitter * a, cb = splitter * b;
		var aHigh = ca - (ca - a), aLow = a - aHigh;
		var bHigh = cb - (cb - b), bLow = b - bHigh;
		return ((aHigh * bHigh - product) + aHigh * bLow + aLow * bHigh) + aLow * bLow;
	}

	/** A score with its unit: "3.1%", "4 cells", "0.53", "2917.3 ms" (whole numbers without decimals). **/
	public static function scoreText(value:Float, unit:String):String
	{
		if (unit == "%") return fixed(value, 1) + "%";
		var number = value == Math.ffloor(value) ? fixed(value, 0) : fixed(value, unit == "ms" ? 1 : 2);
		return unit != "" ? number + " " + unit : number;
	}

	/** match for 0, minor below `minor`, off from there: the colour scale for differences. **/
	public static function chipClass(v:Float, minor:Float = 1.0):String
	{
		return v == 0 ? "match" : (v < minor ? "minor" : "off");
	}

	/** A coloured pill in a sortable cell; `cls` overrides the scale ("match", "minor", "off", "none"). **/
	public static function chip(v:Float, ?text:String, ?cls:String, ?href:String):String
	{
		var body = escape(text != null ? text : fixed(v, 1) + "%");
		if (href != null) body = '<a href="$href">$body</a>';
		return '<td class="n" data-v="$v"><span class="chip ${cls != null ? cls : chipClass(v)}">$body</span></td>';
	}

	public static function dash():String
	{
		return '<td class="dim" data-v="-1">&ndash;</td>';
	}

	public static function cell(c:Dynamic):String
	{
		if (c == null) return dash();
		if (Std.isOfType(c, String))
		{
			var s:String = c;
			return StringTools.startsWith(s, "<td") ? s : "<td>" + escape(s) + "</td>";
		}
		if (Std.isOfType(c, Bool)) return "<td>" + (c ? "yes" : "no") + "</td>";
		if (Std.isOfType(c, Float) || Std.isOfType(c, Int))
		{
			var f:Float = c;
			var text = (f == Math.ffloor(f)) ? Std.string(Std.int(f)) : trimZeros(fixed(f, 2));
			return '<td class="n" data-v="$f">$text</td>';
		}
		if (Reflect.hasField(c, "t"))
		{
			var v:Float = Reflect.field(c, "v");
			var t:String = Reflect.field(c, "t");
			var cls = "";
			if (StringTools.endsWith(t, "%") || t.indexOf("% (") > -1)
			{
				cls = " " + switch (chipClass(v))
				{
					case "match": "ok";
					case "minor": "warn";
					default: "bad";
				}
			}
			return '<td class="n$cls" data-v="$v">${escape(t)}</td>';
		}
		return "<td>" + escape(Std.string(c)) + "</td>";
	}

	static function trimZeros(text:String):String
	{
		if (text.indexOf(".") < 0) return text;
		while (StringTools.endsWith(text, "0")) text = text.substr(0, text.length - 1);
		if (StringTools.endsWith(text, ".")) text = text.substr(0, text.length - 1);
		return text;
	}

	/** A sortable table (click a header to sort). Long tables scroll in their own box. **/
	public static function table(columns:Array<String>, rows:Array<Array<Dynamic>>, ?caption:String, ?note:String, cls:String = "",
			tallAfter:Int = 25):String
	{
		var b = new StringBuf();
		if (caption != null) b.add('<p class="table-title">${escape(caption)}</p>');
		b.add('<div class="table-wrap${rows.length > tallAfter ? " tall" : ""}"><table class="sortable $cls"><thead><tr>');
		for (c in columns) b.add('<th scope="col"><button type="button">${escape(c)}</button></th>');
		b.add("</tr></thead><tbody>");
		for (row in rows)
		{
			b.add("<tr>");
			for (c in row) b.add(cell(c));
			b.add("</tr>");
		}
		b.add("</tbody></table></div>");
		if (note != null) b.add('<p class="note">${escape(note)}</p>');
		return b.toString();
	}

	/** Secondary content, closed until the reader opens it. **/
	public static function collapsed(inner:String, show:String, hide:String, ?note:String):String
	{
		return '<details class="develop"><summary><span class="show">${escape(show)}</span><span class="hide">${escape(hide)}</span></summary>'
			+ '<div class="develop-body">${note != null ? '<p class="develop-note">${escape(note)}</p>' : ""}$inner</div></details>';
	}

	/** An image that opens in the viewer; arrow keys move within `gallery`. `src` is relative to the page. **/
	public static function figure(src:String, width:Int, height:Int, caption:String, ?detail:String, gallery:String = ""):String
	{
		var s = escape(src);
		return '<figure><a class="zoom" href="$s" data-gallery="${escape(gallery)}"><img src="$s" width="$width" height="$height" loading="lazy" alt="${escape(caption)}"></a>'
			+ '<figcaption>${escape(caption)}${detail != null ? '<span class="detail">${escape(detail)}</span>' : ""}</figcaption></figure>';
	}

	/** Cards of figures; each card is a list of figure() strings or notes. **/
	public static function gallery(cards:Array<Array<String>>, wide:Bool = false):String
	{
		var b = new StringBuf();
		b.add('<div class="gallery ${wide ? "wide" : "narrow"}">');
		for (card in cards) b.add('<div class="pair">${card.join("")}</div>');
		b.add("</div>");
		return b.toString();
	}

	/** The card text beside a reference image. **/
	public static function refNote(text:String, lead:String = "The reference."):String
	{
		return '<div class="ref-note"><p><b>${escape(lead)}</b> ${escape(text)}</p></div>';
	}

	public static function callout(html:String):String
	{
		return '<p class="callout">$html</p>';
	}

	public static function paragraph(text:String):String
	{
		return "<p>" + escape(text) + "</p>";
	}

	/** items: [class, label, meaning], e.g. ["match", "match", "no pixel off"]. **/
	public static function legend(items:Array<Array<String>>):String
	{
		return '<p class="legend">' + [for (i in items) '<span class="chip ${i[0]}">${escape(i[1])}</span> ${escape(i[2])}'].join(" &nbsp; ") + "</p>";
	}
}

/** A report page: numbered headings (1, 1.1, 1.1.1 or appendix letters) collected into the contents. **/
class HtmlDoc
{
	var parts:Array<String> = [];
	var toc:Array<{level:Int, number:String, title:String, anchor:String}> = [];
	var counters = [0, 0, 0];

	public function new() {}

	public function heading(level:Int, title:String, anchor:String, ?appendix:String, inToc:Bool = true):Void
	{
		var number:String;
		if (appendix != null)
		{
			number = appendix;
		}
		else
		{
			counters[level - 1]++;
			for (i in level...3) counters[i] = 0;
			number = [for (i in 0...level) counters[i]].join(".");
		}
		if (inToc) toc.push({level: level, number: number, title: title, anchor: anchor});
		var tag = "h" + (level + 1);
		parts.push('<$tag id="$anchor"><span class="num">$number</span> ${Html.escape(title)}</$tag>');
	}

	public function add(html:String):Void
	{
		parts.push(html);
	}

	/** The page as HTML: `facts` are [label, value] pairs shown under the title. **/
	public function render(pageTitle:String, title:String, eyebrow:String, lead:String, facts:Array<Array<String>>, tocDepth:Int = 3):String
	{
		var contents = [
			for (t in toc)
				if (t.level <= tocDepth) '<li class="l${t.level}"><a href="#${t.anchor}"><span class="num">${t.number}</span> ${Html.escape(t.title)}</a></li>'
		].join("\n");
		var factList = [for (f in facts) '\t\t<li>${Html.escape(f[0])} <b>${Html.escape(f[1])}</b></li>'].join("\n");
		var page = Template.page();
		for (pair in [
			["PAGE_TITLE", Html.escape(pageTitle)],
			["TITLE", Html.escape(title)],
			["EYEBROW", Html.escape(eyebrow)],
			["LEAD", lead],
			["FACTS", factList],
			["TOC", contents],
			["BODY", parts.join("\n")]
		])
			page = StringTools.replace(page, "{{" + pair[0] + "}}", pair[1]);
		return page;
	}
}

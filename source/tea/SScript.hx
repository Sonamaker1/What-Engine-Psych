package tea;

import ex.*;

import haxe.Exception;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import tea.backend.*;
import haxescript.*;

using StringTools;

typedef TeaCall =
{
	#if sys
	/**
		Script's file name. Will be null if the script is not from a file. 
		
		Not available on JavaScript.
	**/
	public var ?fileName(default, null):String;
	#end
	
	/**
		If call has been successful or not. 
	**/
	public var succeeded(default, null):Bool;

	/**
		Function's name that has been called. 
	**/
	public var calledFunction(default, null):String;

	/**
		Function's return value. Will be if null if there is no value returned.
	**/
	public var returnValue(default, null):Null<Dynamic>;

	/**
		Exceptions in this call. Will be empty if there are not any.
	**/
	public var exceptions(default, null):Array<Exception>;
}

/**
	The base class for dynamic Haxe scripts.
**/
@:structInit
@:access(haxescript.Interp)
@:access(haxescript.Parser)
@:keepSub
class SScript
{	
	/**
		Variables in this map will be set to every existing Teas. 
	**/
	public static var globalVariables:GlobalSScriptMap = new GlobalSScriptMap();
	
	/**
		Every created Tea will be mapped to this map. 
	**/
	public static var global(default, null):Map<String, SScript> = [];
	
	static var IDCount(default, null):Int = 0;

	static var BlankReg(get, never):EReg;

	/**
		Script's own return value.
		
		This is not to be messed up with function's return value.
	**/
	public var returnValue(default, null):Null<Dynamic>;

	/**
		Use this to access to interpreter's variables!
	**/
	public var variables(get, never):Map<String, Dynamic>;

	/**
		Main interpreter and executer for this script.
	**/
	public var interp(default, null):Interp;

	/**
		An unique parser for the script to parse scripts.
	**/
	public var parser(default, null):Parser;

	/**
		The script to execute. Gets set automatically when you create a `new` Tea.
	**/
	public var script(default, null):String = "";

	/**
		This variable tells if this script is active or not.

		Set this to false if you do not want your script to get executed.
	**/
	public var active:Bool = true;

	/**
		This string tells you the path of your script file as a read-only string.
	**/
	public var scriptFile(default, null):String = "";

	/**
		Latest error in this script in parsing. Will be null if there aren't any errors.
	**/
	public var parsingException(default, null):Exception;

	@:noPrivateAccess var _destroyed(default, null):Bool;

	/**
		ID for this script, used for scripts with no script file.
	**/
	var ID(default, null):Null<Int> = null;

	/**
		Creates a new Tea.

		@param scriptPath The script path or the script itself.
		@param Preset If true, SScript will set some useful variables to interp. Override `preset` to customize the settings.
		@param startExecute If true, script will execute itself. If false, it will not execute.	
	**/
	public function new(?scriptPath:String = "", ?preset:Bool = true, ?startExecute:Bool = true)
	{
		interp = new Interp();
		parser = new Parser();

		if (preset)
			this.preset();

		for (i => k in globalVariables)
		{
			if (i != null)
				set(i, k);
		}

		try 
		{
			doFile(scriptPath);
			if (startExecute)
				execute();
		}

		interp.setScr(this);
	}

	/**
		Executes this script once.

		Executing scripts with classes will not do anything.
	**/
	public function execute():Void
	{
		if (_destroyed)
			return;

		if (interp == null || !active)
			return;

		var origin:String = #if hscriptPos {
			if (scriptFile != null && scriptFile.length > 0)
				scriptFile;
			else 
				"SScript";
		} #else null #end;

		if (script != null && script.length > 0)
		{
			resetInterp();
			
			try 
			{
				var expr:Expr = parser.parseString(script #if hscriptPos, origin #end);
				var r = interp.execute(expr);
				returnValue = r;
			}
			catch (e) 
			{
				parsingException = e;
				returnValue = null;
			}
		}
	}

	/**
		Sets a variable to this Tea. 

		If `key` already exists, it will be replaced.
		@param key Variable name.
		@param obj The object to set.
		@return Returns this instance for chaining.
	**/
	public function set(key:String, ?obj:Dynamic):SScript
	{
		if (_destroyed)
			return null;
		if (key == null || key.length < 1 || BlankReg.match(key))
			return null;

		if (obj == null && key.indexOf('.') > -1)
			return setClassString(key);

		function setVar(key:String, obj:Dynamic):Void
		{
			if (key == null)
				return;

			if (Tools.keys.contains(key))
				throw '$key is a keyword, set something else';

			if (!active)
				return;

			interp.variables[key] = obj;
		}

		setVar(key, obj);
		return this;
	}

	/**
		A special object is the object that'll get checked if a variable is not found in a Tea.
		
		Special object can't be basic types like Int, String, Float, Array and Bool.

		Instead, use it if you have a state instance.
		@param obj The special object. 
		@param includeFunctions If false, functions will be ignored in the special object. 
		@param exclusions Optional array of fields you want it to be excluded.
		@return Returns this instance for chaining.
	**/
	public function setSpecialObject(obj:Dynamic, ?includeFunctions:Bool = true, ?exclusions:Array<String>):SScript
	{
		if (_destroyed)
			return null;
		if (!active)
			return this;
		if (obj == null)
			return this;
		if (exclusions == null)
			exclusions = new Array();

		var types:Array<Dynamic> = [Int, String, Float, Bool, Array];
		for (i in types)
			if (Std.isOfType(obj, i))
				throw 'Special object cannot be ${i}';

		if (interp.specialObject == null)
			interp.specialObject = {obj : null , includeFunctions: null , exclusions: null };

		interp.specialObject.obj = obj;
		interp.specialObject.exclusions = exclusions.copy();
		interp.specialObject.includeFunctions = includeFunctions;
		return this;
	}

	/**
		This is a helper function to set classes or enums easily.

		For example; if `cl` is `sys.io.File` class, it'll be set as `File`.
		@param cl The class to set.
		@return this instance for chaining.
	**/
	public function setClass(cl:Dynamic):SScript
	{
		if (_destroyed)
			return null;
		
		if (cl == null)
		{			
			return null;
		}
		else if (!(cl is Enum) && !(cl is Class))
		{
			return null;
		}

		var clName:String = if (cl is Enum) Type.getEnumName(cl) else Type.getClassName(cl);
		if (clName != null)
		{
			var splitCl:Array<String> = clName.split('.');
			if (splitCl.length > 1)
			{
				clName = splitCl[splitCl.length - 1];
			}

			set(clName, cl);
		}
		return this;
	}

	/**
		Sets a class or an enum to this script from a string.

		`cl` will be formatted, for example: `sys.io.File` -> `File`.
		@param cl The class to set.
		@return this instance for chaining.
	**/
	public function setClassString(cl:String):SScript
	{
		if (_destroyed)
			return null;

		if (cl == null || cl.length < 1)
		{
			return null;
		}

		var cls:Dynamic = Type.resolveClass(cl);
		if (cls == null)
			cls = Type.resolveEnum(cl);
		if (cls != null)
		{
			if (cl.split('.').length > 1)
			{
				cl = cl.split('.')[cl.split('.').length - 1];
			}

			set(cl, cls);
		}
		return this;
	}

	public function locals():Map<String, Dynamic>
	{
		if (_destroyed)
			return null;

		if (!active)
			return [];

		var newMap:Map<String, Dynamic> = new Map();
		for (i in interp.locals.keys())
		{
			var v = interp.locals[i];
			if (v != null)
				newMap[i] = v.r;
		}
		return newMap;
	}

	/**
		Removes a variable from this script. 

		If a variable named `key` doesn't exist, unsetting won't do anything.
		@param key Variable name to remove.
		@return Returns this instance for chaining.
	**/
	public function unset(key:String):SScript
	{
		if (_destroyed)
			return null;

		if (interp == null || !active || key == null || !interp.variables.exists(key))
			return null;

		interp.variables.remove(key);
		return this;
	}

	/**
		Gets a variable by name. 

		If a variable named as `key` does not exists return is null.
		@param key Variable name.
		@return The object got by name.
	**/
	public function get(key:String):Dynamic
	{
		if (_destroyed)
			return null;

		if (interp == null || !active)
		{
			return null;
		}

		var l = locals();
		if (l.exists(key))
			return l[key];

		return if (interp.variables.exists(key)) interp.variables[key] else null;
	}

	/**
		Calls a function the script.

		`WARNING:` You MUST execute the script at least once to get the functions to script's interpreter.
		If you do not execute this script and `call` a function, script will ignore your call.

		@param func Function name in script file. 
		@param args Arguments for the `func`. If the function does not require arguments, leave it null.
		@return Returns an unique structure that contains called function, returned value etc. Returned value is at `returnValue`.
	**/
	public function call(func:String, ?args:Array<Dynamic>):TeaCall
	{
		if (_destroyed)
			return {
				exceptions: [new Exception((if (scriptFile != null && scriptFile.length > 0) scriptFile else "SScript instance") + " is destroyed.")],
				calledFunction: func,
				succeeded: false,
				returnValue: null
			};

		if (!active)
			return {
				exceptions: [new Exception((if (scriptFile != null && scriptFile.length > 0) scriptFile else "SScript instance") + " is not active.")],
				calledFunction: func,
				succeeded: false,
				returnValue: null
			};

		var scriptFile:String = if (scriptFile != null && scriptFile.length > 0) scriptFile else "";
		var caller:TeaCall = {
			exceptions: [],
			calledFunction: func,
			succeeded: false,
			returnValue: null
		}
		#if sys
		if (scriptFile != null && scriptFile.length > 0)
			Reflect.setField(caller, "fileName", scriptFile);
		#end
		if (args == null)
			args = new Array();

		var pushedExceptions:Array<String> = new Array();
		function pushException(e:String)
		{
			if (!pushedExceptions.contains(e))
				caller.exceptions.push(new Exception(e));
			
			pushedExceptions.push(e);
		}
		if (func == null)
		{
			return caller;
		}
		
		var fun = get(func);
		if (exists(func) && Type.typeof(fun) != TFunction)
		{
			pushException('$func is not a function');
		}
		else if (interp == null || !exists(func))
		{
			if (scriptFile != null && scriptFile.length > 1)
				pushException('Function $func does not exist in $scriptFile.');
			else 
				pushException('Function $func does not exist in SScript instance.');
		}
		else 
		{
			var oldCaller = caller;
			try
			{
				var functionField:Dynamic = Reflect.callMethod(this, fun, args);
				caller = {
					exceptions: caller.exceptions,
					calledFunction: func,
					succeeded: true,
					returnValue: functionField
				};
				#if sys
				if (scriptFile != null && scriptFile.length > 0)
					Reflect.setField(caller, "fileName", scriptFile);
				#end
			}
			catch (e)
			{
				caller = oldCaller;
				caller.exceptions.insert(0, e);
			}
		}

		return caller;
	}

	/**
		Clears all of the keys assigned to this script.

		@return Returns this instance for chaining.
	**/
	public function clear():SScript
	{
		if (_destroyed)
			return null;
		if (!active)
			return this;

		if (interp == null)
			return this;

		var importantThings:Array<String> = ['true', 'false', 'null', 'trace'];

		for (i in interp.variables.keys())
			if (!importantThings.contains(i))
				interp.variables.remove(i);

		return this;
	}

	/**
		Tells if the `key` exists in this script's interpreter.
		@param key The string to look for.
		@return Returns true if `key` is found in interpreter.
	**/
	public function exists(key:String):Bool
	{
		if (_destroyed)
			return false;
		if (!active)
			return false;

		if (interp == null)
			return false;
		var l = locals();
		if (l.exists(key))
			return l.exists(key);

		return interp.variables.exists(key);
	}

	/**
		Sets some useful variables to interp to make easier using this script.

		Override this function to set your custom variables as well.
	**/
	public function preset():Void
	{
		if (_destroyed || !active)
			return;

		setClass(Date);
		setClass(DateTools);
		setClass(Math);
		setClass(Reflect);
		setClass(Std);
		setClass(StringTools);
		setClass(Type);

		#if sys
		setClass(File);
		setClass(FileSystem);
		setClass(Sys);
		#end
	}

	function resetInterp():Void
	{
		if (_destroyed)
			return;

		interp.locals = #if haxe3 new Map() #else new Hash() #end;
		while (interp.declared.length > 0)
			interp.declared.pop();

		parser = new Parser();
	}

	function doFile(scriptPath:String):Void
	{
		parsingException = null;

		if (_destroyed)
			return;

		if (scriptPath == null || scriptPath.length < 1 || BlankReg.match(scriptPath))
		{
			ID = IDCount + 1;
			IDCount++;
			global[Std.string(ID)] = this;
			return;
		}

		if (scriptPath != null && scriptPath.length > 0)
		{
			#if sys
				if (FileSystem.exists(scriptPath))
				{
					scriptFile = scriptPath;
					script = File.getContent(scriptPath);
				}
				else
				{
					scriptFile = "";
					script = scriptPath;
				}
			#else
				scriptFile = "";
				script = scriptPath;
			#end

			if (scriptFile != null && scriptFile.length > 0)
				global[scriptFile] = this;
			else if (script != null && script.length > 0)
				global[script] = this;
		}
	}

	/**
		Executes a string once instead of a script file.

		This does not change your `scriptFile` but it changes `script`.

		@param string String you want to execute. If this argument is a file, this will act like `new` and will change `scriptFile`.
		@param origin Optional origin to use for this script, it will appear on traces.
		@return Returns this instance for chaining. Will return `null` if failed.
	**/
	public function doScript(string:String #if hscriptPos, ?origin:String #end):SScript
	{
		if (_destroyed)
			return null;
		if (!active)
			return null;
		if (string == null || string.length < 1 || BlankReg.match(string))
			return this;

		parsingException = null;
		try 
		{
			#if sys
			if (FileSystem.exists(string))
			{
				scriptFile = string;
				#if hscriptPos
				origin = string;
				#end
				string = File.getContent(string);
			}
			#end

			#if hscriptPos
			var og:String = origin;
			if (og == null || og.length < 1)
				og = "SScript";
			#end

			if (!active || interp == null)
				return null;

			resetInterp();

			try
			{	
				script = string;

				if (scriptFile != null && scriptFile.length > 0)
				{
					if (ID != null)
						global.remove(Std.string(ID));
					global[scriptFile] = this;
				}
				else if (script != null && script.length > 0)
				{
					if (ID != null)
						global.remove(Std.string(ID));
					global[script] = this;
				}

				var expr:Expr = parser.parseString(script #if hscriptPos , og #end);
				var r = interp.execute(expr);
				returnValue = r;
			}
			catch (e)
			{
				script = "";
				parsingException = e;
				returnValue = null;
			}
		}

		return this;
	}

	inline function toString():String
	{
		if (_destroyed)
			return "null";

		if (scriptFile != null && scriptFile.length > 0)
			return scriptFile;

		return "[SScript]";
	}

	/**
		This function makes this script completely unusable.

		If you don't want to destroy your script, just set `active` to false!
	**/
	public function kill():Void
	{
		if (_destroyed)
			return;

		if (global.exists(script) && script != null && script.length > 0)
			global.remove(script);
		if (global.exists(scriptFile) && scriptFile != null && scriptFile.length > 0)
			global.remove(scriptFile);

		clear();

		parser = null;
		interp.specialObject.obj = null;
		interp.specialObject = null;
		interp = null;
		script = null;
		scriptFile = null;
		active = false;
		ID = null;
		parsingException = null;
		returnValue = null;
		_destroyed = true;
	}

	function get_variables():Map<String, Dynamic>
	{
		if (_destroyed)
			return null;

		return interp.variables;
	}

	static function get_BlankReg():EReg 
	{
		return ~/^[\n\r\t]$/;
	}
}
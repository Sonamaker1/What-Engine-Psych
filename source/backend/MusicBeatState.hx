package backend;

import psychlua.FunkinLua;
import backend.Conductor.BPMChangeEvent;
import flixel.FlxG;
import flixel.addons.ui.FlxUIState;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.FlxBasic;
import flixel.system.FlxSound;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxAssets.FlxShader;
import flixel.FlxSubState;
import psychlua.ModchartSprite;

#if VIDEOS_ALLOWED 
#if (hxCodec >= "3.0.0") import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler as VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#else import vlc.MP4Handler as VideoHandler; #end
#end

#if !html5
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

interface BeatStateInterface {
	public var camGame:FlxCamera;
	//public var members(default, null):Array<Dynamic>;
	
	private var curStep:Int;
	private var curBeat:Int;

	private var curDecStep:Float;
	private var curDecBeat:Float;
	public var controls(get, never):Controls;
	
	public function get_controls():Controls;

	public function runHScript(name:String, hscript:psychlua.HScript, ?modFolder:String, ?isCustomState:Bool):Void;

	public function getControl(key:String):Bool;
	
	//public function callStageFunctions(event:String,args:Array<Dynamic>,gameStages:Map<String,FunkyFunct>):Void;

	public var gameStages:Map<String,FunkyFunct>;
	public var variables:Map<String, Dynamic>;
	public var modchartTweens:Map<String, FlxTween>;
	public var modchartSprites:Map<String, ModchartSprite>;
	public var modchartTimers:Map<String, FlxTimer>;
	public var modchartSounds:Map<String, FlxSound>;
	public var modchartTexts:Map<String, FlxText>;
	public var modchartSaves:Map<String, FlxSave>;
	public var runtimeShaders:Map<String, Array<String>>;
	

	private function updateBeat():Void;

	private function updateCurStep():Void;
	public var persistentUpdate:Bool;

	//public function remove(Object:FlxBasic, ?Splice:Bool = false):FlxBasic;
	//public function callOnLuas(event:String, args:Array<Dynamic>, ?ignoreStops:Bool, ?exclusions:Array<String>):Dynamic;
	

	public function stepHit():Void;

	public function beatHit():Void;

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite;
}

class MusicBeatState extends FlxUIState implements BeatStateInterface
{
	public var camGame:FlxCamera;
	
	public var gameStages:Map<String,FunkyFunct>;
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var controls(get, never):Controls;

	#if (haxe >= "4.0.0")
	public var variables:Map<String, Dynamic> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, FlxText> = new Map<String, FlxText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	#else
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartSprites:Map<String, ModchartSprite> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, FlxText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();
	#end
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	//public static var gameStages:Map<String,FunkyFunct> = new Map<String,FunkyFunct>();
	

	public static var camBeat:FlxCamera;

	public function get_controls()
	{
		return Controls.instance;
	}

	/*public function get_controls():Controls
		return PlayerSettings.player1.controls;*/
	public var hscripter:psychlua.HScript;
	
	public function quickCallHscript(eventName:String, args:Array<Dynamic>){
		if (args == null){
			args=[];
		}
		try{
			var ret = gameStages.get(eventName);
			if(ret!=null){
				Reflect.callMethod(null, ret.func, args);
				return;
			}
			else{
				var ret2 = hscripter.variables.get(eventName);
				if(ret2 != null){
					Reflect.callMethod(null, ret2, args);
				}
			}
		}
		catch(err){
			if((""+err)!="Null Object Reference"){
				trace("\n["+eventName+"] Function Error: " + err);
			}
		}
	}

	public function runHScript(name:String, hscript:psychlua.HScript, ?modFolder:String="", ?isCustomState:Bool=false){
		function traced(thingToPrint:String){
			//trace(thingToPrint);
		}

		try{		
			var path:String = "mods/"+modFolder+"/"+name; // Paths.getTextFromFile(name);
			var y = '';
			//PLEASE WORK
			
			if (FileSystem.exists(path)){
				traced(path);
				hscripter = new psychlua.HScript(null, path);
				//y = File.getContent(path);
			}else if(FileSystem.exists(Paths.modFolders(name))){
				traced(Paths.modFolders(modFolder+"/"+name));
				hscripter = new psychlua.HScript(null, path);
				//y = File.getContent(path);
			}else if(FileSystem.exists(Paths.modFolders(modFolder+"/"+name))){
				traced(Paths.modFolders(modFolder+"/"+name));
				hscripter = new psychlua.HScript(null, path);
				//y = File.getContent(path);
			}else if(FileSystem.exists(modFolder+"/"+name)){
				traced(modFolder+"/"+name);
				hscripter = new psychlua.HScript(null, path);
				//y = File.getContent(path);
			}else if(FileSystem.exists(Paths.modFolders(name))){
				traced(Paths.modFolders(name));
				hscripter = new psychlua.HScript(null, path);
				//y = File.getContent(path);
			}else{
				trace(path + "Does not exist");
				//hscripter = new psychlua.HScript(null, path);
				//y = Paths.getTextFromFile(modFolder+"/"+name);
				if(isCustomState){
					MusicBeatState.switchState(new states.MainMenuState());
				}
			}
			
		}
		catch(err){
			trace(err);
		}
	}


	override function create() {
		gameStages = new Map<String,FunkyFunct>();
		camBeat = FlxG.camera;
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		super.create();

		if(!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
		quickCallHscript("super_create", []);
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		quickCallHscript("super_update", []);
		//everyStep();
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if(curStep > 0)
				stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		super.update(elapsed);
		quickCallHscript("super_updatePost", []);
	}

	public function onVideoEnd(filepath:String, success:Bool = true)
	{
		quickCallHscript("onVideoEnd", [filepath, success]);
		//callStageFunctions("onVideoEnd",[filepath, success]);
	}

	public var inCutscene:Bool = false;
	
	public function startVideo(name:String)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;

		var filepath:String = Paths.video(name);
		#if sys
		if(!FileSystem.exists(filepath))
		#else
		if(!OpenFlAssets.exists(filepath))
		#end
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			onVideoEnd(filepath, false);
			return;
		}

		var video:VideoHandler = new VideoHandler();
			#if (hxCodec >= "3.0.0")
			// Recent versions
			video.play(filepath);
			video.onEndReached.add(function()
			{
				video.dispose();
				onVideoEnd(filepath);
				return;
			}, true);
			#else
			// Older versions
			video.playVideo(filepath);
			video.finishCallback = function()
			{
				onVideoEnd(filepath);
				return;
			}
			#end
		#else
		FlxG.log.warn('Platform not supported!');
		onVideoEnd(filepath, false);
		return;
		#end
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	
	/*
	public function callStageFunctions(event:String,args:Array<Dynamic>,gameStages:Map<String,FunkyFunct>){
		try{
			var ret = gameStages.get(event);
			if(ret != null){
				//trace(event);
				Reflect.callMethod(null, ret.func, args);
				
				//gameParameters.set("args", args);
				//ret.func();
			}
			//trace(ret+"("+event+")");
		}
		catch(err){
			trace("\n["+event+"] Stage Function Error: " + err);
		}
	}
	*/
	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}


	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState = null) {
		//quickCallHscript("static_switchState", []);
		if(nextState == null) nextState = FlxG.state;
		if(nextState == FlxG.state)
		{
			resetState();
			trace('resetted');
			return;
		}

		//trace('changed state');
		var name = Type.getClassName(Type.getClass(nextState));
		name = name.replace('.','/');
		name = name.replace('State','Addons.hx');

		
		//trace('['+name+']');
		trace('New State: ['+ name +']');
		//nextState.
		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;

		cast(nextState, MusicBeatState).runHScript(name, null);
	}

	public static function resetState() {
		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null)
	{
		if(nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.6, false));
		if(nextState == FlxG.state)
			CustomFadeTransition.finishCallback = function() FlxG.resetState();
		else
			CustomFadeTransition.finishCallback = function() FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
		quickCallHscript("super_stepHit", []);
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
		quickCallHscript("super_beatHit", []);
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
		quickCallHscript("super_sectionHit", []);
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		if(variables.exists(tag)) return variables.get(tag);
		return null;
	}
}

/*class ModchartSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	//public var isInFront:Bool = false;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.globalAntialiasing;
	}
}*/



class ModchartText extends FlxText
{
	public var wasAdded:Bool = false;
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);
		setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		cameras = [PlayState.instance.camHUD];
		scrollFactor.set();
		borderSize = 2;
	}
}

// For SScript usage lol
typedef FunkyFunct = {
    var func:Void->Void;
}

package tools;

import backend.Paths;
import haxe.Int64;
import lime.media.AudioBuffer;
import lime.media.AudioSource;
import openfl.media.Sound;
import flixel.FlxG;

class SoundCompare
{
    //A sorta hacky solution I coded for another mod lol - Whatify
    public static function looseEquals(a:Sound,b:Sound):Bool
    {
        // SoundCompare counts the number of samples across all channels of two given sounds.
        // If they equal, then that's the file (or at least one of the same exact length in samples)

        // Why is there no way to just get a reliable comparison aaaaaaaa
        @:privateAccess(Sound){
            if (a.__buffer.data != null)
            {
                var samplesA = (a.__buffer.data.length * 8) / (a.__buffer.channels * a.__buffer.bitsPerSample);
                var samplesB = (b.__buffer.data.length * 8) / (b.__buffer.channels * b.__buffer.bitsPerSample);
                return samplesA == samplesB;
            }
            else if (a.__buffer.__srcVorbisFile != null)
            {
                var samplesA = Int64.toInt(a.__buffer.__srcVorbisFile.pcmTotal());
                var samplesB = Int64.toInt(b.__buffer.__srcVorbisFile.pcmTotal());
                return samplesA == samplesB;
            }
            return false;
        }
    }

    public static function forcePlaying(SoundFile:Sound){
        @:privateAccess(FlxSound){
			if( (FlxG.sound.music == null) || !looseEquals(FlxG.sound.music._sound, SoundFile ) ) {
				FlxG.sound.playMusic(SoundFile, 0);
			}
		}
    }

}

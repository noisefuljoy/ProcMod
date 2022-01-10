/*
This script exemplifies the use of SuperCollider on Bela.
When a project contains a `_main.scd` file, `sclang` is started
and the content of the file is executed.
The examples in SuperCollider/ include more code examples to interface
with Bela-specific UGens.
If you want to interact with SuperCollider running on the board
from within the SuperCollider IDE on your computer, check out
the SuperCollider/7-remote-control examples instead.
*/
s = Server.default;

s.options.numAnalogInChannels = 8; // can be 2, 4 or 8
s.options.numAnalogOutChannels = 8; // can be 2, 4 or 8
s.options.numDigitalChannels = 16;
s.options.maxLogins = 8;

s.options.pgaGainLeft = 5;     // sets the pregain for the left audio input (dB)
s.options.pgaGainRight = 5;    // sets the pregain for the right audio input (dB)
s.options.headphoneLevel = -5; // sets the headphone level (-dB)
s.options.speakerMuted = 1;    // set true to mute the speaker amp and draw a little less power
s.options.dacLevel = 0;       // sets the gain of the stereo audio dac (+dB)
s.options.adcLevel = 0;       // sets the gain of the stereo audio adc (+dB)

s.options.blockSize = 512;
s.options.numInputBusChannels = 10;
s.options.numOutputBusChannels = 2;
s.options.postln;

s.waitForBoot({

SynthDef(\trillraw, {|t_recalibrate=0.0|
		var i2c_bus = 1;
		var i2c_address = 0x30;
		var noiseThreshold = 0.025; // float: 0-0.0625, with 0.0625 being the highest noise thresh
		var prescalerOpt = 1; // int: 1-8 with 1 being the highest sensitivity
		var touchsigs = DC.ar(0).dup(3); // use 3 touches
		var centroids;
		var out, ping;
		centroids = TrillRaw.kr(i2c_bus, i2c_address, noiseThreshold, prescalerOpt, t_recalibrate);
		SendReply.kr(Impulse.kr(10), "/trill", centroids);
	}).add;

~nyquist = s.sampleRate * 0.5;

SynthDef(\radiorecorder, {|in bufnum|
	var input = In.ar(in, 1);
	input = Compander.ar(input, input, 0.001, 1, 0.001, 0.001, 0.1,1000);
	//input = Compander.ar(input, input, 0.001,1,0.01,0.001,0.1,50);
	//for hardware input
	//RecordBuf.ar(SoundIn.ar(in),bufnum);
	//for bus
	RecordBuf.ar(input,bufnum);
}).store;

//SYNTHS
//second generation sampler
SynthDef(\recrecorder, {|in bufnum|
	//for hardware input
	//RecordBuf.ar(SoundIn.ar(in),bufnum);
	//for bus
	var input = In.ar(in, 1);
	input = Compander.ar(input, input, 0.001,1,0.01,0.001,0.1,200);
	//input = Compander.ar(input, input, 0.001,1,0.01,0.001,0.1,50);
	RecordBuf.ar(input,bufnum,loop:0,doneAction:2);
}).store;
//sampleplayer

SynthDef(\radioplay, {|out amp mainvolBus start end release=0.005 trig=1 octave=1 reverse=1 vectorOut bufnum xpan= -0.5 ypan=1.0 nyquist sampleRate|
	//var start = In.kr(startBus, 1);
	var mainvol = In.kr(mainvolBus, 1);
	var loopdur = (end - start)/sampleRate*(1/octave);

	var trigger = EnvGen.kr(Env([1,0],[loopdur*0.95]),1);
	var env = EnvGen.ar(Env.adsr(loopdur*0.3,loopdur*0.1,1,loopdur*0.05),trigger,doneAction:2);
	var sig = BufRd.ar(1, bufnum, Phasor.ar(trig, BufRateScale.kr(bufnum)*reverse*octave,start,end ),loop: 0) * env * amp;
	//var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum),trig, loop: 1);
	//Out.ar(out, Pan2.ar(sig, LFNoise1.kr(Rand(0.8,3.2)).range(pan,pan+0.25)));
	//loopdur.poll;
	//Out.ar(out, Pan4.ar(sig, LFNoise2.kr(Rand(0.1,6.4)).range(xpan,xpan+1.0),LFNoise2.kr(Rand(0.1,14.4)).range(ypan,ypan+1.0,)));
	sig = LPF.ar(sig, nyquist);
		sig = HPF.ar(sig, 30);


	Out.ar(out, Pan2.ar(sig*mainvol*0.5, LFNoise1.kr(Rand(0.8,3.2)).range(-0.5,0.5)));

/*
	Out.ar(out, PanAz.ar(6, sig*mainvol*0.5,
				LFNoise1.kr(Rand(0.8,3.2)).range(0.0,0.5),1.0,6.0,0.5));
*/

	//Out.ar(out, sig*mainvol);
	Out.ar(vectorOut,sig);
}).store;

//synth for granular patterns
SynthDef(\radioplaypattern, {|out=0 ampBus lengthBus start=0 endBus octave=1 trig=1 reverse=1 bufnum envbuf xpos=0 ypos=0 vectorOut nyquist|
	//var trigger = EnvGen.kr(Env([0,1,0],[0.001,0.001]),trig);
	var amp = In.kr(ampBus, 1);
	var end = In.kr(endBus, 1);
	var length = In.kr(lengthBus, 1);
	var env = Osc1.ar(envbuf, length*Rand(0.125,0.5));
	var sig = BufRd.ar(1, bufnum, Phasor.ar(trig, BufRateScale.kr(bufnum)*reverse*octave,start,end ),loop: 1) * env * 1;
	//var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum),trig, loop: 1);
	//Out.ar(out, Pan2.ar(sig, LFNoise1.kr(Rand(0.8,3.2)).range(pan,pan+0.25)));
	//Out.ar(out, Pan4.ar(sig, xpos, ypos));
	sig = LPF.ar(sig, nyquist);
	FreeSelfWhenDone.kr(sig);
	//Out.ar(out, Pan2.ar(sig*amp, 0));

	Out.ar(out, Pan2.ar(sig*amp,LFNoise0.kr(3.2).range(-1.0,1.0)) );

			/*
	Out.ar(out, PanAz.ar(6, sig*amp,
				LFNoise0.kr(3.2).range(0.0,1.0),1.0,6.0,0.5));

*/
	//Out.ar(vectorOut, sig);
	}).store;

//for recording zitar
SynthDef(\zitarRecorder, {|in=0 amplitudeBus fftbuf recbuf|
var input = SoundIn.ar(in);
var chain = FFT(fftbuf, input);
var onsets = Onsets.kr(chain,0.3);
var amplitude = Amplitude.kr(input);

//input = Compander.ar(input, input, 0.001,1,0.001,0.001,0.1,500);
//amplitude.poll;
RecordBuf.ar(input, recbuf,loop:0,trigger:onsets);
Out.kr(amplitudeBus, amplitude); }).add;


//3rd generation granulation
SynthDef(\regranulate, {|out=0 recOut ampBus lengthBus start=0 endBus octave=1 trig=1 reverse=1 bufnum envbuf pan=0 vectorOut nyquist|
	//var trigger = EnvGen.kr(Env([0,1,0],[0.001,0.001]),trig);
	var amp = In.kr(ampBus, 1);
	var end = In.kr(endBus, 1);
	var length = In.kr(lengthBus, 1);
	var env = Osc1.ar(envbuf, length, doneAction: 2);
	var sig = BufRd.ar(1, bufnum, Phasor.ar(trig, BufRateScale.kr(bufnum)*reverse*octave,start,end ),loop: 1) * env * 0.5;
	//var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum),trig, loop: 1);
	sig = LPF.ar(sig, nyquist);
	//Out.ar(out, Pan2.ar(sig * amp));

	Out.ar(out, Pan2.ar(sig*amp,LFNoise0.kr(3.2).range(-1.0,1.0)) );
			/*
	Out.ar(out, PanAz.ar(6, sig*amp,
				LFNoise0.kr(3.2).range(0.0,1.0),1.0,6.0,0.5));
	*/

	Out.ar(recOut, sig*3);
	}).store;

SynthDef(\pumper, {|in out amp=0.5|
	var input = In.ar(in, 1);
	input = Compander.ar(input, input, 0.001,1, 0.001, 0.001,0.1,1000);
	//Out.ar(out, Pan2.ar(input*amp))
	Out.ar(out,  input * amp);
		}).store;
//~sirene = Buffer.read(s, "pseudo_esoterische/sirenes.aiff");
//~khal = Buffer.read(s, "/Users/sjoerdleijten/PROJECTS/PubliekEnsemble/khalid_test_intro.aiff");
//~radioNoiseFiles = "/Users/sjoerdleijten/Dropbox/Samples/radiosamples/amreceiverimpro_selection/*.wav".pathMatch;
//~radioNoises = ~radioNoiseFiles.collect({|i| Buffer.read(s, i); });


// OSCdef(\kleur, {|msg time addr recvPort|
// 	~endRecBus[0].set( ((~lengthSpec.map(msg[1]))*~recrecBufs[0].numFrames););
// 	~endRecBus[1].set( ((~lengthSpec.map(msg[2]))*~recrecBufs[1].numFrames););
// 	~octave[1].put(0, ~octaves[~octaveSpec.map(msg[3])];);
// 		if ( ~playSwitches[1][0] == 1, {
// 			~playGroups[1][0].set(\octave, ~octave[1][0]); });
// 	~octave[1].put(1, ~octaves[~octaveSpec.map(msg[1])]); ~octave[1][1].postln;
// 		if ( ~playSwitches[1][1] == 1, {
// 			~playGroups[1][1].set(\octave, ~octave[1][1]); });
// 	}, '/colour');

//prime_def



// OSCdef(\izzy, {|msg time addr recvPort|
// 		7.do{|i|
// 			case
// 			{ i == 0 } {
// 				~endBus[0].set(~lengthSpec.map(msg[i+1])*~bike0smpls[~samNum1].numFrames);
// 				~endBus[1].set(~lengthSpec.map(msg[i+1])*~bike1smpls[~samNum2].numFrames);

// 				~octave[0].put(0, ~octaves[~octaveSpec.map(msg[i+1])];);
// 				if ( ~playSwitches[0][0] == 1, {
// 			~playGroups[0][0].set(\octave, ~octave[0][0]); });


// 			~octave[0].put(1, ~octaves[~octaveSpec.map(msg[i+1])]);
// 			if ( ~playSwitches[0][1] == 1, {
// 			~playGroups[0][1].set(\octave, ~octave[0][1]); });

// 			}
// 			{ i == 5 } {



// 			}
// 			{ i == 6 } {

// 			};

// 		};
// 	}, '/eyes');



~sireneGroup = Group.new;
~fftbuffers = Array.fill(2,{Buffer.alloc(s, 1024,1)});

~bike0smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];
~bike1smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];


~samNum1 = 0;
~samNum2 = 0;

~recBufs = Array.fill(2, { Array.fill(2, { Buffer.alloc(s, s.sampleRate * 10, 1); }); });
~recrecBufs = Array.fill(2, { Buffer.alloc(s, s.sampleRate * 10, 1); });
0.1.wait;
//groups
~synthGroup = Group.new;
~recGroup = Group.new;
//groups for sample loopers
~playGroups = Array.fill(2, { Array.fill(2, { Group.head(~synthGroup); }); });
~recGroups = Array.fill(2, {|i| Array.fill(2, {|j| Group.after(~playGroups[i][j]); }); });
//sampler groups
//group for resample grain loop
~recrecGroups = Array.fill(2, {|i| Group.after(~synthGroup); });
~compressGroup = Group.after(~synthGroup);

//buses for record sample loop
~vectorBuses = Array.fill(2, { Array.fill(2, { Bus.audio(s, 1); }); });
//compress buses
~compressBuses = Array.fill(8, {
	Array.fill(4, {
		Bus.audio(s, 1);}); });
~recrecbus = Array.fill(2, { Array.fill(2, { Bus.audio(s, 1); }); });

//control buses
~lengthBuses = Array.fill(4, { Array.fill(10, {Bus.control(s, 1).set(0.1)}); });
~startBuses = Array.fill(2, { Array.fill(2, { Bus.control(s, 1).set(0.0); }); });
~ampBuses = Array.fill(8, { Bus.control(s, 1).set(1.0); });
~ampBus = Array.fill(2, {  Bus.control(s,1).set(0.001); });
~endBus = [
			Bus.control(s, 1).set(~bike0smpls[~samNum1].numFrames),
			Bus.control(s, 1).set(~bike1smpls[~samNum2].numFrames) ];
~endRecBus = Array.fill(2, {|i| Bus.control(s, 1).set(~recrecBufs[i].numFrames); });

~recordBuf = Buffer.alloc(s, 1024,1);

//specs
~lengthSpec = [3.0,0.001,\exp].asSpec;
//~lengthSpec = [0.001, 1.0,\linear].asSpec;
//~endSpec = [0.001, 1.0,\linear].asSpec;
~endSpec = [1.0,0.0001,\exp].asSpec;
~clockSpec = [1.0, 3.0, \exp].asSpec;
~startSpec = [0.0,0.9,\linear].asSpec;
~vecFreqSpec = [1, 19000,\exp].asSpec;
~octaveSpec = [0,6,\linear,1,1].asSpec;
~radioplayAmpSpec = [0.5,0.1,\linear].asSpec;
//differentiate length specs
~lengthSpecs = Array.fill(10, {|i| [0.75-((i+1)/20.408163265306),0.001,\linear].asSpec; });

~chooseBus = Bus.control(s, 1).set(1);

~whatFirstGrainSample = [0,0];
~whatSecondGrainSample = [0,0];


//tempo clocks for grain patterns
~clocks = Array.fill(4, { TempoClock.new; });
~recordClock = TempoClock.new(1);
//sample buffers

//arrays for buttons / switches
~startValues = [[0.0, 0.0],[0.0,0.0]];
~reverseButtons = [[0,0],[0,0]];
~playButtons  = [[0,0],[0,0]];
~recButtons  = [[0,0],[0,0]];
~starts  = [[0,0],[0,0]];
~playSwitches = [[0,0],[0,0]];
~recSwitches = [[0,0],[0,0]];
~sampleLengths = [[1.0,1.0],[1.0,1.0]];
~octave = [[1,1],[1,1]];
~octaves = [0.0625,0.125,0.25,0.5,1,2,4];
~radioplayAmps = [[0.1,0.1],[0.1,0.1]];
//feedback gates for rec loops
~fbgates = [0,0];

//array for routine names
~routineNames = Array.fill(2,{|j| Array.fill(2, {|i| "~routineName"++j++i; }); });
~timeRoutineNames = Array.fill(2,{|j| Array.fill(2, {|i| "~timeRoutineName"++j++i; }); });

//compressors for four channels
~outArray = [0,0,0,0];
//8.do{|i| 4.do{|j| Synth(\pumper, [\in, ~compressBuses[i][j], \out, ~outArray[j]], ~compressGroup); }; };
//~compressGroup.set(\out,2);
//~compressGroup.freeAll

~recLength = 0.1;
~recLength2 = 0.1;
~dur = 0.01;
~dur2 = 0.01;
~length = 0.1;
~length2 = 0.1;

~sampleChoose1 = 0;
~sampleChoose2 = 0;


~sine = Env.sine.discretize(1024).putLast(0);
~sineEnv = Buffer.sendCollection(s, ~sine, 1);

Pbindef(\radioplaypattern).fadeTime = 0.0001;

~button_gates = [0, 0];
	~rec_gate = 0;
	~comb_gate = 0;

s.sync;

	~tr = Synth(\trillraw);

	OSCdef(\trill, {|msg| var val0,val1,val3,val7,val14,val15,val20,val29;

			val0 = msg[0+3];
			val1 = msg[1+3];
			val3 = msg[3+3];
			val7 = msg[7+3];
			val14 = msg[14+3];
			val15 = msg[15+3];
			val20 = msg[20+3];
			val29 = msg[29+3];

			case
			{ val0 != 0 } {

			    if ( ~button_gates[0] == 0, {

				Task({ ~button_gates.put(0, 1); "button 0 pressed".postln;
				if ( ~comb_gate == 0, {
					"grain pattern on".postln;

					1.do{|i|var pan = ((i+1)*0.1)-1, dur = 0.1 + (i*0.01);
						Pbindef(("grainpattern1"++i).asSymbol,\instrument, \radioplaypattern,\group,~synthGroup,
						\nyquist, ~nyquist,
						//\xpos, Pwhite(pan,pan+0.1), \ypos, Pwhite(pan, pan+0.1),
						\out,0,
						\octave, 1,
						\start,0,\endBus,~endBus[0].index,\lengthBus, ~lengthBuses[0][i].index,\dur,dur,
						//\reverse,Pwrand([1,-1],[0.6,0.4],inf),
						\bufnum,~bike0smpls[~samNum1],\envbuf, ~sineEnv,\ampBus,~ampBuses[0].index,\pan,Pwhite(pan,pan+0.1),
						 ).play(~clocks[0]);
};


					~comb_gate = 1;
				},{ "grain pattern off".postln;
					1.do{|i| Pbindef(("grainpattern1"++i).asSymbol).pause; };
					~comb_gate = 0;
				});
					2.wait; ~button_gates.put(0, 0); "button 0 unpressed".postln;
				}).start;

			    });

				}
			{ val1 != 0 } {
				("unmapped val"++val1).postln;
				val1 = (val1 - 0.025)/0.075;
				("mapped val"++val1).postln;

				// ~posBus.set(~posSpec.map(val1));
				// ~durBus.set(~durSpec.map(val1));
				// ~trateBus.set(~trateSpec.map(val1));

				// if ( ~button_gates[1] == 0, {
				// Task({ ~button_gates.put(1, 1); "button 1 pressed ".postln;
				// 	if ( ~rec_gate == 0, {
				// 		"recorder on".postln;
				// 	~rec1 = Synth(\recorder,[\in,0,\fftbuf, ~fftBuf,\recbuf, ~recBuf ], ~synthGroup);
				// 	~rec_gate = 1;
				// 	}, { ~rec1.free; ~rec_gate = 0; "recorder off".postln; });
				// 	2.wait; ~button_gates.put(1, 0); "button 1 unpressed".postln; }).start;
			 //   });
			}
			{ val3 != 0 } {
				("unmapped val"++val3).postln;
				val3 = (val3 - 0.025)/0.075;
				("mapped val"++val3).postln;
				~clocks[0].tempo = ~clockSpec.map(val3).postln;
				10.do{|i| ~lengthBuses[0][i].set(~lengthSpec.map(val3);); }

				}
			{ val7 != 0 } {
				("unmapped val"++val7).postln;
				val7 = (val7 - 0.025)/0.075;
				("mapped val"++val7).postln;
				~endBus[0].set(~lengthSpec.map(val7)*~bike0smpls[~samNum1].numFrames);

				 }
			{ val14 != 0 } {
				("unmapped val"++val14).postln;
				val14 = (val14 - 0.025)/0.075;
				("mapped val"++val14).postln;

				 }
			{ val15 != 0 } {
				("unmapped val"++val15).postln;
				val15 = (val15 - 0.025)/0.075;
				("mapped val"++val15).postln;

				}
			{ val20 != 0 } {
				("unmapped val"++val20).postln;
				val20 = (val20 - 0.025)/0.075;
				("mapped val"++val20).postln;

				 }
				{ val29 != 0 } {
				("unmapped val"++val29).postln;
				val29 = (val29 - 0.025)/0.075;
				("mapped val"++val29).postln;

				};
	}, "/trill");


/*
(
~resp = CCResponder({|src,chan,num,val|

	//[num,val].postln;
	case
	//switch samples
				{ num == 109 } { if ( ~samNum1 != 9, { ~samNum1 = ~samNum1 + 1; }, { ~samNum1 = 0; }); }
				{ num == 110} { if ( ~samNum2 != 9, { ~samNum2 = ~samNum2 +1; }, { ~samNum2 = 0; }); }
	//record live audio input for first grain pattern
	{ num == 8 } {

	if ( ~fbgates[0] == 0, {


	if ( val == 127, {
	"rec direct input 0".postln;
	~recsynth1 = Synth(\zitarRecorder, [\in,0,\recbuf, ~bike0smpls[~samNum1],\fftbuf, ~fftbuffers[0]]); }, { ~recsynth1.free; });
					}, {
	if ( val == 127, {

		"recording grain sample 0".postln;
						Synth(\recrecorder,[\in, ~recrecbus[1][0],\chooseBus,~chooseBus.index,
								\bufnum, ~bike0smpls[~samNum1] ],~recrecGroups[1]); });
					});

					}
	//record live audio input for second grain pattern
	{ num == 9 } {
	if ( ~fbgates[1] == 0, {

	if ( val == 127 , {
	"rec direct input 1".postln;
	~recsynth2 = Synth(\zitarRecorder, [\in,0,\recbuf, ~bike1smpls[~samNum2],\fftbuf, ~fftbuffers[0]]); }, { ~recsynth2.free; }); }, {
	if ( val == 127, {
							"recording grain sample 1".postln;
							Synth(\recrecorder,[\in, ~recrecbus[1][1],
								\bufnum, ~bike1smpls[~samNum2] ],~recrecGroups[1]); });
				}); }

	//start&stop pattern 1
	{ num == 24 } {
	"playing pattern 1".postln;
	if ( val == 127, {
10.do{|i|var pan = ((i+1)*0.1)-1, dur = 0.1 + (i*0.01);
Pbindef(("grainpattern1"++i).asSymbol,\instrument, \radioplaypattern,\group,~synthGroup,
\nyquist, ~nyquist,
\xpos, Pwhite(pan,pan+0.1), \ypos, Pwhite(pan, pan+0.1),
\out,0,
\octave, 1,
\start,0,\endBus,~endBus[0].index,\lengthBus, ~lengthBuses[0][i].index,\dur,dur,\reverse,Pwrand([1,-1],[0.6,0.4],inf),
\bufnum,~bike0smpls[~samNum1],\envbuf, ~sineEnv,\ampBus,~ampBuses[0].index,\pan,Pwhite(pan,pan+0.1),
\vectorOut, ~vectorBuses[0][0] ).play(~clocks[0]);
};	},{ 10.do{|i| Pbindef(("grainpattern1"++i).asSymbol).pause; }; }); }
	//change speed + length grains
	{ num == 32 }
	{ ~clocks[0].tempo = ~clockSpec.map(val/127).postln;
		10.do{|i| ~lengthBuses[0][i].set(~lengthSpec.map(val/127);); } }
	//end position in sample
	{ num == 0 }
	{ ~endBus[0].set(~lengthSpec.map(val/127)*~bike0smpls[~samNum1].numFrames); }
	//switch on/off duration variation routine
	{ num == 16 }
	{ if ( val == 127, {
		~durVar = Routine({ inf.do{ 100.do{|i| var dur = ~clocks[0].tempo.reciprocal*0.1, time = 0.001 + rrand(0.0001,0.001);
		10.do{|i|
		~lengthBuses[0][i].set(rrand(dur*0.001,dur)); }; time.wait; } }}).play; "dur routine playing".postln; },
		{ ~durVar.stop; "dur routine stop".postln; });
	}

//start&stop pattern 2
{ num == 25 } { if ( val == 127, {
5.do{|i|var pan = (i+1)*0.1,dur = 0.1 + (i*0.01);
Pbindef(("grainpattern2"++i).asSymbol,\instrument, \radioplaypattern,\group,~synthGroup,
\nyquist, ~nyquist,
\xpos, Pwhite(pan,pan+0.1), \ypos, Pwhite(pan, pan+0.1),
\out,0,
\octave, 1,
\start,0,
\endBus,~endBus[1].index,
\lengthBus, ~lengthBuses[1][i].index,
\dur,dur,\reverse,Pwrand([1,-1],[0.6,0.4],inf),\bufnum,~bike1smpls[~samNum2],\envbuf, ~sineEnv,
							\ampBus,~ampBuses[1].index,
\vectorOut, ~vectorBuses[0][1] ).play(~clocks[1]); } },
		{ 10.do{|i| Pbindef(("grainpattern2"++i).asSymbol).pause; }; }); }
	//change speed + length grains
	{ num == 33 }
	{ ~clocks[1].tempo = ~clockSpec.map(val/127).postln;
		10.do{|i| ~lengthBuses[1][i].set( ~lengthSpec.map(val/127).postln; ); }; }
	//change end position grain pattern
	{ num == 1 }
	{ //~length2 = ~lengthSpec.map(val/127).postln;
		~endBus[1].set(~lengthSpec.map(val/127)*~bike1smpls[~samNum2].numFrames);
	}
	//3rd granular pattern samples the sampler
	//start&stop pattern
	{ num == 28 } { if ( val == 127, {
"pattern3 started".postln;
5.do{|i|var pan = ((i+1)*0.19)-1;
Pbindef(("grainpattern3"++i).asSymbol,\instrument, \regranulate,
\group,~synthGroup,
\nyquist, ~nyquist,
\ampBus,~ampBuses[4].index,
\out, 0,
\octave, 1,
\start,0,
\endBus,~endRecBus[0].index,
\lengthBus, ~lengthBuses[2][i].index,
\dur,0.1,
\reverse,Pwrand([1,-1],[0.6,0.4],inf),
\bufnum,~recrecBufs[0],\envbuf, ~sineEnv,\pan,Pwhite(pan,pan+0.1),
				\recOut, ~vectorBuses[1][0] ).play(~clocks[2]);
};	},
	{ 10.do{|i| Pbindef(("grainpattern3"++i).asSymbol).stop;};	"pattern 3 stopped".postln; }); }
	{ num == 36 }
	{
		~clocks[2].tempo = ~clockSpec.map(val/127).postln;
		10.do{|i| ~lengthBuses[2][i].set(~lengthSpecs[i].map(val/127);); }
	}
	{ num == 4 }
	{ ~endRecBus[0].set( ((~lengthSpec.map(val/127))*~recrecBufs[0].numFrames).postln;); }

{ num == 20 }
	{ if ( val == 127, { ~durVar3 = Routine({ inf.do{ 100.do{|i| var dur = ~clocks[2].tempo.reciprocal*0.5, time = 0.001 + rrand(0.0001,0.001);
		10.do{|i|
			~lengthBuses[2][i].set(rrand(dur*0.001,dur)); }; time.wait; } }}).play; "dur routine playing".postln; },
		{ ~durVar3.stop; "dur routine stop".postln; });
	}

{ num == 29 } { if ( val == 127, {
"pattern4 started".postln;
5.do{|i|var pan = ((i+1)*0.19)-1,dur = 0.1 + (i*0.001);
Pbindef(("grainpattern4"++i).asSymbol,\instrument, \regranulate,
\group,~synthGroup,
\nyquist, ~nyquist,
\ampBus,~ampBuses[5].index,
\out, 0,
\octave, 1,
\start,0,
\endBus,~endRecBus[1].index,
\lengthBus, ~lengthBuses[3][i].index,
\dur,0.1,
\reverse,Pwrand([1,-1],[0.6,0.4],inf),
\bufnum,~recrecBufs[1],\envbuf, ~sineEnv,
				\recOut, ~vectorBuses[1][1]).play(~clocks[3]);
};	},
		{ 10.do{|i| Pbindef(("grainpattern4"++i).asSymbol).stop;};	"pattern 4 stopped".postln; }); }
{ num == 37 }
{
		~clocks[3].tempo = ~clockSpec.map(val/127).postln;
		10.do{|i| ~lengthBuses[2][i].set(~lengthSpecs[i].map(val/127);); }
}
{ num == 5 }
{
		~endRecBus[1].set( ((~lengthSpec.map(val/127))*~recrecBufs[1].numFrames).postln;);
}

{ num == 21 }
	{ if ( val == 127, { ~durVar = Routine({ inf.do{ 100.do{|i| var dur = ~clocks[3].tempo.reciprocal*0.5, time = 0.001 + rrand(0.0001,0.001);
		10.do{|i|
			~lengthBuses[3][i].set(rrand(dur*0.001,dur)); }; time.wait; } }}).play; "dur routine playing".postln; },
		{ ~durVar4.stop; "dur routine stop".postln; });
	}
	//record sampler for grain pattern 3
	{ num == 12 } { "rec 1".postln;
		Synth(\recrecorder,[\in, ~recrecbus[0][0], \bufnum, ~recrecBufs[0]],~recrecGroups[0]); }
	//record sampler for grain pattern 4
	{ num == 13 } { "rec 1".postln;
		Synth(\recrecorder,[\in, ~recrecbus[0][1], \bufnum, ~recrecBufs[1]],~recrecGroups[1]); };

	//[num,val].postln;
});

);
*/

2.do{|i|
2.do{|j|
Routine({inf.do{
~startBuses[i][j].get({|val| ~startValues[i].put(j, (val / s.sampleRate)); });
0.01.wait; } }).play; }; };

/*
~outputs = [ [ ~compressBuses[4][0].index, ~compressBuses[5][0].index ],
	[ ~compressBuses[6][0].index, ~compressBuses[7][0].index] ];
*/


//routines for sample looping without clicks and recording
2.do{|i|

2.do{|j|
var reverse = 1, timeRoutine,timeRoutineSwitch=0,time=0.25, start=0;

Routine({
			inf.do{ var playTime = ~sampleLengths[i][j] * s.sampleRate;

//switch on&off loops - routine speed is based on length sample
if ( ~playButtons[i][j] == 1, { if ( ~playSwitches[i][j] == 0, {
		~playSwitches[i].put(j,1); "playing".postln;
		~routineNames[i][j] = Routine({ inf.do{


if ( ~octave[i][j] > 1,  { if ( ~sampleLengths[i][j] < 0.5, { ~sampleLengths[i].put(j, ~sampleLengths[i][j]*2); });
							//"tooooooo short!!!!".postln;
						});
~startBuses[i][j].get({|item| start = item; });
if ( ~octave[i][j] == 4, { if ( start > ((~sampleLengths[i][j]*s.sampleRate)-start), { start = start - ((~sampleLengths[i][j]*s.sampleRate)-start)}); });

//("start : "++start).postln;
if ( start == inf, { start = ~sampleLengths[i][j]*s.sampleRate*0.5;
"inf error".postln; });
time = (~sampleLengths[i][j] - ~startValues[i][j]) * (1/~octave[i][j]);
time = time + (time*0.05);

if ( time < 0.001, { time = 0.01});

if ( time < 0.01, { if ( start < ((~sampleLengths[i][j]*s.sampleRate)*0.8), {
							start = (~sampleLengths[i][j]*s.sampleRate)*0.8;

							 "damn".postln; }); });


								Synth(\radioplay, [\out,if ( i == 0, { 0 }, { 0 }); ,\amp,~radioplayAmps[i][j],\nyquist, ~nyquist,\sampleRate, s.sampleRate,
									\mainvolBus, if ( i == 0, { if ( j == 0, { ~ampBuses[2].index }, { ~ampBuses[3].index }); },
										{ if ( j == 0, { ~ampBuses[6].index }, { ~ampBuses[7].index }); }); ,
									\start,start,\bufnum, ~recBufs[i][j], \end, ~sampleLengths[i][j]*s.sampleRate,\reverse,reverse,\xpan,j-1.0,\ypan,j-1.0,\octave, ~octave[i][j],
							\vectorOut,~recrecbus[i][j] ],~playGroups[i][j]);

					time.wait; } });
					~routineNames[i][j].play;
				}) },
					{ if ( ~playSwitches[i][j] == 1,
						{ ~playSwitches[i].put(j,0); ~routineNames[i][j].stop; }); });
if ( ~recButtons[i][j] == 1, {
			if ( ~recSwitches[i][j] == 0,{ ~recSwitches[i].put(j, 1);
				"recording".postln;
						Synth(\radiorecorder,[\in,~vectorBuses[i][j], \bufnum, ~recBufs[i][j]],~recGroups[i][j]);
						if ( ~playSwitches[i][j] == 1, {
							~playGroups[i][j].set(\end,~sampleLengths[i][j]*s.sampleRate); ~playGroups[i][j].set(\trig, 1); });

//routine for measuring the length of recording
~timeRoutineNames[i][j] = Routine({
				inf.do{
				10000.do{|k| if ( k != 0 , {
					if ( ~recSwitches[i][j] == 0, {
					~sampleLengths[i].put(j, k * 0.001);
~playGroups[i][j].set(\start,~starts[i][j]*(~sampleLengths[i][j]*s.sampleRate),\end, ~sampleLengths[i][j]*s.sampleRate);  ~timeRoutineNames[i][j].stop;
						"stopped time routine".postln;

						}); });  0.001.wait; } } }).play;
					}); }, { if ( ~recSwitches[i][j] == 1, { ~recSwitches[i].put(j, 0);
						"sample length : ".postln; ~sampleLengths[i][j].postln;
						~startBuses[i][j].set((~starts[i][j]*~sampleLengths[i][j]*s.sampleRate).postln);
/*
~playGroups[j].set(\start,~starts[j]*(~sampleLengths[j]*s.sampleRate),\end, ~sampleLengths[j]*s.sampleRate);
*/
						~recGroups[i][j].freeAll;
						  }); });
				if ( ~reverseButtons[i][j] == 1, { if ( reverse == 1, {
					reverse = -1; if ( ~playSwitches[i][j] == 1, { ~playGroups[i][j].set(\reverse, reverse); }); }); },
			{ if ( reverse == -1, { reverse = 1;
						if ( ~playSwitches[i][j] == 1, { ~playGroups[i][j].set(\reverse, reverse); }); }); });

		0.01.wait;
	};
}).play;
	};
};
//(
//clocks for speed recordings tasks
~recclockSpec = [1.0, 40.0, \exp].asSpec;

~recClocks = Array.fill(2, { TempoClock.new(1); });

/*
~resp2 = CCResponder({|src,chan,num,val|
	[num,val].postln;
if ( num == 10,
		{  if ( val == 127, {"sampling grain pattern 1".postln;~recButtons[0].put(0,1); },{ ~recButtons[0].put(0,0); }); });
	//play sample
	if ( num == 18,
		{ if ( val == 127, { "playing grain loop 1".postln;~playButtons[0].put(0,1); },{ "stopped grain loop 1".postln; ~playButtons[0].put(0,0); }); });
	//reversed on / off
	if ( num == 26,
		{ if ( val == 127, { "reverse on".postln; ~reverseButtons[0].put(0,1) }, { "reverse off".postln; ~reverseButtons[0].put(0,0) }); });
	//set start position
	if ( num == 34, { ~starts[0].put(0, ~startSpec.map(val/127); ); ~starts[0][0].postln;
		~startBuses[0][0].set(~starts[0][0]*~sampleLengths[0][0]*s.sampleRate);
		~radioplayAmps[0].put(0, ~radioplayAmpSpec.map(val/127); ); ~radioplayAmps[0][0].postln;
	});
	//octave shifting
	if ( num == 2, {
		~octave[0].put(0, ~octaves[~octaveSpec.map(val/127)];); ~octave[0][0].postln;
		if ( ~playSwitches[0][0] == 1, {
			~playGroups[0][0].set(\octave, ~octave[0][0]); }); });
	//record sample 2 from grain pattern 2
	if ( num == 11, {
		if ( val == 127, { "sampling grain pattern 2".postln; ~recButtons[0].put(1,1); },{ ~recButtons[0].put(1,0); });});
	if ( num == 19, { if ( val == 127, { "playing grain loop 2".postln; ~playButtons[0].put(1,1); }, { ~playButtons[0].put(1,0); });});
	//reversed on /off
	if ( num == 27,
	{ if ( val == 127, { "reverse on".postln; ~reverseButtons[0].put(1,1); },{ "reverse off".postln; ~reverseButtons[0].put(1, 0); });});
	//set start position
	if ( num == 35, {
	~starts[0].put(1, ~startSpec.map(val/127) ); ~starts[0][1].postln;
	~startBuses[0][1].set(~starts[0][1]*~sampleLengths[0][1]*s.sampleRate);
	~radioplayAmps[0].put(1, ~radioplayAmpSpec.map(val/127); ); ~radioplayAmps[0][1].postln;
	});
	//octave shifting
	if ( num == 3, {
		~octave[0].put(1, ~octaves[~octaveSpec.map(val/127)]); ~octave[0][1].postln;
		if ( ~playSwitches[0][1] == 1, {
			~playGroups[0][1].set(\octave, ~octave[0][1]); }); });
	//SECOND
		if ( num == 14,
		{  if ( val == 127, {"sampling grain pattern 1".postln;~recButtons[1].put(0,1); },{ ~recButtons[1].put(0,0); }); });
	//play sample
	if ( num == 22,
	{ if ( val == 127, { "playing grain loop 1".postln;~playButtons[1].put(0,1); },{ "stopped grain loop 1".postln; ~playButtons[1].put(0,0); }); });
	//reversed on / off
	if ( num == 30,
	{ if ( val == 127, { "reverse on".postln; ~reverseButtons[1].put(0,1) }, { "reverse off".postln; ~reverseButtons[1].put(0,0) }); });
	//set start position
	if ( num == 38, { ~starts[1].put(0, ~startSpec.map(val/127); ); ~starts[1][0].postln;
		~startBuses[1][0].set(~starts[1][0]*~sampleLengths[1][0]*s.sampleRate);
		~radioplayAmps[1].put(0, ~radioplayAmpSpec.map(val/127); ); ~radioplayAmps[1][0].postln;
	});
	//octave shifting
	if ( num == 6, {
		~octave[1].put(0, ~octaves[~octaveSpec.map(val/127)];); ~octave[1][0].postln;
		if ( ~playSwitches[1][0] == 1, {
			~playGroups[1][0].set(\octave, ~octave[1][0]); }); });
	//record sample 2 from grain pattern 2
	if ( num == 15, {
		if ( val == 127, { "sampling grain pattern 2".postln; ~recButtons[1].put(1,1); },{ ~recButtons[1].put(1,0); });});

	//play sample loop
	if ( num == 23, { if ( val == 127, { "playing grain loop 2".postln; ~playButtons[1].put(1,1); }, { ~playButtons[1].put(1,0); });});
	//reversed on /off
	if ( num == 31,
	{ if ( val == 127, { "reverse on".postln; ~reverseButtons[1].put(1,1); },{ "reverse off".postln; ~reverseButtons[1].put(1, 0); });});
	//set start position
	if ( num == 39, {
		~starts[1].put(1, ~startSpec.map(val/127) ); ~starts[1][1].postln;
		~startBuses[1][1].set(~starts[1][1]*~sampleLengths[1][1]*s.sampleRate);
		~radioplayAmps[1].put(1, ~radioplayAmpSpec.map(val/127); ); ~radioplayAmps[1][1].postln;
	});
	//octave shifting
	if ( num == 7, {
		~octave[1].put(1, ~octaves[~octaveSpec.map(val/127)]); ~octave[1][1].postln;
		if ( ~playSwitches[1][1] == 1, {
			~playGroups[1][1].set(\octave, ~octave[1][1]); }); });
	//rec loops
	if ( num == 100, {
		if ( val == 127, { "rec loop 0 running".postln;
	~recRoutine0 = Routine({
				inf.do{
		"recording sample loop 0".postln;
		~recButtons[0].put(0,1);
		rrand(0.5,2.0).wait;
		"stopped recording sample loop 0".postln;
		~recButtons[0].put(0,0);
		rrand(0.5,2.0).wait;
		"recording grain sample 1".postln;
		Synth(\recrecorder,[\in, ~recrecbus[0][0], \bufnum, ~recrecBufs[0]],~recrecGroups[0]);
		rrand(0.5,2.0).wait;
		"recording sample loop 1".postln;
		~recButtons[1].put(0,1);
		rrand(0.5,2.0).wait;
		"stopped recording sample loop 0".postln;
		~recButtons[1].put(0,0);
		rrand(0.5,2.0).wait;
		if ( ~fbgates[0] == 1, {
		"recording grain sample 0".postln;

						Synth(\recrecorder,[\in, ~recrecbus[1][0],\chooseBus,~chooseBus.index,
							\bufnum, ~bike0smpls[~samNum1] ],~recrecGroups[1]);
						1.0.wait;
						10.do{|i| Pbindef(("grainpattern1"++i).asSymbol,\bufnum,~bike0smpls[~samNum1] ); };
					});
				}
				}).play(~recClocks[0]); }, { "rec loop 0 stopped".postln; ~recButtons[0].put(0,0); ~recButtons[0].put(1,0); ~recRoutine0.stop; }); } );
		if ( num == 101, {
		if ( val == 127, { "rec loop 1 running".postln;
		~recRoutine1 = Routine({
	inf.do{

		~recButtons[0].put(1,1);
		rrand(0.5,2.0).wait;
		~recButtons[0].put(1,0);
		rrand(0.5,2.0).wait;
		Synth(\recrecorder,[\in, ~recrecbus[0][1], \bufnum, ~recrecBufs[1]],~recrecGroups[0]);
		rrand(0.5,2.0).wait;
		~recButtons[1].put(1,1);
		rrand(0.5,2.0).wait;
		~recButtons[1].put(1,0);
		rrand(0.5,2.0).wait;
		if ( ~fbgates[1] == 1, {

		Synth(\recrecorder,[\in, ~recrecbus[1][1],
							\bufnum, ~bike1smpls[~samNum2] ],~recrecGroups[1]);
							1.0.wait;
								10.do{|i| Pbindef(("grainpattern2"++i).asSymbol,\bufnum,~bike1smpls[~samNum2]  ); };
			 });
	}
}).play(~recClocks[1]);
 }, { "rec loop 1 stopped".postln; ~recButtons[1].put(0,0); ~recButtons[1].put(1,0); ~recRoutine1.stop; }); } );
//open close feedback gates
	if ( num == 106, {
		if ( val == 127, {"gate 0 opened".postln; ~fbgates.put(0, 1); },
			{"gate 0 closed".postln; ~fbgates.put(0, 0); }); });
	if ( num == 107, {
		if ( val == 127, {"gate 1 opened".postln; ~fbgates.put(1, 1); },
			{"gate 1 closed".postln; ~fbgates.put(1, 0); }); });


	//second sampler
});
);
*/



	~dbampSpec = [ -80.0, 0.0].asSpec;
/*
	~volumeResp = CCResponder({|src chan num val|
		[num, val].postln;
		8.do{|i|
			if ( num == (i+74), { ~ampBuses[i].set( ~dbampSpec.map(val/127).dbamp; ); });
		};
		case
		{ num == 82 } { ~recClocks[0].tempo = (~recclockSpec.map(val/127)).postln; }
		{ num == 83 } { ~recClocks[1].tempo = (~recclockSpec.map(val/127)).postln; };

	});
*/

});


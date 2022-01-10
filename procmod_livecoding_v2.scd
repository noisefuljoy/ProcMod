/*****
Run the code below from the SuperCollider IDE after you started scsynth on Bela (see -main.scd)
Make sure you have the Bela Remote SC classes are in the extensions directory of your SC installation.
Get them here: https://github.com/sensestage/bela-remote
*****/
fork{

( // connect to the already-running remote belaserver
Server.default = s = Server("belaServer", NetAddr("bela.local", 57110));
s.options.maxLogins = 4; // should match the settings on the Bela
s.initTree;
s.startAliveThread;
);
s.waitForBoot{
// Communicate with the server
s.plotTree; // show all active nodes
s.freeAll;  // free all nodes


SynthDef(\recorder, {|in=0 fftbuf recbuf thresh=0.3|
var input = SoundIn.ar(in);
var chain = FFT(fftbuf, input);
var onsets = Onsets.kr(chain,thresh);
input = Compander.ar(input, input, 0.01,1,0.01,0.005,0.1,25);
//amplitude.poll;
	RecordBuf.ar(input, recbuf,loop:0,trigger:onsets);
 }).store;

SynthDef(\pumper, {|in out=0 amp=0.5|
	var input = In.ar(in, 1);
	//input = Compander.ar(input, input, 0.1,1, 0.01, 0.001,0.1,10);
	Out.ar(out, input * amp );
			 }).store;

SynthDef(\radioplaypattern, {|out=0 ampBus lengthBus start=0 endBus octaveBus trig=1 reverse=1 bufnum envbuf xpos=0 ypos=0 vectorOut nyquist|
	//var trigger = EnvGen.kr(Env([0,1,0],[0.001,0.001]),trig);
	var amp = In.kr(ampBus, 1);
	var end = In.kr(endBus, 1);
	var length = In.kr(lengthBus, 1);
	var octave = In.kr(octaveBus, 1);
	var env = Osc1.ar(envbuf, length*Rand(0.9,1.5));
	var sig = BufRd.ar(1, bufnum, Phasor.ar(trig, BufRateScale.kr(bufnum)*reverse*octave,start,end ),loop: 1) * env * 0.2;
	//var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum),trig, loop: 1);
	//Out.ar(out, Pan2.ar(sig, LFNoise1.kr(Rand(0.8,3.2)).range(pan,pan+0.25)));
	//Out.ar(out, Pan4.ar(sig, xpos, ypos));
	sig = LPF.ar(sig, nyquist);
	FreeSelfWhenDone.kr(sig);
	Out.ar(out, sig*amp);
	//Out.ar(out, Pan2.ar(sig*amp,LFNoise0.kr(3.2).range(-1.0,1.0)) );
	}).store;



SynthDef(\combc, {|in out=0 delmod=0.001 dec=8 mix=0.4|
		var sig,delsig;
		sig = In.ar(in, 1);
		//sig = BLowPass.ar(sig, 500,0.1);
			sig = BPeakEQ.ar(sig, 4000,1,-12);
			sig = BHiShelf.ar(sig, 8000,1,-14);

		delsig = sig;
		3.do{|i|
			n = (i + 1) * 0.1;
			o = (i + 1) * 0.01;
			e = (i + 1) * 0.1;
				delsig = CombC.ar(sig, 0.2, SinOsc.kr(LFNoise0.kr(0.01).range(delmod+o,(delmod+o)*0.001)).range(0.01, n), e + dec, 0.3, delsig);
		};





			sig = FreeVerb.ar(sig, 0.45, 0.9, 0.2);
		//sig = LPF.ar(sig, 800);
		sig = (delsig * mix) + (sig * ( 1 - mix) );
			Out.ar(out, Pan2.ar(sig, 0));
		//Out.ar(out, Pan2.ar(sig, SinOsc.kr(LFNoise0.kr(0.2).range(0.1,80.0)).range(-1.0,1.0)));
		}).add;



1.wait;

~tr = Synth(\trillcraft);
~br = Synth(\trillbar);
~flx = Synth(\trillflex);

~bike0smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];
~bike1smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];
		~fftBuf = Buffer.alloc(s, 512);

~synthGroup = Group.new;
~effectGroup = Group.after(~synthGroup);
~nyquist = s.sampleRate * 0.5;

~combBus = Bus.audio(s, 1);
~compBus = Bus.audio(s, 1);


~pumpSynth = Synth(\pumper, [\in, ~compBus, \out, ~combBus], ~effectGroup);
/*~pumpSynth.free
~combSynth.free*/
~combSynth = Synth(\combc, [\in, ~combBus,\mix, 0.8,\out, 0], ~effectGroup, \addAfter);

~clocks = Array.fill(4, { TempoClock.new(1); });

~clockSpec = [0.125, 3.0, \exp].asSpec;
~lengthSpec = [0.999,0.01,\exp].asSpec;
~endSpec = [0.999,0.0001,\exp].asSpec;
~ampSpec = [0.15,6.0,-15].asSpec;
~octaveSpec = [0.0625,3.0,\exp, 0.0625,1].asSpec;

~lengthBuses = Array.fill(4, { Array.fill(10, {Bus.control(s, 1).set(0.4)}); });
~startBuses = Array.fill(2, { Array.fill(2, { Bus.control(s, 1).set(0.0); }); });
~ampBuses = Array.fill(8, { Bus.control(s, 1).set(1.0); });
~ampBus = Array.fill(2, {  Bus.control(s,1).set(0.001); });
~endBus = [
			Bus.control(s, 1).set(~bike0smpls[0].numFrames),
			Bus.control(s, 1).set(~bike1smpls[1].numFrames) ];

~octaveBus = Bus.control(s, 1).set(1);

~sine = Env.sine.discretize(1024).putLast(0);
~sineEnv = Buffer.sendCollection(s, ~sine, 1);

~samNum1 = 0;
~samNum2 = 0;

~clocks[0].tempo = 2;
~endBus[0].set(44100);

Pbindef(\radioplaypattern).fadeTime = 0.0001;

~button_gates = [0, 0];
	~rec_gate = 0;
	~comb_gate = 0;

//s.sync;


	OSCdef(\trill, {|msg| var val0,val1,val3,val7,val14,val15,val20,val29;

			val0 = msg[29+3];
			val1 = msg[1+3];
			val3 = msg[3+3];
			val7 = msg[7+3];
			val14 = msg[14+3];
			val15 = msg[15+3];
			val20 = msg[20+3];
			//val29 = msg[29+3];

			case
			{ val0 != 0 } {

			    if ( ~button_gates[0] == 0, {

				Task({ ~button_gates.put(0, 1); "button 0 pressed".postln;
				if ( ~comb_gate == 0, {
					"grain pattern on".postln;

					5.do{|i|var pan = ((i+1)*0.1)-1, dur = 0.15 + (i*0.2);
						Pbindef(("grainpattern1"++i).asSymbol,\instrument, \radioplaypattern,\group,~synthGroup,
						\nyquist, ~nyquist,
						//\xpos, Pwhite(pan,pan+0.1), \ypos, Pwhite(pan, pan+0.1),
						\out,~compBus,
						\octaveBus, ~octaveBus.index,
						\start,0,\endBus,~endBus[0].index,\lengthBus, ~lengthBuses[0][i].index,\dur,dur,
						//\reverse,Pwrand([1,-1],[0.6,0.4],inf),
						\bufnum,~bike0smpls[~samNum1],\envbuf, ~sineEnv,\ampBus,~ampBuses[0].index,\pan,Pwhite(pan,pan+0.1),
						 ).play(~clocks[0]);
};


					~comb_gate = 1;
				},{ "grain pattern off".postln;
					5.do{|i| Pbindef(("grainpattern1"++i).asSymbol).pause; };
					~comb_gate = 0;
				});
					0.5.wait; ~button_gates.put(0, 0); "button 0 unpressed".postln;
				}).start;

			    });

				}
			{ val20 != 0 } {
				/*("unmapped val"++val1).postln;
				val1 = (val1 - 0.025)/0.075;
				("mapped val"++val1).postln;
*/
				// ~posBus.set(~posSpec.map(val1));
				// ~durBus.set(~durSpec.map(val1));
				// ~trateBus.set(~trateSpec.map(val1));

				if ( ~button_gates[1] == 0, {
				Task({ ~button_gates.put(1, 1); "button 1 pressed ".postln;
				if ( ~rec_gate == 0, {
				 		"recorder on".postln;
				 	~rec1 = Synth(\recorder,[\in,0,\fftbuf, ~fftBuf,\recbuf, ~bike0smpls[~samNum1] ], ~synthGroup);
				 	~rec_gate = 1;
				 	}, { ~rec1.free; ~rec_gate = 0; "recorder off".postln; });
				 	0.5.wait; ~button_gates.put(1, 0); "button 1 unpressed".postln; }).start;
			    });
			}



			{ val3 != 0 } {
				("unmapped val 3 : "++val3).postln;
				val3 = (val3 - 0.042072265625)/0.278658203125;
				("mapped val 3 : "++val3).postln;
				~clocks[0].tempo = ~clockSpec.map(val3).postln;
				5.do{|i| ~lengthBuses[0][i].set(~lengthSpec.map(val3).postln;); }

				}

			{ val7 != 0 } {
				("unmapped val 7 : "++val7).postln;
				val7 = (val7 - 0.04536328125)/0.41264453125;
				("mapped val 7 : "++val7).postln;
				~endBus[0].set((~endSpec.map(val7)*~bike0smpls[~samNum1].numFrames).postln);
				~ampBuses[0].set(~ampSpec.map(val7).postln;);

				 }

			{ val14 != 0 } {
				("unmapped val 14 : "++val14).postln;
				val14 = (val14 - 0.025)/0.075;
				("mapped val 14 : "++val14).postln;
				~octaveBus.set(~octaveSpec.map(val14).postln;);

				 }

			{ val15 != 0 } {
				/*("unmapped val"++val15).postln;
				val15 = (val15 - 0.025)/0.075;
				("mapped val"++val15).postln;*/

				if ( ~button_gates[1] == 0, {

				Task({ ~button_gates.put(1, 1); "button 0 pressed".postln;
				if ( ~comb_gate == 0, { "comb on".postln;
					~combSynth.set(\delmod,rrand(1.0,3.0),\dec,rrand(6.0,7.0),\mix, 0.4);
					~comb_gate = 1;
				},{ "comb off".postln;
					~combSynth.set(\delmod,0.01,\dec,0.01,\mix, 0.00 );
					~comb_gate = 0;
				});
					0.5.wait; ~button_gates.put(1, 0); "button 0 unpressed".postln;
				}).start;

			    });


				}
			{ val20 != 0 } {
				("unmapped val"++val20).postln;
				val20 = (val20 - 0.025)/0.075;
				("mapped val"++val20).postln;

				 };

	}, "/craft");

	OSCdef(\trillbar, {|msg|
			msg.postln; }, '/bar');

	OSCdef(\trillflex, {|msg|
			msg.postln; }, '/flex');

	};
};

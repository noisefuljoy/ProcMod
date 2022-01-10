/*****
Run the code below from the SuperCollider IDE after you started scsynth on Bela (see -main.scd)

Make sure you have the Bela Remote SC classes are in the extensions directory of your SC installation.
Get them here: https://github.com/sensestage/bela-remote

(c) 2017: Jonathan Reus, Marije Baalman, Giulio Moro, Andrew McPherson
*****/


( // connect to the already-running remote belaserver
Server.default = s = Server("belaServer", NetAddr("bela.local", 57110));
s.options.maxLogins = 4; // should match the settings on the Bela
s.initTree;
s.startAliveThread;
);

// Communicate with the server
s.plotTree; // show all active nodes
s.freeAll;  // free all nodes


(

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
	}).store;

SynthDef(\radioplaypattern, {|out=0 ampBus lengthBus start=0 endBus octave=1 trig=1 reverse=1 bufnum envbuf xpos=0 ypos=0 vectorOut nyquist|
	//var trigger = EnvGen.kr(Env([0,1,0],[0.001,0.001]),trig);
	var amp = In.kr(ampBus, 1);
	var end = In.kr(endBus, 1);
	var length = In.kr(lengthBus, 1);
	var env = Osc1.ar(envbuf, length*Rand(0.9,1.5));
	var sig = BufRd.ar(1, bufnum, Phasor.ar(trig, BufRateScale.kr(bufnum)*reverse*octave,start,end ),loop: 1) * env * 1;
	//var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum),trig, loop: 1);
	//Out.ar(out, Pan2.ar(sig, LFNoise1.kr(Rand(0.8,3.2)).range(pan,pan+0.25)));
	//Out.ar(out, Pan4.ar(sig, xpos, ypos));
	sig = LPF.ar(sig, nyquist);
	FreeSelfWhenDone.kr(sig);

	Out.ar(out, Pan2.ar(sig*amp,LFNoise0.kr(3.2).range(-1.0,1.0)) );
	}).store;


);



~tr = Synth(\trillraw);


~bike0smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];
~bike1smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];


~synthGroup = Group.new;
~nyquist = s.sampleRate * 0.5;

~clocks = Array.fill(4, { TempoClock.new(1); });

~clockSpec = [0.5, 4.0, -8].asSpec;
~lengthSpec = [5.0,0.05,-8].asSpec;

~lengthBuses = Array.fill(4, { Array.fill(10, {Bus.control(s, 1).set(0.4)}); });
~startBuses = Array.fill(2, { Array.fill(2, { Bus.control(s, 1).set(0.0); }); });
~ampBuses = Array.fill(8, { Bus.control(s, 1).set(1.0); });
~ampBus = Array.fill(2, {  Bus.control(s,1).set(0.001); });
~endBus = [
			Bus.control(s, 1).set(~bike0smpls[0].numFrames),
			Bus.control(s, 1).set(~bike1smpls[1].numFrames) ];

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

s.sync;

	~tr = Synth(\trillraw);

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
					0.5.wait; ~button_gates.put(0, 0); "button 0 unpressed".postln;
				}).start;

			    });

				}
			/*{ val1 != 0 } {
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
	        */
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

				 };
	        /*
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

				}; */
	}, "/trill");



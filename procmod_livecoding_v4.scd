/*****
Run the code below from the SuperCollider IDE after you started scsynth on Bela (see -main.scd)
Make sure you have the Bela Remote SC classes are in the extensions directory of your SC installation.
Get them here: https://github.com/sensestage/bela-remote
*****/

(
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
//s.freeAll;  // free all nodes

/*
Trill devices detected on bus 1
Address    | Type
0x20 ( 32) | Bar
0x28 ( 40) | Square
0x30 ( 48) | Craft
0x38 ( 56) | Ring
0x40 ( 64) | Hex
0x48 ( 72) | Flex
Total: 6 devices
*/

t = ScalaTunings.at('partch_41comb');
~pent_opt = Tuning.partch_41comb;


fork{
var sc = ~pent_opt;

~pent_ratios = Array.fill(287, {|i|
	var octave = i / 41;
	case
	{ octave < 1; } { sc.ratios.wrapAt(i) * 1 }
	{ ((octave == 1) or: (octave > 1)) and: (octave < 2) } { sc.ratios.wrapAt(i) * 2 }
	{ ((octave == 2) or: (octave > 2)) and: (octave < 3)  } { sc.ratios.wrapAt(i) * 4  }
	{ ((octave == 3) or: (octave > 3)) and: (octave < 4)  } { sc.ratios.wrapAt(i) * 6 }
	{ ((octave == 4) or: (octave > 4)) and: (octave < 5)  } { sc.ratios.wrapAt(i) * 8 }
	{ ((octave == 5) or: (octave > 5)) and: (octave < 6)  } { sc.ratios.wrapAt(i) * 10 }
	{ ((octave == 6) or: (octave > 6)) and: (octave < 7)  } { sc.ratios.wrapAt(i) * 12 }
});
};


~tr = Synth(\trillcraft);
~sq = Synth(\trillsquare);
//~flx = Synth(\trillflex);

~toybox = Buffer.read(s, "/root/Bela/projects/craft_livecoding/Psalt_sound.wav");
~sus = Buffer.read(s, "/root/Bela/projects/craft_livecoding/Sus_sound2.wav");


~fftBuf = Buffer.alloc(s, 512);

~synthGroup = Group.new;
~effectGroup = Group.after(~synthGroup);
~nyquist = s.sampleRate * 0.5;

~combBus = Bus.audio(s, 1);
~compBus = Bus.audio(s, 1);

~clocks = Array.fill(4, { TempoClock.new(1); });

~clockSpec = [0.125, 3.0, \exp].asSpec;
~lengthSpec = [0.999,0.01,\exp].asSpec;
~endSpec = [0.999,0.0001,\exp].asSpec;
~ampSpec = [0.15,6.0,-15].asSpec;
~octaveSpec = [0.0625,3.0,\exp, 0.0625,1].asSpec;
~relSpec = [0.1,0.5,\linear].asSpec;
~freqSpec = [10.0,300.0,\linear].asSpec;

~ampBuses = Array.fill(8, { Bus.control(s, 1).set(1.0); });
~ampBus = Array.fill(2, {  Bus.control(s,1).set(0.001); });


~octaveBus = Bus.control(s, 1).set(1);
~posBus = Bus.control(s, 1).set(0);
~durBus = Bus.control(s, 1).set(0.25);
~trateBus = Bus.control(s, 1).set(80);

~sine = Env.sine.discretize(1024).putLast(0);
~sineEnv = Buffer.sendCollection(s, ~sine, 1);

~samNum1 = 0;
~samNum2 = 0;



~button_gates = [0, 0];
	~rec_gate = 0;
	~comb_gate = 0;

~button_gates = Array.fill(16 , { 0 } );
~posBus = Array.fill(16, {|i| Bus.control(s, 1).set(i*0.0625); });
~rateBus = Array.fill(16, {|i| Bus.control(s, 1).set(1); });

Synth(\recorder);

//s.sync;

OSCdef(\craft, {|msg| var val0,val2,val4,val6,val8,val10, val12,val14,val15,val17,val19, val21,val23,val25,val27,val29;
			msg.postln;

			val0 = msg[0+3];
			val2 = msg[2+3];
			val4 = msg[4+3];
			val6 = msg[6+3];
			val8 = msg[8+3];
			val10 = msg[10+3];
			val12 = msg[12+3];
			val14 = msg[14+3];
			val15 = msg[15+3];
			val17 = msg[17+3];
			val19 = msg[19+3];
			val21 = msg[21+3];
			val23 = msg[23+3];
			val25 = msg[25+3];
			val27 = msg[27+3];
			val29 = msg[29+3];

			if ( val0 != 0,  {
				("unmapped val"++val0).postln;
				val0 = (val0 - 0.025)/0.075;
				("mapped val"++val0).postln;

				~rateBus[0].set(~pent_ratios.wrapAt(val0));


				 if ( ~button_gates[0] == 0, {
				~button_gates.put(0, 1); "button 0 pressed".postln;
				~grain0 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[0].index,
				\release, ~relSpec.map(val0),
				\rateBus, ~rateBus[0].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[0] == 1, {

					~grain0.set(\gate, 0);
					~button_gates.put(0, 0); "button unpressed".postln;
				});
			});

			if ( val2 != 0,  {
				("unmapped val"++val2).postln;
				val2 = (val2 - 0.025)/0.075;
				("mapped val"++val2).postln;

				~rateBus[1].set(~pent_ratios.wrapAt(val2));


				 if ( ~button_gates[1] == 0, {
				~button_gates.put(1, 1); "button 2 pressed".postln;
				~grain1 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[1].index,
				\release, ~relSpec.map(val2),
				\rateBus, ~rateBus[1].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[1] == 1, {

					~grain1.set(\gate, 0);
					~button_gates.put(1, 0); "button 2 unpressed".postln;
				});
			});

			if ( val4 != 0,  {
				("unmapped val"++val4).postln;
				val4 = (val4 - 0.025)/0.075;
				("mapped val"++val4).postln;
				~rateBus[2].set(~pent_ratios.wrapAt(val4));


				 if ( ~button_gates[2] == 0, {
				~button_gates.put(2, 1); "button 4 pressed".postln;
				~grain2 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[2].index,
				\release, ~relSpec.map(val4),
				\rateBus, ~rateBus[2].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[2] == 1, {

					~grain2.set(\gate, 0);
					~button_gates.put(2, 0); "button 4 unpressed".postln;
				});
			});

			if ( val6 != 0,  {
				("unmapped val"++val6).postln;
				val6 = (val6 - 0.025)/0.075;
				("mapped val"++val6).postln;

				~rateBus[3].set(~pent_ratios.wrapAt(val6));

				 if ( ~button_gates[3] == 0, {
				~button_gates.put(3, 1); "button 6 pressed".postln;
				~grain3 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[3].index,
				\release, ~relSpec.map(val6),
				\rateBus, ~rateBus[3].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[3] == 1, {

					~grain3.set(\gate, 0);
					~button_gates.put(3, 0); "button 6 unpressed".postln;
				});
			});

			if ( val8 != 0,  {
				("unmapped val"++val8).postln;
				val8 = (val8 - 0.025)/0.075;
				("mapped val"++val8).postln;

				~rateBus[4].set(~pent_ratios.wrapAt(val8));


				 if ( ~button_gates[4] == 0, {
				~button_gates.put(4, 1); "button 8 pressed".postln;
				~grain4 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[4].index,
				\release, ~relSpec.map(val8),
				\rateBus, ~rateBus[4].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[4] == 1, {

					~grain4.set(\gate, 0);
					~button_gates.put(4, 0); "button 8 unpressed".postln;
				});
			});

			if ( val10 != 0,  {
				("unmapped val"++val10).postln;
				val10 = (val10 - 0.025)/0.075;
				("mapped val"++val10).postln;

				~rateBus[5].set(~pent_ratios.wrapAt(val10));

				 if ( ~button_gates[5] == 0, {
				~button_gates.put(5, 1); "button 10 pressed".postln;
				~grain5 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[5].index,
				\release, ~relSpec.map(val10),
				\rateBus, ~rateBus[5].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[5] == 1, {

					~grain5.set(\gate, 0);
					~button_gates.put(5, 0); "button 10 unpressed".postln;
				});
			});

			if ( val12 != 0,  {
				("unmapped val"++val12).postln;
				val12 = (val12 - 0.025)/0.075;
				("mapped val"++val12).postln;

				~rateBus[6].set(~pent_ratios.wrapAt(val12));

				 if ( ~button_gates[6] == 0, {
				~button_gates.put(6, 1); "button 12 pressed".postln;
				~grain6 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[6].index,
				\release, ~relSpec.map(val12),
				\rateBus, ~rateBus[6].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[6] == 1, {

					~grain6.set(\gate, 0);
					~button_gates.put(6, 0); "button 12 unpressed".postln;
				});
			});

			if ( val14 != 0,  {
				("unmapped val"++val14).postln;
				val14 = (val14 - 0.025)/0.075;
				("mapped val"++val14).postln;

				~rateBus[7].set(~pent_ratios.wrapAt(val14));

				 if ( ~button_gates[7] == 0, {
				~button_gates.put(7, 1); "button 14 pressed".postln;
				~grain7 = Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[7].index,
				\release, ~relSpec.map(val14),
				\rateBus, ~rateBus[7].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[7] == 1, {

					~grain7.set(\gate, 0);
					~button_gates.put(7, 0); "button 14 unpressed".postln;
				});
			});

			/* SECOND ROW WITH SUS SOUND */

			if ( val15 != 0,  {
				("unmapped val"++val15).postln;
				val15 = (val15 - 0.025)/0.075;
				("mapped val"++val15).postln;

				~rateBus[8].set(~pent_ratios.wrapAt(val15));


				 if ( ~button_gates[8] == 0, {
				~button_gates.put(8, 1); "button 0 pressed".postln;
				~grain8 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[8].index,
				\release, ~relSpec.map(val15),
				\rateBus, ~rateBus[8].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[8] == 1, {

					~grain8.set(\gate, 0);
					~button_gates.put(8, 0); "button unpressed".postln;
				});
			});

			if ( val17 != 0,  {
				("unmapped val"++val17).postln;
				val17 = (val17 - 0.025)/0.075;
				("mapped val"++val17).postln;

				~rateBus[9].set(~pent_ratios.wrapAt(val17));


				 if ( ~button_gates[9] == 0, {
				~button_gates.put(9, 1); "button 2 pressed".postln;
				~grain9 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[9].index,
				\release, ~relSpec.map(val17),
				\rateBus, ~rateBus[9].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[9] == 1, {

					~grain9.set(\gate, 0);
					~button_gates.put(9, 0); "button 2 unpressed".postln;
				});
			});

			if ( val19 != 0,  {
				("unmapped val"++val19).postln;
				val19 = (val19 - 0.025)/0.075;
				("mapped val"++val19).postln;
				~rateBus[10].set(~pent_ratios.wrapAt(val19));


				 if ( ~button_gates[10] == 0, {
				~button_gates.put(10, 1); "button 4 pressed".postln;
				~grain10 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[10].index,
				\release, ~relSpec.map(val19),
				\rateBus, ~rateBus[10].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[10] == 1, {

					~grain10.set(\gate, 0);
					~button_gates.put(10, 0); "button 4 unpressed".postln;
				});
			});

			if ( val21 != 0,  {
				("unmapped val"++val21).postln;
				val21 = (val21 - 0.025)/0.075;
				("mapped val"++val21).postln;

				~rateBus[11].set(~pent_ratios.wrapAt(val21));

				 if ( ~button_gates[11] == 0, {
				~button_gates.put(11, 1); "button 6 pressed".postln;
				~grain11 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[11].index,
				\release, ~relSpec.map(val21),
				\rateBus, ~rateBus[11].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[11] == 1, {

					~grain11.set(\gate, 0);
					~button_gates.put(11, 0); "button 6 unpressed".postln;
				});
			});

			if ( val23 != 0,  {
				("unmapped val"++val23).postln;
				val23 = (val23 - 0.025)/0.075;
				("mapped val"++val23).postln;

				~rateBus[12].set(~pent_ratios.wrapAt(val23));


				 if ( ~button_gates[12] == 0, {
				~button_gates.put(12, 1); "button 8 pressed".postln;
				~grain12 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[12].index,
				\release, ~relSpec.map(val23),
				\rateBus, ~rateBus[12].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[12] == 1, {

					~grain12.set(\gate, 0);
					~button_gates.put(12, 0); "button 8 unpressed".postln;
				});
			});

			if ( val25 != 0,  {
				("unmapped val"++val25).postln;
				val25 = (val25 - 0.025)/0.075;
				("mapped val"++val25).postln;

				~rateBus[13].set(~pent_ratios.wrapAt(val25));

				 if ( ~button_gates[13] == 0, {
				~button_gates.put(13, 1); "button 10 pressed".postln;
				~grain13 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[13].index,
				\release, ~relSpec.map(val25),
				\rateBus, ~rateBus[13].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[13] == 1, {

					~grain13.set(\gate, 0);
					~button_gates.put(13, 0); "button 10 unpressed".postln;
				});
			});

			if ( val27 != 0,  {
				("unmapped val"++val27).postln;
				val27 = (val27 - 0.025)/0.075;
				("mapped val"++val27).postln;

				~rateBus[14].set(~pent_ratios.wrapAt(val27));

				 if ( ~button_gates[14] == 0, {
				~button_gates.put(14, 1); "button 12 pressed".postln;
				~grain14 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[14].index,
				\release, ~relSpec.map(val27),
				\rateBus, ~rateBus[14].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[14] == 1, {

					~grain14.set(\gate, 0);
					~button_gates.put(14, 0); "button 12 unpressed".postln;
				});
			});

			if ( val29 != 0,  {
				("unmapped val"++val29).postln;
				val29 = (val29 - 0.025)/0.075;
				("mapped val"++val29).postln;

				~rateBus[15].set(~pent_ratios.wrapAt(val29));

				 if ( ~button_gates[15] == 0, {
				~button_gates.put(15, 1); "button 14 pressed".postln;
				~grain15 = Synth(\grainSampler,[\bufnum, ~sus,
				\envbuf, ~sineEnv,
				\posBus, ~posBus[15].index,
				\release, ~relSpec.map(val29),
				\rateBus, ~rateBus[15].index,
				\amp, 1,
				\out, 0 ], ~synthGroup);
				});
			}, {
				 if ( ~button_gates[15] == 1, {

					~grain15.set(\gate, 0);
					~button_gates.put(15, 0); "button 14 unpressed".postln;
				});
			});

	}, "/craft");



OSCdef(\trillbar, {|msg|
			msg.postln; }, '/square');

	/*OSCdef(\trillflex, {|msg|
			msg.postln; }, '/flex');*/

	};
};

);

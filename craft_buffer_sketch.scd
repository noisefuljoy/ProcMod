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

s.waitForBoot {

	SynthDef(\recorder, {|in=0 fftbuf recbuf thresh=0.01|
		var input = SoundIn.ar(in);
		var chain = FFT(fftbuf, input);
		var onsets = Onsets.kr(chain,thresh);
		//input = Compander.ar(input, input, 0.01,1,0.01,0.005,0.1,25);
		//amplitude.poll;
	RecordBuf.ar(input, recbuf,loop:0,trigger:onsets);
 }).store;

	SynthDef(\combc, {|in out=0 delmod=0.01 dec=0.01 mix=0.1|
		var sig, delsig;
		sig = In.ar(in, 1);
		delsig = sig;
		3.do{|i|
			n = (i + 1) * 0.1;
			o = (i + 1) * 0.01;
			e = (i + 1) * 0.1;
			delsig = CombC.ar(sig, 0.2, SinOsc.kr(delmod+o).range(0.01, n), e + dec, 0.3, delsig);
		};
		sig = (delsig * mix) + (sig * ( 1 - mix) );
		Out.ar(out, Pan2.ar(sig, 0)); }).add;



	SynthDef(\grainSampler, {|out amp=0.75 posBus durBus trateBus envbuf bufnum release=0.01 rate=1|
		var env, sig, pos, dur, trate;
		//env = Osc1.ar(envbuf, 1);
		pos = In.kr(posBus, 1);
		dur = In.kr(durBus, 1);
		trate = In.kr(trateBus, 1);

		//env = EnvGen.ar(Env.perc(0.001,release), 1, doneAction: 2);
		env = Osc1.ar(envbuf, 1);
		//sig = GrainBuf.ar(1, Impulse.ar(trate), dur, bufnum, BufRateScale.kr(bufnum)*rate, BufFrames.ir(bufnum)*pos, -1);

		sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum)*rate, 1, BufFrames.ir(bufnum)*pos, loop: 1);
		sig = Mix(sig);

		Out.ar(out, sig*env*amp!2 ); }).add;

		~synthGroup = Group.new;
		~effectGroup = Group.after(~synthGroup);
		~combBus = Bus.audio(s, 1);
		~toybox = Buffer.read(s, "gerri_toybox.wav", 1);

		~combSynth = Synth(\combc, [\in, ~combBus,\out, 0], ~effectGroup);

	SynthDef(\trillcraft, {|t_recalibrate=0.0|
		var i2c_bus = 1;
		var i2c_address = 0x30;
		var noiseThreshold = 0.06; // float: 0-0.0625, with 0.0625 being the highest noise thresh
		var prescalerOpt = 1; // int: 1-8 with 1 being the highest sensitivity
		var touchsigs = DC.ar(0).dup(3); // use 3 touches
		var centroids;
		var out, ping;
		centroids = TrillRaw.kr(i2c_bus, i2c_address, noiseThreshold, prescalerOpt, t_recalibrate);
		SendReply.kr(Impulse.kr(10), "/trill", centroids);
	}).add;

	s.sync;

	~tr = Synth(\trillraw);
	~freqSpec = [0.5,2.0,\linear,0.001].asSpec;
	~phaseSpec = [1,120,\linear,1].asSpec;
	~relSpec = [0.001,1.0, \linear, 0.001].asSpec;
	~delmodSpec = [0.0001,10.0, \exp, 0.001].asSpec;
	~decSpec = [0.1,6.0, \exp, 0.001].asSpec;

	~posSpec = [0.0,0.6, \linear, 0.001].asSpec;
	~durSpec = [0.75,0.01, \exp, 0.001].asSpec;
	~trateSpec = [1.0,60.0, \exp, 0.001].asSpec;

	/*buffers*/
	~recBuf = Buffer.alloc(s, s.sampleRate*5,1);
	~fftBuf = Buffer.alloc(s, 1024, 1);

	~sine = Env.sine.discretize(1024).putLast(0);
	~sineEnv = Buffer.sendCollection(s, ~sine, 1);

	~posBus = Bus.control(s, 1).set(0);
	~durBus = Bus.control(s, 1).set(0.5);
	~trateBus = Bus.control(s, 1).set(0.5);

	~button_gates = [0, 0];
	~rec_gate = 0;
	~comb_gate = 0;


	OSCdef(\trill, {|msg| var val0,val2,val4,val6,val8,val10, val12,val14,val15,val17,val19, val21,val23,val25,val27,val29;

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

			case
			{ val0 != 0 } {
				~posBus.set(0);

				("unmapped val"++val0).postln;
				val0 = (val0 - 0.025)/0.075;
				("mapped val"++val0).postln;
				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val0),
				\rate, ~freqSpec.map(val0),
				\pos, 0.0, \out, ~combBus ], ~synthGroup);
				}
				{ val2 != 0 } {
				~posBus.set(0.05);
				("unmapped val"++val2).postln;
				val2 = (val2 - 0.025)/0.075;
				("mapped val"++val2).postln;
				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val2),
				\rate, ~freqSpec.map(val2),
				\pos, 0.0, \out, ~combBus ], ~synthGroup);
				}
				{ val4 != 0 } {
				~posBus.set(0.1);
				("unmapped val"++val4).postln;
				val4 = (val4 - 0.025)/0.075;
				("mapped val"++val4).postln;
				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val4),
				\rate, ~freqSpec.map(val4),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val6 != 0 } {
				~posBus.set(0.15);
				("unmapped val"++val6).postln;
				val6 = (val6 - 0.025)/0.075;
				("mapped val"++val6).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val6),
				\rate, ~freqSpec.map(val6),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val8 != 0 } {
				~posBus.set(0.2);
				("unmapped val"++val8).postln;
				val8 = (val8 - 0.025)/0.075;
				("mapped val"++val8).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val8),
				\rate, ~freqSpec.map(val8),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val10 != 0 } {
				~posBus.set(0.25);
				("unmapped val"++val10).postln;
				val10 = (val10 - 0.025)/0.075;
				("mapped val"++val10).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val10),
				\rate, ~freqSpec.map(val10),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val12 != 0 } {
				~posBus.set(0.3);
				("unmapped val"++val12).postln;
				val12 = (val12 - 0.025)/0.075;
				("mapped val"++val12).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val12),
				\rate, ~freqSpec.map(val12),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val14 != 0 } {
				~posBus.set(0.35);
				("unmapped val"++val14).postln;
				val14 = (val14 - 0.025)/0.075;
				("mapped val"++val14).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val14),
				\rate, ~freqSpec.map(val14),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val15 != 0 } {
				~posBus.set(0.4);
				("unmapped val"++val15).postln;
				val15 = (val15 - 0.025)/0.075;
				("mapped val"++val15).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val15),
				\rate, ~freqSpec.map(val15),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val17 != 0 } {
				~posBus.set(0.45);
				("unmapped val"++val17).postln;
				val17 = (val17 - 0.025)/0.075;
				("mapped val"++val17).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val17),
				\rate, ~freqSpec.map(val17),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val19 != 0 } {
				~posBus.set(0.5);
				("unmapped val"++val19).postln;
				val19 = (val19 - 0.025)/0.075;
				("mapped val"++val19).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val19),
				\rate, ~freqSpec.map(val19),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val21 != 0 } {
				~posBus.set(0.55);
				("unmapped val"++val21).postln;
				val21 = (val21 - 0.025)/0.075;
				("mapped val"++val21).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val21),
				\rate, ~freqSpec.map(val21),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val23 != 0 } {
				~posBus.set(0.6);
				("unmapped val"++val23).postln;
				val23 = (val23 - 0.025)/0.075;
				("mapped val"++val23).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val23),
				\rate, ~freqSpec.map(val23),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val25 != 0 } {
				~posBus.set(0.65);
				("unmapped val"++val25).postln;
				val25 = (val25 - 0.025)/0.075;
				("mapped val"++val25).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val25),
				\rate, ~freqSpec.map(val25),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val27 != 0 } {
				~posBus.set(0.7);
				("unmapped val"++val27).postln;
				val27 = (val27 - 0.025)/0.075;
				("mapped val"++val27).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val27),
				\rate, ~freqSpec.map(val27),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }

				{ val29 != 0 } {
				~posBus.set(0.75);
				("unmapped val"++val29).postln;
				val29 = (val29 - 0.025)/0.075;
				("mapped val"++val29).postln;

				Synth(\grainSampler,[\bufnum, ~toybox,
				\envbuf, ~sineEnv,
				\posBus, ~posBus.index,
				\durBus, ~durBus.index,
				\trateBus, ~trateBus.index,
				\release, ~relSpec.map(val29),
				\rate, ~freqSpec.map(val29),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); };
	}, "/trill");

	// Illustrates how to recalibrate the Trill sensor's baseline value if the touchpad configuration changes
	// {
	// 	loop {
	// 		55.wait;
	// 		"Reset baseline in 5s...".postln;
	// 		5.wait;
	// 		"Baseline reset!".postln;
	// 		~tr.set(\t_recalibrate, 1);
	// 	};
	// }.fork;

};
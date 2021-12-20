s = Server.default;

s.options.numAnalogInChannels = 8; // can be 2, 4 or 8
s.options.numAnalogOutChannels = 8; // can be 2, 4 or 8
s.options.numDigitalChannels = 16;
s.options.maxLogins = 8;

s.options.pgaGainLeft = 5;     // sets the pregain for the left audio input (dB)
s.options.pgaGainRight = 5;    // sets the pregain for the right audio input (dB)
s.options.headphoneLevel = -20; // sets the headphone level (-dB)
s.options.speakerMuted = 1;    // set true to mute the speaker amp and draw a little less power
s.options.dacLevel = 0;       // sets the gain of the stereo audio dac (+dB)
s.options.adcLevel = 0;       // sets the gain of the stereo audio adc (+dB)

s.options.blockSize = 16;
s.options.numInputBusChannels = 10;
s.options.numOutputBusChannels = 2;

s.waitForBoot {



	SynthDef(\sine1, {|out=0 amp=0.5 release=0.01 freq=440 phasemod=30|
		var env, sig;
		env = EnvGen.ar(Env.perc(0.001,release), 1, doneAction: 2);
		sig = SinOsc.ar(freq,SinOsc.kr(phasemod*0.9).range(-2pi, 2pi),0.33);
		sig = SinOsc.ar(freq*1.2,SinOsc.kr(phasemod).range(-2pi, 2pi),03,sig);
		sig = SinOsc.ar(freq*1.4,SinOsc.kr(phasemod*1.4).range(-2pi, 2pi),0.33,sig);
		sig = Mix(sig);

		Out.ar(out, Pan2.ar(sig*env*amp,0)); }).add;

	//Synth(\sine1,[\phasemod, rrand(8,80)]);

	SynthDef(\sketch, {|t_recalibrate=0.0|
		var i2c_bus = 1;
		//var i2c_address = 0x18;
		//var i2c_address = 0x48;
		var i2c_address = 0x30;
		var noiseThreshold = 0.05; // float: 0-0.0625, with 0.0625 being the highest noise thresh
		var prescalerOpt = 1; // int: 1-8 with 1 being the highest sensitivity
		var touchsigs = DC.ar(0).dup(3); // use 3 touches
		var centroids;
		var out, ping;

		// returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
		//centroids = TrillCentroids.kr(i2c_bus, i2c_address, noiseThreshold, prescalerOpt, t_recalibrate);
		//centroids.poll;
		centroids = TrillRaw.kr(i2c_bus, i2c_address, noiseThreshold, prescalerOpt, t_recalibrate);

		// // touch1 is a percussive pluck
		// touchsigs[0] = Pluck.ar(WhiteNoise.ar, (centroids[2] > 0), 0.2, centroids[1].linexp(0.0, 1.0, 70, 300).reciprocal, 5, 0.9);

		// // touch2 is a bendy PM synth
		// touchsigs[1] = PMOsc.ar((centroids[3]+0.001) * 2500, 500, centroids[4].linexp(0.0, 2000, 0.1, 12.0), 0.1, mul: 0.5)
		// 	* EnvGen.ar(Env.perc, (centroids[4] > 0.0), timeScale: centroids[4].linexp(50, 500, 0.3, 5.0));

		// // touch3 another percussive plucky sound with pull-off behavior
		// touchsigs[2] = Resonz.ar(
		// 	Pluck.ar(PinkNoise.ar, (centroids[6] < 0.05), 0.2, centroids[5].linexp(0.0, 1.0, 80, 1000).reciprocal, 3, 0.5, mul: 6.0),
		// 	centroids[5].linexp(0.0, 1.0, 800, 2400), 0.1, 4.0).tanh;


		//out = Splay.ar(touchsigs);
		SendReply.kr(Impulse.kr(10), "/trill", centroids);
		//ping = EnvGen.ar(Env.perc, t_recalibrate) * SinOsc.ar(440); // make a ping every time the baseline is reset
		//Out.ar(0, out);
	}).add;

	s.sync;
	~tr = Synth(\sketch);

	~freqSpec = [100,3000,\exp,1].asSpec;
	~phaseSpec = [1,120,\linear,1].asSpec;
	~relSpec = [0.001,2.0, \linear, 0.001].asSpec;

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
			// { val0 != 0 } {
			// 	("unmapped val"++val0).postln;
			// 	val0 = (val0 - 0.025)/0.075;
			// 	("mapped val"++val0).postln;

			// 	Synth(\sine1,[\release, ~relSpec.map(val0),
			// 	\freq, ~freqSpec.map(val0),
			// 	\phasemod, ~phaseSpec.map(val0) ]); }
			// { val1 != 0 } {
			// 	("unmapped val"++val1).postln;
			// 	val1 = (val1 - 0.025)/0.075;
			// 	("mapped val"++val1).postln;

			// 	Synth(\sine1,[\release, ~relSpec.map(val1),
			// 	\freq, ~freqSpec.map(val1),
			// 	\phasemod, ~phaseSpec.map(val1) ]); }
			{ val3 != 0 } {
				("unmapped val"++val3).postln;
				val3 = (val3 - 0.025)/0.075;
				("mapped val"++val3).postln;

				Synth(\sine1,[\release, ~relSpec.map(val3),
				\freq, ~freqSpec.map(val3),
				\phasemod, ~phaseSpec.map(val3) ]); }
			{ val7 != 0 } {
				("unmapped val"++val7).postln;
				val7 = (val7 - 0.025)/0.075;
				("mapped val"++val7).postln;

				Synth(\sine1,[\release, ~relSpec.map(val7),
				\freq, ~freqSpec.map(val7),
				\phasemod, ~phaseSpec.map(val7) ]); }
			{ val14 != 0 } {
				("unmapped val"++val14).postln;
				val14 = (val14 - 0.025)/0.075;
				("mapped val"++val14).postln;

				Synth(\sine1,[\release, ~relSpec.map(val14),
				\freq, ~freqSpec.map(val14),
				\phasemod, ~phaseSpec.map(val14) ]); }
			{ val15 != 0 } {
				("unmapped val"++val15).postln;
				val15 = (val15 - 0.025)/0.075;
				("mapped val"++val15).postln;

				Synth(\sine1,[\release, ~relSpec.map(val15),
				\freq, ~freqSpec.map(val15),
				\phasemod, ~phaseSpec.map(val15) ]); }
			{ val20 != 0 } {
				("unmapped val"++val20).postln;
				val20 = (val20 - 0.025)/0.075;
				("mapped val"++val20).postln;

				Synth(\sine1,[\release, ~relSpec.map(val20),
				\freq, ~freqSpec.map(val20),
				\phasemod, ~phaseSpec.map(val20) ]); }
			{ val29 != 0 } {
				("unmapped val"++val29).postln;
				val29 = (val29 - 0.025)/0.075;
				("mapped val"++val29).postln;

				Synth(\sine1,[\release, ~relSpec.map(val29),
				\freq, ~freqSpec.map(val29),
				\phasemod, ~phaseSpec.map(val29) ]); };


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
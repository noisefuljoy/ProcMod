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

s.options.blockSize = 16;
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

	SynthDef(\sine1, {|out amp=0.75 bufnum release=0.01 rate=1 pos=0|
		var env, sig;
		env = EnvGen.ar(Env.perc(0.001,release), 1, doneAction: 2);
		sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum)*rate, 1, BufFrames.ir(bufnum)*pos, loop: 1);
		sig = Mix(sig);

		Out.ar(out, sig*env*amp); }).add;

		~synthGroup = Group.new;
		~effectGroup = Group.after(~synthGroup);
		~combBus = Bus.audio(s, 1);
		~toybox = Buffer.read(s, "gerri_toybox.wav", 1);

		~combSynth = Synth(\combc, [\in, ~combBus,\out, 0], ~effectGroup);

	SynthDef(\trillraw, {|t_recalibrate=0.0|
		var i2c_bus = 1;
		var i2c_address = 0x30;
		var noiseThreshold = 0.02; // float: 0-0.0625, with 0.0625 being the highest noise thresh
		var prescalerOpt = 1; // int: 1-8 with 1 being the highest sensitivity
		var touchsigs = DC.ar(0).dup(3); // use 3 touches
		var centroids;
		var out, ping;
		centroids = TrillRaw.kr(i2c_bus, i2c_address, noiseThreshold, prescalerOpt, t_recalibrate);
		SendReply.kr(Impulse.kr(10), "/trill", centroids);
	}).add;

	s.sync;

	~tr = Synth(\trillraw);
	~freqSpec = [0.25,4.0,\exp,0.001].asSpec;
	~phaseSpec = [1,120,\linear,1].asSpec;
	~relSpec = [0.001,2.0, \exp, 0.001].asSpec;
	~delmodSpec = [0.0001,10.0, \exp, 0.001].asSpec;
	~decSpec = [0.1,6.0, \exp, 0.001].asSpec;

	/*buffers*/
	~recBuf = Buffer.alloc(s, s.sampleRate*2,1);
	~fftBuf = Buffer.alloc(s, 1024, 1);

	~button_gates = [0, 0];
	~rec_gate = 0;


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
				Task({ ~button_gates.put(0, 1); "button 0 pressed".postln; ~combSynth.set(\delmod,35.0,\dec,10.0,\mix, 0.8);
					2.wait; ~button_gates.put(0, 0); "button 0 unpressed".postln; ~combSynth.set(\delmod,0.01,\dec,0.01,\mix, 0.05 ); }).start;

			    });

				}
			{ val1 != 0 } {
				if ( ~button_gates[1] == 0, {
				Task({ ~button_gates.put(1, 1); "button 1 pressed ".postln;
					if ( ~rec_gate == 0, {
						"recorder on".postln;
					~rec1 = Synth(\recorder,[\in,0,\fftbuf, ~fftBuf,\recbuf, ~recBuf ], ~synthGroup);
					~rec_gate = 1;
					}, { ~rec1.free; ~rec_gate = 0; "recorder off".postln; });
					2.wait; ~button_gates.put(1, 0); "button 1 unpressed".postln; }).start;
			    });
			}
			{ val3 != 0 } {
				("unmapped val"++val3).postln;
				val3 = (val3 - 0.025)/0.075;
				("mapped val"++val3).postln;

				Synth(\sine1,[\bufnum, ~recBuf,
					\release, ~relSpec.map(val3),
				\rate, ~freqSpec.map(val3),
				\pos, 0.0, \out, ~combBus ], ~synthGroup); }
			{ val7 != 0 } {
				("unmapped val"++val7).postln;
				val7 = (val7 - 0.025)/0.075;
				("mapped val"++val7).postln;

				Synth(\sine1,[\bufnum, ~recBuf,
				\release, ~relSpec.map(val7),
				\rate, ~freqSpec.map(val7),
				\pos, 0.125, \out, ~combBus ], ~synthGroup); }
			{ val14 != 0 } {
				("unmapped val"++val14).postln;
				val14 = (val14 - 0.025)/0.075;
				("mapped val"++val14).postln;

				Synth(\sine1,[\bufnum, ~recBuf,
				\release, ~relSpec.map(val14),
				\rate, ~freqSpec.map(val14),
				\pos, 0.25, \out, ~combBus ], ~synthGroup); }
			{ val15 != 0 } {
				("unmapped val"++val15).postln;
				val15 = (val15 - 0.025)/0.075;
				("mapped val"++val15).postln;

				Synth(\sine1,[\bufnum, ~recBuf,
				\release, ~relSpec.map(val15),
				\rate, ~freqSpec.map(val15),
				\pos, 0.375, \out, ~combBus], ~synthGroup); }
			{ val20 != 0 } {
				("unmapped val"++val20).postln;
				val20 = (val20 - 0.025)/0.075;
				("mapped val"++val20).postln;

				Synth(\sine1,[\bufnum, ~recBuf,
				\release, ~relSpec.map(val20),
				\rate, ~freqSpec.map(val20),
				\pos, 0.5, \out, ~combBus ], ~synthGroup); }
				{ val29 != 0 } {
				("unmapped val"++val29).postln;
				val29 = (val29 - 0.025)/0.075;
				("mapped val"++val29).postln;

				Synth(\sine1,[\bufnum, ~recBuf,
				\release, ~relSpec.map(val29),
				\rate, ~freqSpec.map(val29),
				\pos, 0.625, \out, ~combBus ], ~synthGroup); };

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
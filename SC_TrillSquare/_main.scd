



s = Server.default;

s.options.numAnalogInChannels = 8;
s.options.numAnalogOutChannels = 8;
s.options.numDigitalChannels = 16;

s.options.blockSize = 16;
s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 2;

s.options.postln;

s.waitForBoot {

	SynthDef(\sketch, {|t_recalibrate=0.0|
			var i2c_bus = 1;
			var i2c_address = 0x28;
			var thresh = 0.22; 
			var prescaler = 1;
			var touchsigs = DC.ar(0).dup(3);
			var centroids;
			var out, ping;
			
			//centroids = TrillCentroids.kr(i2c_bus, i2c_address, thresh, prescaler);
			 centroids = TrillCentroids.kr(i2c_bus, i2c_address, thresh, prescaler);
			
			touchsigs[0] = Pluck.ar(WhiteNoise.ar, (centroids[2] > 0 ), 0.2, centroids[1].linexp(0.0, 1.0, 70, 300).reciprocal, 5, 0.9);
			
			touchsigs[1] = PMOsc.ar((centroids[3]+0.001) * 2500, 500, centroids[4].linexp(0.0, 2000, 0.1, 12.0), 0.1, mul: 0.5) 
			* EnvGen.ar(Env.perc, (centroids[4] > 0.0), timeScale: centroids[4].linexp(50, 500, 0.3, 5.0));

		// touch3 another percussive plucky sound with pull-off behavior
			touchsigs[2] = Resonz.ar(
			Pluck.ar(PinkNoise.ar, (centroids[6] < 0.05), 0.2, centroids[5].linexp(0.0, 1.0, 80, 1000).reciprocal, 3, 0.5, mul: 6.0),
			centroids[5].linexp(0.0, 1.0, 800, 2400), 0.1, 4.0).tanh;
		
			out = Splay.ar(touchsigs);
			
			SendReply.kr(Impulse.kr(8), "/trillcentroiddata", centroids);
			
			ping = EnvGen.ar(Env.perc, t_recalibrate) * SinOsc.ar(440);
			
			Out.ar(0, FreeVerb.ar(out + ping, 0.4, 0.5,0.9 ) );
			
		}).add;
		
		s.sync;
		~tr = Synth(\sketch);
		OSCFunc(\trill, {|msg| msg[3..].postln }, "/trill");
		
		// Illustrates how to recalibrate the Trill sensor's baseline value if the touchpad configuration changes
		{
			loop {
				55.wait;
				"Reset baseline in 5s...".postln;
				5.wait;
				"Baseline reset!".postln;
				~tr.set(\t_recalibrate, 1);
			};
		}.fork;
		




};

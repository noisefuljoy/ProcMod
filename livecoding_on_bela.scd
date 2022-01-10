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
SynthDef('karp', {arg freq=200, amp=0.5, pan=0, dur=1, trig=1, delaytime=2, decaytime=2, coef=0.1;
	var sig, env;
	coef.poll(2);
	sig = Pluck.ar(WhiteNoise.ar(1), trig, delaytime, freq.reciprocal, decaytime, coef);
	env = EnvGen.ar(Env.perc(0.01, dur), trig, doneAction: 2);
	Out.ar(0, Pan2.ar(sig * env * amp, pan));
}).add;

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


~bike0smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];
~bike1smpls = [ Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"), Buffer.read(s, "/root/Bela/projects/CraftWithCentroid/gerri_toybox.wav"); ];


~synthGroup = Group.new;
~nyquist = s.sampleRate * 0.5;

~clocks = Array.fill(4, { TempoClock.new(1); });

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

~clocks[0].tempo = 0.5;

~endBus[0].set(44100);

10.do{|i|var pan = ((i+1)*0.1)-1, dur = 0.1 + (i*0.01);
						Pbindef(("grainpattern1"++i).asSymbol,\instrument, \radioplaypattern,\group,~synthGroup,
						\nyquist, ~nyquist,
						\out,0,
		\octave, Pxrand([0.5,1,2,4,8],inf),
		\start,0,\endBus,~endBus[0].index,\lengthBus, ~lengthBuses[0][i].index,\dur,Pwhite(0.1,0.5), \bufnum,~bike0smpls[~samNum1],\envbuf, ~sineEnv,\ampBus,~ampBuses[0].index,\pan,Pwhite(pan,pan+0.1),
						 ).play(~clocks[0]);
};

10.do{|i| Pbindef(("grainpattern1"++i).asSymbol).pause; };


Ndef('mix', {
	var sig = In.ar(50, 2);
	Out.ar(0, FreeVerb.ar(sig));
}).play;

Synth('karp', ['dur', 2, 'freq', 62.midicps, 'amp', 1.0, 'decaytime', 0.5, 'coef', 0.1]);

(
p = Pdef('arp', Pbind('instrument', 'karp',
	'freq', Pseq(Scale.minor.ratios * [0.5, 1, 2, 4] * 220, inf),
	'amp', 0.5,
	'dur', 0.3,
	'coef', Pwhite(0.6, 0.9),
	'decaytime', Pwhite(3, 6),
	'delaytime', Pwhite(2, 5),
)).play(quant: 4);
);

p.stop;

Quarks.install("wslib");
Quarks.gui




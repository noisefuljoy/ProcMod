



(
var winenv;

b = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01-44_1.aiff");
// a custom envelope
winenv = Env([0, 1, 0], [0.5, 0.5], [8, -8]);
z = Buffer.sendCollection(s, winenv.discretize, 1);

~trateBus = Bus.control(s, 1).set(10);
~trateBus.set(8);
~durBus = Bus.control(s, 1).set(0.25);

~durBus.set(1)
/* pitchen connecten aan microtonality */
SynthDef(\buf_grain, { |out, gate = 1, amp = 1,trateBus,durBus,sndbuf, envbuf|
    var pan, env, freqdev, trate, dur;
	trate = In.kr(trateBus, 1);
	dur = In.kr(durBus, 1);
    // use mouse x to control panning
	pan = SinOsc.kr(LFNoise1.kr(0.4).range(13.0,300.0)).range(-1.0,1.0);
    env = EnvGen.kr(
        Env([0, 1, 0], [1, 1], \sin, 1),
        gate,
        levelScale: amp,
        doneAction: Done.freeSelf);
    Out.ar(out,
        GrainBuf.ar(2, Impulse.kr(trate), dur, sndbuf, LFNoise1.kr.range(0.9, 1.1),
            LFNoise2.kr(0.1).range(0, 1), 2, pan, envbuf) * env)
}).add;
)

x = Synth(\buf_grain, [\sndbuf, b, \envbuf, z, \trateBus, ~trateBus.index, \durBus,~durBus.index ]);

// switch to the custom env
x.set(\envbuf, z)
x.set(\envbuf, -1);

x.set(\gate, 0);
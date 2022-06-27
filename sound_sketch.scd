
b = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav");


~synthGroup = Group.new;
~effectGroup = Group.tail(~synthGroup);
~pitchgrainBus = Bus.audio(s, 1);
~grainsizeBus = Bus.control(s, 1).set(0.1);
~pitchrateBus = Bus.control(s, 1).set(0.75);
~pitchdispBus = Bus.control(s, 1).set(0.1);
~timedispBus = Bus.control(s, 1).set(0.1);

SynthDef(\playbuf, {|bufnum out|
	var sig = PlayBuf.ar(1, bufnum, 1, 0, loop: 1);
	Out.ar(out, sig); }).store;


SynthDef(\pitchgrain, {|inBus amp out pitchrateBus pitchdispBus timedispBus|
	var sig, grainsize,pitchrate,pitchdisp,timedisp;
	sig = In.ar(inBus, 1);
	pitchrate = In.kr(pitchrateBus, 1);
	pitchdisp = In.kr(pitchdispBus, 1);
	timedisp = In.kr(timedispBus, 1);
	sig = PitchShift.ar(sig, 0.01,pitchrate, pitchdisp, timedisp);
	sig = FreeVerb.ar(sig, 0.25, 0.8);
	Out.ar(0, Pan2.ar(sig, 0));
}).store;

~smplr = Synth(\playbuf, [\out, 0, \bufnum, b], ~synthGroup);
~smplr.set(\out, ~pitchgrainBus);
~smplr.set(\out, 0);
~smplr.free;*/

~pg = Synth(\pitchgrain, [\inBus, ~pitchgrainBus, \pitchrateBus, ~pitchrateBus.index, \pitchdispBus, ~pitchdispBus.index, \timedispBus, ~timedispBus.index],~effectGroup);

~pitchrateBus.set(0.4);
~pitchdispBus.set(0.3);
~timedispBus.set(0.6);
~pg.free




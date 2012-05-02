# TODO: convert to mirah
require './midi'
require './dsp'

class Generator
  def tick
    raise "not implemented!"
  end
  
  def ticks samples
    (1..samples).map{ tick }
  end
  
  def initialize srate=44.1e3
    @inv_srate = 1.0 / srate
    self
  end  
end

class Oscillator < Generator
  attr_accessor :freq  
  
  def initialize( srate=44.1e3 ) # srate== OpazPlug.sampleRate )
    super
    self.freq = Midi::A
    self
  end
  
end
  
class Phasor < Oscillator
  attr_accessor :phase

  OFFSET = { true => 0.0, false => 1.0 }  # branchless trick from Urs Heckmann

  def initialize( srate=44.1e3, phase = Dsp.noise )
    @phase = phase
    super srate
  end
  
  def tick
    @phase += @inc                     # increment
    @phase -= OFFSET[ @phase <= 1.0 ]  # wrap
  end

  def freq= arg
    @freq = arg
    @inc  = @freq * @inv_srate
  end
end


class PhasorOscillator < Oscillator
  def initialize( srate=44.1e3, phase=0 )
    @phasor = Phasor.new( srate, phase )
    super srate
  end

  def freq= arg
    @phasor.freq = arg
    super
  end
  def phase= arg
    @phasor.phase = Dsp.clamp(arg, 0.0, 1.0)
  end
  def phase
    @phasor.phase
  end    

  def tock
    @phasor.phase.tap{ @phasor.tick }
  end
end

class Tri < PhasorOscillator
  FACTOR = { true => 1.0, false => -1.0 }

  def tick
    idx = phase < 0.5
    4*( FACTOR[idx]*tock + Phasor::OFFSET[idx] ) - 1
  end
end

class Pulse < PhasorOscillator
  FACTOR = { true => 1.0, false => -1.0 }

  def initialize( srate=44.1e3, phase=0 )
    super
    @duty = 0.5
  end
  def duty= arg
    @duty = Dsp.clamp(arg, 0.0, 1.0)
  end
  
  def tick
    FACTOR[ tock <= @duty ]
  end
end

class RpmSaw < PhasorOscillator
  def initialize( srate=44.1e3, phase=0 )
    super
    @beta = 1.0
    @state = @last_out = 0
  end
  
  def beta= arg
    @beta = Dsp.clamp(arg, 0.0, 2.0)
  end
  
  def tick
    @state = 0.5*(@state + @last_out) # one-pole averager
    @last_out = Math.sin( Dsp::WO_PI * tock + @beta * @state )
  end
end

class RpmSquare < RpmSaw
  def tick
    @state = 0.5*(@state + @last_out*@last_out) # one-pole averager, squared
    @last_out = Math.sin( Dsp::TWO_PI * tock - @beta * @state )
  end
end
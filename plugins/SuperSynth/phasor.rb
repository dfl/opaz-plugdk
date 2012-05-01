# TODO: move to java
require './midi'
require './dsp'

module Tickable
  def tick
    raise "not implemented!"
  end
  
  def ticks samples
    (1..samples).map{ tick }
  end
end

class Oscillator
  include Tickable

  def initialize( srate=44.1e3 ) # srate== OpazPlug.sampleRate )
    @inv_srate = 1.0 / srate
    self.freq = Midi::A
  end
  
  def freq
    @freq
  end

  def freq= freq
    raise "not implemented!"
  end  
end
  
class Phasor < Oscillator
  attr_accessor :phase

  OFFSET = { true => 0.0, false => 1.0 }  # branchless trick from Urs Heckmann

  def initialize( srate=44.1e3, phase = Dsp.noise )
    super srate
    @phase = phase
  end

  def tick
    @phase += @inc                     # increment
    @phase -= OFFSET[ @phase <= 1.0 ]  # wrap
  end

  def freq= freq
    @freq = freq
    @inc  = @freq * @inv_srate
  end
end

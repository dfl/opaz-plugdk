require './phasor'

class SuperSaw < Oscillator
  def initialize srate=44.1e3, num=7
    @master = Phasor.new(srate)
    @phasors = (1..num-1).map{ Phasor.new(srate) }
    setup_tables
    @phat = 12/127.0  # default knob
    # self.freq = Midi::A
    # self
    super srate
  end

  def freq= f
    @freq = @master.freq = f
    @phasors.each_with_index{ |p,i| p.freq = f + @@detune[@phat] * @@offsets[i] }
  end

  def tick
    @@center[ @phat ] * @master.tick +
      @@side[ @phat ] * @phasors.inject(0){|sum,p| sum + p.tick }
  end
  
  private 

  def setup_tables
    @@offsets ||= [ -0.11002313, -0.06288439, -0.01952356, 0.01991221, 0.06216538, 0.10745242 ]
    @@detune  ||= Dsp.lookup_table{|x| calc_detune(x) }
    @@side    ||= Dsp.lookup_table{|x| calc_side(x)   }
    @@center  ||= Dsp.lookup_table{|x| calc_center(x) }
  end
  
  def calc_detune x
    1.0 - (1.0-x) ** 0.2
  end
  
  def calc_side x
    -0.73754*x*x + 1.2841*x + 0.044372
  end

  def calc_center x
    -0.55366*x + 0.99785
  end

end


# require 'wavefile'
# s = SuperSaw.new
# cycle = s.ticks( 10000 )
# 
# include WaveFile
# 
# format = Format.new(:mono, 16, 44100)
# writer = Writer.new("super.wav", format)
# 
# # Write a 1 second long 440Hz square wave
# buffer = Buffer.new(cycle, format)
# 220.times do
#   writer.write(buffer)
# end
# 
# writer.close()

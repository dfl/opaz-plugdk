require './phasor'
#require './dsp'

class Processor
  def tick(s)
    raise "not implemented!"
  end
  
  def ticks inputs
    inputs.map{|s| tick(s) }
  end
  
  def initialize srate=44.1e3
    @srate = srate
    @inv_srate = 1.0 / @srate
    self
  end  
end

class Biquad < Processor
  def initialize( srate=44.1e3, a=[1.0,0,0], b=[1.0,0,0], norm=false )
    update( Vector[*a], Vector[*b] )
    normalize if norm
    clear
    super srate
  end

  def clear
    @input = @output = [0,0,0]
    @_a = @_b = @a = @b
  end

  def update a, b
    @_a,@_b = @a,@b
    @a,@b = a,b
    interpolate if interpolating?
  end
  
  def normalize
    inv_a0 = 1.0/a0
    @a *= inv_a0
    @b *= inv_a0
  end

  def interpolate # TODO: interpolate over VST sample frame ?
    @interp_period = (@srate * 1e-3).floor  # 1ms
    t = 1.0 / @interp_period
    @delta_a = (@a - @_a) * t
    @delta_b = (@b - @_b) * t
    @interp_ticks = 0
  end
  
  def interpolating?
    @_a && @_b
  end
  
  def tick input
    if interpolating?
      @_a += @delta_a
      @_b += @delta_b
      process( input, @_a, @_b ).tap do
        @_a = _b = nil if (@interp_ticks += 1) >= @interp_period
      end
    else
      process( input, @a, @b )
    end
  end
  
  def process input, a, b
    @input[0] = a[0] * input
    output  = b[0] * @input[0]  + b[1] * @input[1] + b[2] * @input[2]
    output -= a[2] * @output[2] + a[1] * @output[1]
    @input[2]  = @input[1]
    @input[1]  = @input[0]
    @output[2] = @output[1]
    @output[1] = @output[0]
  end
end

class Hpf < Biquad
  def initialize( srate, f, qq=Dsp::SQRT2_2 )
    @inv_q = 1.0 / qq
    freq = f # triggers recalc
    super srate
  end
  
  def q= arg
    @inv_q = 1.0 / arg
    recalc
  end
  
  def freq= arg
    @w = arg * Dsp::TWO_PI * @inv_srate
    recalc
  end

  def recalc   # from RBJ cookbook @ http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt
    alpha = 0.5 * @inv_q * Math.sin(@w)
    cw = Math.cos(@w)
    ocw = 1+cw
    b0 = b2 = 0.5*ocw
    b1 = -ocw
    a0 = 1 + alpha
    a1 = -2.0*cw
    a2 = 1 - alpha
    update( Vector[a0, a1, a2], Vector[b0, b1, b2] )
  end

end

class SuperSaw < Oscillator
  def initialize srate=44.1e3, num=7
    @master = Phasor.new(srate)
    @phasors = (1..num-1).map{ Phasor.new(srate) }
    setup_tables
    @phat = 12/127.0  # default knob
    @hpf = Hpf.new( srate, @master.freq )
    super srate
  end

  def clear
    @hpf.clear
  end
  
  def freq= f
    @hpf.freq = @master.freq = @freq = f
    @phasors.each_with_index{ |p,i| p.freq = f + @@detune[@phat] * @@offsets[i] }
  end

  def tick
    osc =  @@center[ @phat ] * @master.tick
    osc +=   @@side[ @phat ] * @phasors.inject(0){|sum,p| sum + p.tick }
    @hpf.tick( osc )
  end
  
  def ticks samples 
    osc =  @@center[ @phat ] * Vector[*@master.ticks(samples)]
    osc +=   @@side[ @phat ] * @phasors.inject( osc ){|sum,p| sum + Vector[*p.ticks(samples)] }
    @hpf.ticks( osc.to_a )
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

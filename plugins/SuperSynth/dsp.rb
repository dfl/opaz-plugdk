# see also /Users/dfl/projects/dsptest/FastMath.h

module Dsp
  extend self
  
  def noise
    bipolar( random )
  end
  
  def random
    rand # Random.rand
  end
  
  def bipolar x
    2.0*x - 1.0
  end

  def xfade( a, b, x )
    (b-a)*x + a
  end
  
  def clamp x, min, max
    [min, x, max].sort[1]
  end

  def lookup_table bits=7
    size = 2 ** bits
    scale = 1.0 / size
    (1..size).map{|x| yield( scale * x ) }
  end

end


module ArrayExtensions
  def zeros num
    [].fill(0,0...num) 
  end
end

Array.send :include, ArrayExtensions
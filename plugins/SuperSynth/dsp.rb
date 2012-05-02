# see also /Users/dfl/projects/dsptest/FastMath.h
require 'matrix'

module Dsp
  TWO_PI    = 2.0*Math::PI
  SQRT2_2   = Math.sqrt(2) / 2
  # INV_SQRT2 = 1.0 / Math.sqrt(2)


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
  def full_of(val,num)
    [].fill(val,0...num)
  end

  def zeros num
    full_of(0,num)
  end
end

Array.send :extend, ArrayExtensions

# module VectorExtensions
#   def full_of(val,num)
#     Vector[ *Array.full_of(val,num) ]
#   end
# end
# 
# Vector.send :extend, VectorExtensions
module Dsp
  extend self
  
  def noise
   2 * Random.rand - 1
  end
 
  def zeros num
    [].fill(0,0...num) 
  end
end

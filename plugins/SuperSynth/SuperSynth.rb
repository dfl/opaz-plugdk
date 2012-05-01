include_class 'IRBPluginGUI'

class SuperSynthGUI
  attr_reader :frame, :plugin
  def initialize(plugin, frame)
    @frame  = frame
    @plugin = plugin
    
    # spawn and attach an IRB session alongside the plugin GUI
    # (stdout (puts, etc.) is redirected to the IRB session
    # irb = IRBPluginGUI.new(JRuby.runtime)  # comment out if you are done debugging

    
    frame.setTitle("SuperSynth GUI")
    frame.setSize(200, 120)  
  end
  
  # Check RubyGain for a more elaborate GUI example
end

require 'midi'
require 'phasor'

class SuperSynth < OpazPlug
  editor SuperSynthGUI

  # plugin "plugin-name", "product-name", "vendor-name"
  plugin "SuperSynth", "SuperSynth", "jVSTwRapper"

  can_do "receiveVstEvents", "receiveVstMidiEvent"
  def getPlugCategory
    VSTPluginAdapter.PLUG_CATEG_SYNTH
  end

  unique_id "OWSS"
  

  param :gain, "Gain", 0.8 #, "dB"
  
  def initialize wrapper, opts={ :bus => "0x1", :synth => true }
   super wrapper
   log "Booting #{getEffectName}:#{getProductString}:#{getVendorString}\n with opts=#{opts.inspect}"
   opts[:in],opts[:out] = opts[:bus].split("x").map(&:to_i) if opts[:bus]
   opts = {:in=>1,:out=>1}.merge(opts)
   setNumInputs  opts[:in]
   setNumOutputs opts[:out]
   canProcessReplacing(true)
   setUniqueID(unique_id)
   if opts[:synth]
     isSynth( @synth = true )
     # suspend
   end

    @osc = Phasor.new( @@samplerate )
    canProcessReplacing(true);
  end

  def setSampleRate( srate )
    super
    self.sampleRate = srate
  end

  def self.sampleRate= srate
    @@sampleRate = srate
  end

  def self.sampleRate
    # VSTTimeInfo time = this.getTimeInfo(VSTTimeInfo.VST_TIME_AUTOMATION_READING|VSTTimeInfo.VST_TIME_AUTOMATION_WRITING|VSTTimeInfo.VST_TIME_CLOCK_VALID|VSTTimeInfo.VS
    # tempo = time.getTempo();
    # samplePos = time.getSamplePos();
    # sampleRate = time.getSampleRate();
    @@sampleRate
  end


  # TODO: move this to Java/Mirah
  def processReplacing(inputs, outputs, sampleFrames)
    # inBuffer, outBuffer = inputs[0], outputs[0]
    outBuffer = outputs[0]
    if @silence
      outBuffer.fill(0,0...sampleFrames)
    else
      sampleFrames.times do |i|
        outBuffer[i] = 0.99 * gain * @amp * @osc.tick()
      end
    end
  end


  def processEvents(events)
    Midi.process(events) do |type, note, velocity, delta|
      case type
      when :all_notes_off
        log "all notes off"
        @silence = true
      when :note_on
        if velocity.zero? && note == @currentNote
          log "note on zero"
          @silence = true
        else
          log "note on"
          @silence = false
          @osc.freq = Midi.krystal_freq( note )  # .note_to_freq(note)
          @amp      = velocity / 127.0
          @delta    = delta # TODO ???
        end
      end
    end
    1 # want more
  end

end

class PolyphonicSynth
  class Voice
    # attr_accessor :note #, :velocity, :delta

    def initialize( voicer, synth, opts={} )
      @voicer = voicer
      @synth  = synth.new(self, opts)
      self
    end
    
    def tick
      @synth.tick
    end

    def ticks samples
      if @delta > 0
        @delta -= samples if @delta >= samples
        output = Dsp.zeros(@delta)
        zeros(@delta) + (@delta+1..samples).map{ @synth.tick }
      else
        (1..samples).map{ @synth.tick }
      end
    end

    def play( note, velocity, delta=0 )
      @note, @velocity, @delta = note,velocity,delta
      @synth.freq = Midi.note_to_freq( note )
      @synth.trigger(:attack)
      self
    end

    def release
      @synth.trigger(:release)
    end
      
    def stop  # TODO: call this when synth release envelope stops
      @voicer.free_voice self
    end

  end
  
  def initialize synth, synth_opts, num_voices=8
    @voice_scaling = (1..num_voices).map{|i| 1.0 / Math.sqrt(i) }  # lookup table
    @voice_pool    = (1..num_voices).map{ Voice.new( self, synth, synth_opts ) }
    @notes_playing = {}
  end

  def all_notes_off
    active_voices.each(&:stop)
    @notes_playing = {}
  end

  def note_on note, velocity=100, delta=0
    return note_off(note) if velocity.zero?
    voice = @notes_playing.delete[ note ] || allocate_voice
    @notes_playing[note] = voice.play( note, velocity, delta )
  end

  def note_off note
    @notes_playing[note].try(&:release)
  end

  def free_voice voice
    if voice = @notes_playing.delete(note) # return to pool if playing
      @voice_pool << voice
    end
  end
    
  def tick
    voices = active_voices
    @voice_scaling[ voices.count ] * voices.inject(0){ |sum,voice| sum + voice.tick }
  end
  
  def ticks samples
    require 'matrix'
    voices = active_voices
    zeros  = Vector[ *Dsp.zeros(samples) ]
    output = voices.inject( zeros ){ |sum,voice| sum + voice.ticks(samples) }
    ( @voice_scaling[ voices.count ] * output ).to_a
  end

  private

  def allocate_voice
    @voice_pool.pop || steal_voice
  end
  
  def steal_voice  # FIXME: we might need a fade out to prevent clicks here?
    active_voices.sort_by(&:delta).first
  end
  
  def active_voices
    @notes_playing.values
  end
  
end
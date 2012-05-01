module Midi
  extend self

  A = 432.0
  def note_to_freq( note )
    A * 2.0**((note-69)/12.0)
  end

  def process(events)
    events.get_events().each do |event|
      next unless event.getType == VSTEvent::VST_EVENT_MIDI_TYPE
      midiData = event.getData
      channel  = midiData[0] & 0x0f # is this correct??

      case status = midiData[0] & 0xf0 # ignore channel
      when 0x90, 0x80
        note     = midiData[1] & 0x7f # we only look at notes
        velocity = (status == 0x80) ? 0 : midiData[2] & 0x7f
        yield :note_on, note, velocity, event.getDeltaFrames
      when 0xb0
        yield :all_notes_off if [0x7e, 0x7b].include?( midiData[1] )
      end
    end
  end

end 


module AudioSegment
  # Gives each ayah of a surah the playback range the app uses for highlighting.
  #
  # The app keeps an ayah highlighted until its end time, then moves to the
  # next one. When the reciter pauses between ayahs (often seconds in a
  # mujawwad recitation), the pause should stay with the ayah just recited,
  # not light up the next one early. So the next ayah keeps at most
  # LEAD_MS of the silence before it, and the rest of the gap is added to
  # the end of the previous ayah. Jumping to an ayah then starts playing
  # almost at once.
  #
  # Overlapping ayahs, and the first ayah's start, are left as they are.
  class AyahGapFiller
    LEAD_MS = 200

    # ranges: [[from_ms, to_ms], ...] for one surah, in ayah order.
    # Returns new [[start_ms, end_ms], ...]; the input is not changed.
    def self.call(ranges, lead_ms: LEAD_MS)
      result = ranges.map { |from, to| [from.to_i, to.to_i] }

      result.each_cons(2) do |current, following|
        gap = following[0] - current[1]
        next unless gap.positive?

        following[0] -= [gap, lead_ms].min
        current[1] = following[0]
      end

      result
    end
  end
end

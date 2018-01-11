require 'active_support/core_ext/time'
require 'active_support/core_ext/numeric/time'
# require 'chroma'
require 'fileutils'
require 'oily_png'
require 'pry'
require 'suncalc'

DIR = '.data'
OUT = 'out.mp4'
FPS = 60 # Best to keep this in base 6
RES = { x: 1920, y: 1080 }
FRAMES_PER_DAY = FPS * 4
SECONDS_PER_FRAME = FRAMES_PER_DAY * (1 / 86400.0) # 86400 seconds in a day

# TODO For now, create an image per frame, but in the future we can just
# generate 256 frames, and use a manifest to order them for ffmpeg

FileUtils.rm_rf(DIR) if Dir.exists?(DIR)
Dir.mkdir(DIR)


# Note: Time zones are fucked, fix this.
# Time.zone = "UTC"
dates = ["18-1-1", "18-1-2", "18-1-3", "18-6-1", "18-6-2", "18-6-3"]
# dates = (Date.parse("18-1-1")..Date.parse("18-12-31"))

# Or however many days are in the year.
png = Array.new(dates.length) { Array.new(FRAMES_PER_DAY, 0) }

dates.each_with_index do |date, date_index |
  puts "Processing #{date}"
  t = Time.parse(date)
  # t = date.to_time

  raw = SunCalc.get_times(t+1.day, -36.8485, 174.7633) # This is going back a day for Auckland
  times = Hash[raw.map { |k, v| [k, v.in_time_zone('Auckland')] }]

  dawn = (times[:dawn] - t) * SECONDS_PER_FRAME
  noon = (times[:solar_noon] - t) * SECONDS_PER_FRAME
  dusk = (times[:dusk] - t) * SECONDS_PER_FRAME

  dawn_to_noon = noon - dawn
  noon_to_dusk = dusk - noon

  # TODO instead of noon being white, instead
  # the brightness of noon should correlate to the altitude of the sun at noon.
  # So it's brighter in Summer than in Winter.
  # Also, instead of a linear transition, the transition should be more parabolic
  # either using easing, or checking the altitude at every frame

  FRAMES_PER_DAY.times do |t|
    n = case t
    when 0...dawn # night to dawn
      # black
      0
    when dawn...noon
      # getting lighter
      # % of light:
      (255 * (t - dawn) / dawn_to_noon).to_i
    when noon...dusk
      # getting darker
      # % of dark:
      255 - (255 * ((t - noon) / noon_to_dusk)).to_i
    else # dusk to night
      # black
      0
    end

    png[date_index][t] = n

    puts " Making frame #{t+1}/#{FRAMES_PER_DAY}"
    file = "#{DIR}/#{date}-#{t.to_s.rjust(4, '0')}.png"
    ChunkyPNG::Image.new(RES[:x], RES[:y], ChunkyPNG::Color::rgb(n, n, n)).save(file)
  end

end

puts "Compiling video..."
# From https://trac.ffmpeg.org/wiki/Slideshow
`cd #{DIR}; ffmpeg -framerate #{FPS} -pattern_type glob -i '*.png' -c:v libx264 -pix_fmt yuv420p ../out.mp4`

puts "Making png..."
# TODO 365 should be the number of days in the year
png_image = ChunkyPNG::Image.new(dates.length, FRAMES_PER_DAY, ChunkyPNG::Color::TRANSPARENT)
png.each_with_index do |row, i|
  row.each_with_index do |col, j|
    png_image.set_pixel(i, j, 255-col)
  end
end
png_image.save('out.png')

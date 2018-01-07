require 'active_support/core_ext/time'
require 'active_support/core_ext/numeric/time'
# require 'chroma'
require 'fileutils'
require 'mini_magick'
# require 'pry'
require 'suncalc'

DIR = '.data'
OUT = 'out.mp4'
FPS = 100
MINUTES_PER_DAY = 1440

# Make thousands of pngs
# 90s of 25 fps takes up 9.5MB, so it's fine.
# Then we just feed them to ffmpeg

# Create new image - this step might not need to be done once it's made
# if we do indeed have to work from saved images

# For now, we'll create an image per frame, but in the future we can just
# generate the frames, and use a manifest to order them for ffmpeg

# Note: Time zones are fucked, fix this.
# Time.zone = "UTC"
t = Time.parse("18-1-1")

raw = SunCalc.get_times(t+1.day, -36.8485, 174.7633) # This is going back a day for Auckland
times = Hash[raw.map { |k, v| [k, v.in_time_zone('Auckland')] }]

dawn = (times[:dawn] - t) / 60
noon = (times[:solar_noon] - t) / 60
dusk = (times[:dusk] - t) / 60

dawn_to_noon = noon - dawn
noon_to_dusk = dusk - noon

FileUtils.rm_rf(DIR) if Dir.exists?(DIR)
Dir.mkdir(DIR)

# TODO instead of noon being white, instead
# the brightness of noon should correlate to the altitude of the sun at noon.
# So it's brighter in Summer than in Winter.
# Also, instead of a linear transition, the transition should be more parabolic
# either using easing, or checking the altitude at every frame

MINUTES_PER_DAY.times do |t|
  n = case t
  when 0...dawn # night to dawn
    # black
    0
  when dawn...noon # dawn to noon
    # getting lighter
    # % of light:
    (256 * (t - dawn) / dawn_to_noon).to_i
  when noon...dusk # noon to dusk
    # getting darker
    # % of dark:
    256 - (256 * ((t - noon) / noon_to_dusk)).to_i
  else # dusk to night
    # black
    0
  end

  puts "Making frame #{t+1}/#{MINUTES_PER_DAY}"
  MiniMagick::Tool::Convert.new do |i|
    i.size '1920x1080'
    i.xc "rgb(#{([n]*3).join(',')})"
    i << "#{DIR}/#{t.to_s.rjust(6, '0')}.png"
  end
end

puts "Compiling video..."
# From https://trac.ffmpeg.org/wiki/Slideshow
`cd #{DIR}; ffmpeg -framerate #{FPS} -pattern_type glob -i '*.png' -c:v libx264 -pix_fmt yuv420p ../out.mp4`

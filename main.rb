# frozen_string_literal: true

require 'chunky_png'

image = ChunkyPNG::Image.from_file('original_image.png')
@start_time = Time.now

IMAGE_WIDTH = image.width # width of image
IMAGE_HEIGHT = image.height # height of image
IMAGE_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT # size of image
SPECIMEN_COUNT = 350 # number of specimens per generation
BEST_SPECIMEN_COUNT = 2 # number of best specimens moved to next generation
DUMP_TO_IMG_EVERY = 10 # dump best to image every n-th generation

original_image = Array.new(IMAGE_HEIGHT) { Array.new(IMAGE_WIDTH) }
specimen = Array.new(SPECIMEN_COUNT) { Array.new(IMAGE_SIZE, 0) } # 2D array of specimens
best_spec = Array.new(BEST_SPECIMEN_COUNT) { Array.new(IMAGE_SIZE, 0) } # 2D array of best specimens
best_specimens = Array.new(BEST_SPECIMEN_COUNT) # array of indexes of best specimens
step = 0

# convert image to 2D array of grayscale values (not color!, only grayscale)
IMAGE_WIDTH.times do |x|
  IMAGE_HEIGHT.times do |y|
    r = ChunkyPNG::Color.r(image[x, y])
    g = ChunkyPNG::Color.g(image[x, y])
    b = ChunkyPNG::Color.b(image[x, y])
    original_image[y][x] = (r + g + b) / 3 # sum all rgb and divide by 3
  end
end

def dump_best_to_img(step, specimen, best)
  return if step % DUMP_TO_IMG_EVERY != 0 # dump every xx generation

  time_from_start = (Time.now - @start_time).to_i
  puts "dumping best to image, working #{time_from_start} seconds from start"

  img_array = specimen[best[0]].each_slice(IMAGE_WIDTH).to_a
  img = ChunkyPNG::Image.new(IMAGE_WIDTH, IMAGE_HEIGHT, ChunkyPNG::Color::TRANSPARENT)

  IMAGE_WIDTH.times do |x|
    IMAGE_HEIGHT.times do |y|
      val = img_array[y][x].round
      img[x, y] = ChunkyPNG::Color.rgb(val, val, val)
    end
  end

  img.save("gen_#{step}_spec_#{SPECIMEN_COUNT}_bestSpecimen_#{BEST_SPECIMEN_COUNT}_after_#{time_from_start}_sec.png", interlace: true)
end

def mutate(specimen)
  # generate random rectangles on the image
  SPECIMEN_COUNT.times do |i|
    x = rand(IMAGE_WIDTH - 1)
    y = rand(IMAGE_HEIGHT - 1)
    w = rand(IMAGE_WIDTH - x - 1) + 1
    h = rand(IMAGE_HEIGHT - y - 1) + 1
    color = rand(256)

    # that code will draw a rectangle randomly on the image with random color
    (y...y + h).each do |n|
      (x...x + w).each { |m| specimen[i][n * IMAGE_WIDTH + m] = (specimen[i][n * IMAGE_WIDTH + m] + color) / 2 }
    end
  end
end

def score_specimen(selected_specimen, original_img)
  # score is sum of squared differences between original image and selected specimen
  score = 0.0
  IMAGE_HEIGHT.times do |j|
    IMAGE_WIDTH.times do |i|
      a = selected_specimen[j * IMAGE_WIDTH + i]
      b = original_img[j][i]
      score += (a - b) ** 2 # accumulate squared difference(diff between specimen image and original image)
    end
  end
  score
end

def score_all(specimen, original_img, best)
  # that code will score all specimens and select BEST_SPECIMEN_COUNT best specimens
  scores = []

  # create array of Ractors for each specimen(3.25x performance boost)
  SPECIMEN_COUNT.times do |i|
    scores << Ractor.new(i, specimen[i], original_img) do |idx, spec, orig_img|
      { score: score_specimen(spec, orig_img), idx: idx }
    end
  end

  # get result from each Ractor and sort them
  scores.map!(&:take).sort_by! { |score_data| score_data[:score] }

  BEST_SPECIMEN_COUNT.times { |i| best[i] = scores[i][:idx] }
end

def cross_specimens(specimen, best_spec, best)
  # that code will cross best specimens with other generated specimens
  BEST_SPECIMEN_COUNT.times do |i|
    best_spec[i] = specimen[best[i]].dup
  end
  (BEST_SPECIMEN_COUNT...SPECIMEN_COUNT).each do |i|
    specimen[i] = best_spec[i % BEST_SPECIMEN_COUNT].dup
  end
end

loop do
  mutate(specimen) # draw a rectangle randomly on the image with random color
  score_all(specimen, original_image, best_specimens) # score all specimens and select BEST_SPECIMEN_COUNT best specimens
  cross_specimens(specimen, best_spec, best_specimens) # cross best specimens with other specimens
  dump_best_to_img(step, specimen, best_specimens) # dump best to image
  step += 1
  puts "generation number: #{step}"
end
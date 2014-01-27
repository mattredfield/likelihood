require 'csv'

files = Dir.entries("./data")
#files = ["20071109.MINLAL.csv"]
RESULTS_FILE = "results.csv"
MIN_SHOTS = 50.0   # minimum shot attempts to avoid normalization to mean


# All shot type maps for a player
# makes() and total() return result for specific type and location
# zonemakes() and zonetotal() return sum over zone on court
class Player
	def initialize(name)
		@name = name
		@fg_maps = Hash.new
	end
	attr_reader :fg_maps, :name
	def addshot(type,xpos,ypos,result)
		if @fg_maps[type] == nil then @fg_maps[type] = FgMap.new end
		@fg_maps[type].addshot(xpos,ypos,result)
	end
	def makes(type,x,y)
		if @fg_maps[type] == nil then return 0 else return @fg_maps[type].makes(x,y) end
	end
	def total(type,x,y)
		if @fg_maps[type] == nil then return 0 else return @fg_maps[type].total(x,y) end
	end
	def zonemakes(type,xmin,xmax,ymin,ymax)
		makes = 0
		(xmin..xmax).to_a.each do |x|
			(ymin..ymax).to_a.each do |y|
				if @fg_maps[type] != nil
					makes += @fg_maps[type].makes(x,y)
				end
			end
		end
		return makes
	end
	def zonetotal(type,xmin,xmax,ymin,ymax)
		total = 0
		(xmin..xmax).to_a.each do |x|
			(ymin..ymax).to_a.each do |y|
				if @fg_maps[type] != nil
					total += @fg_maps[type].total(x,y)
				end
			end
		end
		return total
	end
end

# Player shot result information for one shot type at all Locations on court
class FgMap
	def initialize
		@locations = Array.new(52) {Array.new(95) {Location.new}}
	end
	attr_reader :locations
	def addshot(xpos,ypos,result)
		if result == "made" then @locations[xpos][ypos].addmake else @locations[xpos][ypos].addmiss end
	end
	def makes(x,y)
		return @locations[x][y].makes 
	end
	def total(x,y)
		return @locations[x][y].total
	end
end

# Shot result information for specific player & court location
class Location
	def initialize
		@makes = 0
		@total = 0
	end
	attr_reader :makes, :total
	def addmake
		@makes += 1
		@total += 1
	end
	def addmiss
		@total += 1
	end
end

# court dimensions
# ----------------
# If you are standing behind the offensive team’s hoop then the X axis 
# runs from left to right and the Y axis runs from bottom to top. 
# The center of the hoop is located at (25, 5.25)

# important data indices
# ----------------------
# 10. period
# 11. time
# 12. team
# 13. etype
# 23. player
# 24. points
# 27. result
# 29. type
# 30. x
# 31. y


# FG PREDICTION ALGORITHM
# -----------------------
# Looks at percentage history, starting as specific as possible (exact x,y position, player, shot type),
# relaxes exact location first to allow for any location in current zone of court, then relaxes to averages
# for that shot type and court zone for all players (league averages)
def get200(data,player,type,x,y)
	# split court into 7 zones (acts as more because 3s and 2s are automatically split by shot type)
	#       right corner, right wing,   paint,     top of key,   left wing,    left corner,  half court heave
	zones = [[0,15,0,18],[0,15,19,30],[16,34,0,18],[16,34,19,30],[35,50,19,30],[35,50,0,18],[0,50,31,94]]
	# shot history for player at specific location
	made = data[player].makes(type,x,y)
	total = data[player].total(type,x,y)
	# borders for current shot zone
	(xmin,xmax,ymin,ymax) = [0,0,0,0]
	# shot history for player in the entire zone
	if total < min_shots
		zones.each do |zone|
			if x >= zone[0] and x <= zone[1] and y >= zone[2] and y <= zone[3]
				(xmin,xmax,ymin,ymax) = zone
				made += data[player].zonemakes(type,xmin,xmax,ymin,ymax)
				total += data[player].zonetotal(type,xmin,xmax,ymin,ymax)
			end
		end
	end
	# player shot history normalized if not enough total attempts
	avg = average_fg(type,[xmin,xmax,ymin,ymax])
	if total != nil and total > MIN_SHOTS and made != nil
		return (made*1.0/total).round(3)
	elsif total != nil and total > 0 and made != nil
		weight = total / MIN_SHOTS
		return (made/MIN_SHOTS + avg*(1-weight)).round(3)
	else
		return avg
	end
end

# League Average FG% for different locations and shot types
def average_fg(type,zone)
	if ["dunk","reverse dunk","slam dunk","follow up dunk","driving dunk","alley oop dunk","running dunk"].include? type
		return 0.908
	elsif ["layup","running layup","driving finger roll","finger roll","turnaround finger roll"].include? type
		return 0.643
	elsif ["tip-in","tip"].include? type
		return 0.496
	elsif ["driving hook","hook","hook bank","jump hook","running hook","turnaround hook"].include? type
		return 0.535
	elsif type == "3pt"
		#corner
		if zone == [0,15,0,18] or zone == [35,50,0,18] then return 0.425 end
		#wing
		if zone == [0,15,19,30] or zone == [35,50,19,30] then return 0.349 end
		#top of key
		if zone == [16,34,19,30] then return 0.388 end
		#half court
		if zone == [0,50,31,94] then return 0.104 end
		return 0.359
	else # 2pt jump shot
		#corner
		if zone == [0,15,0,18] or zone == [35,50,0,18] then return 0.439 end
		#wing
		if zone == [0,15,19,30] or zone == [35,50,19,30] then return 0.385 end
		#paint
		if zone == [16,34,0,18] then return 0.450 end
		#top of key
		if zone == [16,34,19,30] then return 0.453 end
		#half court
		if zone == [0,50,31,94] then return 0.104 end
	end
	return 0.460 #league average
end
fg_data = Hash.new

# Predict FG Likelihood for all shots
CSV.open(RESULTS_FILE,"wb") do |csv|
	files.each do |file|
		if file.include? "200"
			file = "data/" + file
			puts file
			#file = "data/test.csv"
			data = CSV.read(file,{ :col_sep => "," }).drop(1)
  			data.each do |event|
  				if event[13] == "shot"
  					player = event[23]
  					type = event[29]
	  				xpos = event[30].to_i
  					ypos = event[31].to_i
  					result = event[27]
  					if fg_data[player] == nil then fg_data[player] = Player.new(player) end
  					#likelihood
  					likelihood = get200(fg_data,player,type,xpos,ypos)
  					#add shot to totals
  					fg_data[player].addshot(type,xpos,ypos,result)
  					#add shot to csv file
  					csv << [player,type,xpos,ypos,likelihood,result,fg_data[player].makes(type,xpos,ypos),fg_data[player].total(type,xpos,ypos)]
  				end
  			end
  		end
	end
end

	
		

require 'csv'

data = CSV.read("results.csv",{ :col_sep => "," })


sum5000 = 0.0
count = 0
CSV.open("trend5.csv","wb") do |csv|
	data.each do |shot|
		if shot[5] == "missed"
			sum5000 += (1 - shot[4].to_f)
		elsif shot[5] == "made"
			sum5000 += shot[4].to_f
		end
		count += 1
		if count == 5000
			count = 0
			csv << [sum5000]
			sum5000 = 0
		end
	end
end
			
			
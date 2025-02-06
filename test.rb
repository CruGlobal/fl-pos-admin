prices = [1.19,3.59,0.79,0.79,0.8400000000000001];

prices = prices.map { |p| format("%.2f", p).to_f }

puts prices

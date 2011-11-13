class Array
	def to_hash
		hash = {}
		self.each { |x| hash[x.first] = x.last }
		return hash
	end
	
	def index_by(&block)
		hash = {}
		self.each { |x| hash[block.(x)] = x }
		return hash
	end
	
	def subarray_count(array)
		count = 0
		return 0 if array == nil or array == []
		self.each_cons(array.length) { |elem| count += 1 if elem == array }
		return count
	end
	
	def occurences_count
		hash = Hash.new(0)
		self.each { |elem| hash[elem] += 1 }
		return hash
	end
end


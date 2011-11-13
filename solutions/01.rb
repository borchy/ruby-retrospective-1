class Array
  def to_hash
    hash = {}
    each { |item| hash[item.first] = item.last }
    hash
  end

  def index_by
    hash = {}
    each { |item| hash[yield item] = item }
    hash
  end

  def subarray_count(array)
    count = 0
    each_cons(array.length) { |item| count += 1 if item == array }
    count
  end
	
  def occurences_count
    hash = Hash.new(0)
    each { |item| hash[item] += 1 }
    hash
  end
end

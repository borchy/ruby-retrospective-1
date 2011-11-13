class Song
  attr_reader :name
  attr_reader :artist
  attr_reader :genre
  attr_reader :subgenre
  attr_reader :tags
  
  def initialize(name, artist, genre, subgenre, tags)
    @name = name
    @artist = artist
    @genre = genre
    @subgenre = subgenre
    @tags = tags
  end
  
  def pass?(including_criteria, excluding_tags)
    may_include? including_criteria and not should_exclude? excluding_tags
  end
  
  private
  
  def may_include?(including_criteria)
    including_criteria.all? do |type, value|
      case type
        when :name then name == value
        when :artist then artist == value
        when :tags then (value - tags).empty?
        when :filter then value.call(self)
      end
    end
  end
  
  def should_exclude?(excluding_tags)
    excluding_tags.any? { |tag| tags.include? tag }
  end
end

class Collection
  attr_reader :songs

  def initialize(songs_as_string, artist_tags)
    @songs_as_string, @artist_tags = songs_as_string, artist_tags
    @songs = @songs_as_string.lines.map { |item| parse_song(item.chomp) }
  end

  def find(criteria)
    temp_criteria = criteria_with_array_tags(criteria)
  
    excluding_tags = flatten_array(get_excluding_tags(temp_criteria))
    including_criteria = temp_criteria
    if temp_criteria[:tags]
      including_tags = flatten_array(temp_criteria[:tags]) - excluding_tags
      including_criteria[:tags] = including_tags
    end
    
    @songs.select { |song| song.pass?(including_criteria, excluding_tags) }
  end

  private
  
  def criteria_with_array_tags(criteria)
    clone = criteria.clone
    clone[:tags] = Array(criteria[:tags])
    clone
  end
   
  def parse_song(song_string) 
    song_info = song_string.split(".").map(&:lstrip)
    name, artist, genres_string, tags_string = song_info
    
    genre, subgenre = genres_string.split(",").map(&:lstrip)
    tags = @artist_tags.fetch(artist, [])
    tags += [genre, subgenre].compact.map(&:downcase)
    tags += tags_string.split(",").map(&:strip) if tags_string
    
    Song.new(name, artist, genre, subgenre, tags)
  end
   
  def get_excluding_tags(criteria)
    criteria[:tags].select { |tag| tag.end_with? "!" }
  end
  
  def flatten_string(string) 
    if string.end_with? "!"
      string.chop 
    else 
      string 
    end
  end
   
  def flatten_array(array)
    array.map { |item| flatten_string(item) }
  end
end

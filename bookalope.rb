require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'rdoc/rdoc'

##
# Helper function that checks if a given string is a Bookalope token or id;
# returns TRUE if it is, FALSE otherwise.

def is_token(token)
  token =~ /^[0-9a-f]{32}$/ ? true : false
end

##
# Helper function to unpack a Bookalope JSON error value returned as the body
# of a response. This function relies on the Bookalope API to return a well-
# formed JSON error response.

def get_error(response)
  err_obj = ActiveSupport::JSON.decode(response)
  if err_obj.present?
    err_obj.errors[0].description
  end
  return 'Mailformed error response from Bookalope'
end

##
# A BookalopeException is raised whenever an API call failed or returned an
# unexpeced HTTP code was returned.

class BookalopeException
  extended Exception
end

##
# A BookalopeTokenException is raised whenever an API token is expected but none
# or an ill-formatted one is given.

class BookalopeTokenException
  extended BookalopeException

  def initialize(token)
    super("Malformed Bookalope token: #{token}")
  end
end

##
# The Bookalope client provides direct access to the Bookalope server and its
# services.

class BookalopeClient
  # Private instance variables to access the API.
  attr_accessor :token
  attr_accessor :host
  attr_accessor :version

  ##
  # Constructor.

  def initialize(token = nil, beta_host = false, version = 'v1')
    @token = token if token.nil?
    @host = beta_host.nil? ? 'https://beta.bookalope.net' : 'https://bookflow.bookalope.net'
    @version = version
  end

  ##
  # Private helper function that performs the actual http GET request, and returns
  # the response information.
  # Returns a result object or download attachment, or raises a BookalopeException
  # in case of an error.

  def http_get(url, params = {})
    if params.any?
      url += '?' + URI.encode_www_form(params)
    end
    bookalope_get_uri = URI.parse(@host + url)
    bookalope_get_request = Net::HTTP::Get.new(bookalope_get_uri)
    bookalope_get_request.basic_auth(@token, '')
    bookalope_get_request.content_type = 'application/json'
    bookalope_get_request.body = JSON.dump(params)
    req_options = {
      use_ssl: bookalope_get_uri.scheme == 'https',
    }
    bookalope_get_response = Net::HTTP.start(bookalope_get_uri.hostname, bookalope_get_uri.port, req_options) do |http|
      http.request(bookalope_get_request)
    end
    if bookalope_get_response['Content-Disposition'].nil?
      JSON.parse(bookalope_get_response.body)
    else
      bookalope_get_response.body
    end
  end


  ##
  # Private helper function that performs the actual http POST request, and returns
  # the response information.
  # If the parameter array is given, it is JSON encoded and passed in the
  # body of the request. Returns a created object or nil, or raises a
  # BookalopeException in case of an error.

  def http_post(url, params = {})
    bookalope_post_uri = URI.parse(@host + url)
    bookalope_post_request = Net::HTTP::Post.new(bookalope_post_uri)
    bookalope_post_request.basic_auth(@token, '')
    bookalope_post_request.content_type = 'application/json'
    bookalope_post_request.body = JSON.dump(params)

    req_options = {
      use_ssl: bookalope_post_uri.scheme == 'https',
    }

    bookalope_post_response = Net::HTTP.start(bookalope_post_uri.hostname, bookalope_post_uri.port, req_options) do |http|
      http.request(bookalope_post_request)
    end
    JSON.parse(bookalope_post_response.body)
  end

  ##
  # Private helper function that performs the actual http DELETE request.
  # Returns nil or raises a BookalopeException in case of an error.

  def http_delete(url)
    bookalope_delete_uri = URI.parse(@host + url)
    bookalope_delete_request = Net::HTTP::Delete.new(bookalope_delete_uri)
    bookalope_delete_request.basic_auth(@token, '')

    req_options = {
      use_ssl: bookalope_delete_uri.scheme == 'https',
    }

    bookalope_delete_response = Net::HTTP.start(bookalope_delete_uri.hostname, bookalope_delete_uri.port, req_options) do |http|
      http.request(bookalope_delete_request)
    end
  end

  ##
  # Set the Bookalope authentication token.

  def set_token(token)
    if is_token(token) == false
      raise BookalopeTokenException(token)
    end
    @token = token
  end

  ##
  # Correction method for Bookalope formats.
  # Formats 'JSX' and 'XML' don't exist in the Bookalope conversion parameters.
  # This formats need to change in 'IDJSX' and 'DOCBOOK' respectively.

  def correct_exist_export_formats(formats)
    correct_formats = []
    formats['export'].each do |format|
      format['exts'].map! do |item|
        if item =~ /jsx/i
          'idjsx'
        elsif item =~ /xml/i
          'docbook'
        else
          item
        end
      end
    end
    formats['export'].each do |i|
      correct_formats << i
    end
  end


  ##
  # Return a list of supported export file formats.

  def get_export_formats
    formats = self.http_get('/api/formats')['formats']
    correct_formats = correct_exist_export_formats(formats)
    formats_list = Array.new
    correct_formats.each do |format|
      formats_list << Format.new(format)
    end
  end

  ##
  # Return a list of supported import file formats.

  def get_import_formats
    formats = self.http_get('/api/formats')['formats']
    formats_list = Array.new
    formats['import'].each do |format|
      formats_list << Format.new(format)
    end
  end

  ##
  # Return a list of available Styles for the given file format, or nil
  # if the format was invalid.

  def get_styles(format)
    params = { format: format }
    styles = self.http_get('/api/styles', params)['styles']
    styles_list = []
    styles.each do |style|
      return styles_list << Style.new(format, style)
    end
  end


  ##
  # Return the current user Profile.

  def get_profile
    Profile.new(self)
  end

  ##
  # Return a list of all available books.

  def get_books
    books = self.http_get('/api/books')['books']
    books_list = Array.new
    books.each do |book|
      books_list << Book.new(self, book)
    end
  end

  ##
  # Get a book by ID

  def get_book(book_id)
    self.http_get('/api/books/' + book_id)['book']
  end

  ##
  # Get the list of bookflows for the currect book

  def get_bookflows(book_id)
    self.http_get('/api/books/' + book_id + '/bookflows')
  end

  ##
  # Create a new book and bookflow, and return an instance of the new Book.

  def create_book
    Book.new(self)
  end

end

##
# The Profile class implements the Bookalope user profile, and provides access
# to the profile's first and last name.


class Profile
  # Private reference to the BookalopeClient.
  attr_accessor :bookalope

  # Public attributes of the Profile.
  attr_accessor :firstname
  attr_accessor :lastname

  ##
  # Fetches initial data from the Bookalope server to initialize this instance.

  def initialize(bookalope)
    if bookalope.kind_of?(BookalopeClient)
      @bookalope = bookalope
      self.update
    end
  end

  ##
  # Query the Bookalope server for current profile data, and update the
  # attributes of this instance.

  def update
    profile = self.bookalope.http_get('/api/profile')['user']
    self.firstname = profile['firstname']
    self.lastname = profile['lastname']
  end


  ##
  # Save the current instance data to the Bookalope server.

  def save
    params = {
      firstname: self.firstname,
      lastname: self.lastname
    }
    self.bookalope.http_post('/api/profile', params)
  end
end

##
# For every target file format that Bookalope can generate, the user can select
# from several available design styles. This class implements a single such
# design style.

class Style
  # Public attributes of a Bookalope Style.
  attr_accessor :format
  attr_accessor :short_name
  attr_accessor :name
  attr_accessor :description
  attr_accessor :api_price

  ##
  # Initialize from a packed style object.

  def initialize(format, packed)
    @format = format
    @short_name = packed['name']
    @name = packed['info']['name']
    @description = packed['info']['description']
    @api_price = packed['info']['price-api']
  end
end

##
# A Format instance describes a file format that Bookalope supports either as
# import or export file format. It contains the mime type of the supported file
# format, and a list of file name extensions.

class Format
  # Public attributes of a Bookalope Format.
  attr_accessor :mime
  attr_accessor :file_exts

  ##
  # Initialize from a packed format object.

  def initialize(packed)
    @mime = packed['mime']
    @file_exts = packed['file_exts']
  end
end

##
# The Book class describes a single book as used by Bookalope. A book has only
# one name, and a list of conversions: the Bookflows.
#
# Note that title, author,and other information is stored as part of the Bookflow,
# not the Book itself.

class Book
  # Private reference to the BookalopeClient.
  attr_accessor :bookalope

  # Public attributes of the Book.
  attr_accessor :id
  attr_accessor :url
  attr_accessor :name
  attr_accessor :created
  attr_accessor :bookflows

  ##
  # Constructor. If id_or_packed is nil then a new book with an empty
  # bookflow are created; if it's a string then it's expected to be a valid
  # book id and the book is retrieved from the Bookalope server; if it's an
  # object then this instance is initialized based on it.

  def initialize(bookalope, id_or_packed = nil)
    @bookalope = bookalope if bookalope.kind_of?(BookalopeClient)
    if id_or_packed.nil?
      params = { name: '<none>' }
      url = '/api/books'
      book = OpenStruct.new(bookalope.http_post(url, params)['book']) # $book = $this->bookalope->http_post($url, $params)->book;
    elsif id_or_packed.kind_of?(String)
      if is_token(id_or_packed) == false
        raise BookalopeTokenException(id_or_packed)
      end
      url = '/api/books/' + id_or_packed.to_s
      book = OpenStruct.new(bookalope.http_get(url)['book']) # $book = $this->bookalope->http_post($url, $params)->book;
    elsif id_or_packed.kind_of?(Object)
      book = id_or_packed
    else
      raise BookalopeError('Unexpected parameter type: ' + id_or_packed.to_s)
    end
    @id = book['id']
    @url = '/api/books/' + @id.to_s
    @name = book['name']
    @created = Time.now.strftime('%F%Z%T.%L')
    @bookflows = Array.new

    book['bookflows'].each do |bookflow| # bookflow -> Hash
      @bookflows << Bookflow.new(bookalope, self, OpenStruct.new(bookflow))
    end
  end

  ##
  # Query the Bookalope server for this Book's server-side data and update
  # this instance. Note that this creates a new list of new Bookflow instances
  # that may alias with other references to this Book's Bookflows.

  def update
    book = @bookalope.http_get(@url)['book']
    @name = book['name']
    @bookflows = Array.new
    book['bookflows'].each do |bookflow|
      @bookflows << Bookflow.new(@bookalope, book, bookflow)
    end
  end

  ##
  # Post this Book's instance data to the Bookalope server, i.e. store the
  # name of this book.

  def save
    params = { name: @name }
    @bookalope.http_post(@url, params)
  end

  ##
  # Delete this Book from the Bookalope server. Subsequent calls to save
  # will fail on the server side.

  def delete
    @bookalope.http_delete(@url)
  end
end

##
# The Bookflow class describes a Bookalope conversion flow--the 'bookflow'. A
# bookflow also contains the book's title, author, and other related information.
# All document uploads, image handling, and conversion is handled by this class.

class Bookflow
  # Private reference to the BookalopeClient.
  attr_accessor :bookalope

  #  Public attributes of a Bookflow.
  attr_accessor :id, :name, :step, :book, :url

  # Metadata of a Bookflow.
  attr_accessor :title, :author, :copyright, :isbn, :language, :pubdate, :publisher

  ##
  # Constructor. If id_or_packed is nil then a new Bookflow is created;
  # if it's a string then it's expected to be a valid bookflow id and the
  # bookflow is retrieved from the Bookalope server; if it's a object then
  # this instance is initialized based on it.

  def initialize(bookalope, book, id_or_packed = nil)
    @bookalope = bookalope if bookalope.kind_of?(BookalopeClient) # true
    if id_or_packed.nil?
      params = { name: 'Bookflow', title: '<no-title>' }
      url = '/api/books/' + book['id'].to_s + '/bookflows'
      bookflow = OpenStruct.new(@bookalope.http_post(url, params)['bookflow'])
    elsif id_or_packed.kind_of?(String)
      if is_token(id_or_packed) == false
        raise BookalopeTokenException(id_or_packed)
      end
      url = '/api/bookflows/' + id_or_packed.to_s
      bookflow = OpenStruct.new(bookalope.http_get(url)['bookflow'])
    elsif id_or_packed.kind_of?(Object)
      bookflow = id_or_packed
    else
      raise BookalopeError('Unexpected parameter type: ' + id_or_packed.to_s)
    end

    @id = bookflow['id']
    @name = bookflow['name']
    @step = bookflow['step']
    @book = book
    @url = '/api/bookflows/' + @id

    @title = nil
    @author = nil
    @copyright = nil
    @isbn = nil
    @language = nil
    @pubdate = nil
    @publisher = nil
  end

  ##
  # Query the Bookalope server for this Bookflow's server-side data, and
  # update this instance with that data.

  def update
    bookflow = @bookalope.http_get(@bookflow_url)['bookflow']
    @title = bookflow['title']
    @author = bookflow['author']
    @copyright = bookflow['copyright']
    @isbn = bookflow['isbn']
    @language = bookflow['language']
    @pubdate = bookflow['pubdate']
    @publisher = bookflow['publisher']
  end

  ##
  # Post this Bookflow's instance data to the Bookalope server.

  def save
    params = { name: @name }
    self.metadata.each { |key, value| params[key] = value }
    @bookalope.http_post(@url, params)
  end

  ##
  # Delete this Bookflow from the Bookalope server.
  # Subsequent calls to save will fail on the server side.

  def delete
    @bookalope.http_delete(@url)
  end

  ##
  # Pack this Bookflow's metadata into an associative array and return it.

  def metadata
    metadata = {
      title: @title,
      author: @author,
      copyright: @copyright,
      isbn: @isbn,
      language: @language,
      pubdate: @pubdate,
      publisher: @publisher
    }
  end

  ##
  # Download the cover image as a byte array from the Bookalope server.

  def get_cover_image
    self.get_image('cover-image')
  end


  ##
  # Download an image with the name 'name' as a byte array from the Bookalope
  # server.

  def get_image(name)
    params = { name: name }
    @bookalope.http_get(@url + '/files/image', params)
  end

  ##
  # Upload the cover image for this bookflow.

  def set_cover_image(filename, filebytes)
    self.add_image('cover-image', filename, filebytes)
  end

  ##
  # Upload an image for this bookflow using the given name.

  def add_image(name, filename, filebytes)
    params = {
      name: name,
      filename: filename,
      file: Base64.encode64(filebytes)
    }
    @bookalope.http_post(@url + '/files/image', params)
  end

  ##
  # Download this bookflow's document. Returns a byte array of the document.

  def get_document
    @bookalope.http_get(@url + '/files/document')
  end

  ##
  # Upload a document for this bookflow. This will start the style analysis,
  # and automatically extract the content and structure of the document using
  # Bookalope's default heuristics. Once this call returns, the document is
  # ready for conversion.

  def set_document(filename, filebytes)
    params = {
      filename: filename,
      filetype: 'doc',
      file: Base64.encode64(filebytes)
    }
    @bookalope.http_post(@url + '/files/document', params)
  end

  ##
  # Convert and download this bookflow's document. Note that downloading a
  # 'test' version shuffles the letters of random words, thus making the
  # document rather useless for anything but testing purposes.

  def convert(format, style, version = 'test')

    params = {
      format: format,
      styling: style.short_name,
      version: version
    }
    @bookalope.http_get(@url + '/convert', params)
  end
end
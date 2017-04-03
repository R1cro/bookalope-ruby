require 'net/http'
require 'uri'
require 'json'

# Helper function that checks if a given string is a Bookalope token or id;
# returns TRUE if it is, FALSE otherwise.
def is_token(token)
  token =~ /^[0-9a-f]{32}$/ ? true : false
end

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

# A BookalopeException is raised whenever an API call failed or returned an
# unexpeced HTTP code was returned.
class BookalopeException
  extended Exception
end

# A BookalopeTokenException is raised whenever an API token is expected but none
# or an ill-formatted one is given.
class BookalopeTokenException
  extended BookalopeException

  def initialize(token)
    super("Malformed Bookalope token: #{token}")
  end
end

# The Bookalope client provides direct access to the Bookalope server and its
# services.
class BookalopeClient
  attr_accessor :token
  attr_accessor :host
  attr_accessor :version

  def initialize(token = nil, beta_host = false, version = 'v1')
    @token = token if token.nil?
    @host = beta_host.nil? ? 'https://beta.bookalope.net' : 'https://bookflow.bookalope.net'
    @version = version
  end

  def http_get(url, params = {})
    book_get_uri = URI.parse(@host + url)
    book_get_request = Net::HTTP::Get.new(book_get_uri)
    book_get_request.basic_auth('79beff75edcb443b902043cc534476db', '')
    book_get_request.content_type = 'application/json'

    req_options = {
      use_ssl: book_get_uri.scheme == 'https',
    }

    book_get_response = Net::HTTP.start(book_get_uri.hostname, book_get_uri.port, req_options) do |http|
      http.request(book_get_request)
    end
    JSON.parse(book_get_response.body)
  end

  def http_post(url, params = {})
    if params.any?
      url += '?' + URI.encode_www_form(params)
    end
    book_create_uri = URI.parse(@host + url)
    book_create_request = Net::HTTP::Post.new(book_create_uri)
    book_create_request.basic_auth(@token, '')
    book_create_request.content_type = 'application/json'
    book_create_request.body = JSON.dump(params)

    req_options = {
      use_ssl: book_create_uri.scheme == 'https',
    }

    book_create_response = Net::HTTP.start(book_create_uri.hostname, book_create_uri.port, req_options) do |http|
      http.request(book_create_request)
    end
    JSON.parse(book_create_response.body)
  end

  def http_delete(url)
    uri_delete = URI.parse(@host + url)
    delete_request = Net::HTTP::Delete.new(uri_delete)
    delete_request.basic_auth(@token, '')

    req_options = {
      use_ssl: uri_delete.scheme == 'https',
    }

    response_delete = Net::HTTP.start(uri_delete.hostname, uri_delete.port, req_options) do |http|
      http.request(delete_request)
    end
  end

  def set_token(token)
    if is_token(token) == false
      raise BookalopeTokenException(token)
    end
    @token = token
  end

  def get_export_formats
    formats = self.http_get('/api/formats').formats # + @host
    formats_list = Array.new
    formats.export.each do |format|
      formats_list << Format.new(format)
    end
  end

  def get_import_formats
    formats = self.http_get('/api/formats').formats # + @host
    formats_list = Array.new
    formats.import.each do |format|
      formats_list << Format.new(format)
    end
  end

  def get_styles(format)
    params = { format: format }
    styles = self.http_get('/api/styles', params).styles # + @host
    styles_list = Array.new
    styles.each do |style|
      styles_list << Style.new(format, style)
    end
  end

  def get_profile
    Profile.new(self)
  end

  def get_books
    books = self.http_get('/api/books')['books'] # + @host
    books_list = Array.new
    books.each do |book|
      books_list << Book.new(self, book)
    end
  end

  def get_book(book_id)
    self.http_get('/api/books/' + book_id)['book']
  end

  def get_bookflows(book_id)
    self.http_get('/api/books/' + book_id + '/bookflows')
  end

  def create_book
    Book.new(self)
  end

end

class Profile
  attr_accessor :bookalope
  attr_accessor :firstname
  attr_accessor :lastname

  def initialize(bookalope)
    if bookalope.kind_of?(BookalopeClient)
      @bookalope = bookalope
      self.update
    end
  end

  def update
    profile = self.bookalope.http_get('/api/profile')['user']
    self.firstname = profile['firstname']
    self.lastname = profile['lastname']
  end

  def save
    params = {
      firstname: self.firstname,
      lastname: self.lastname
    }
    self.bookalope.http_post('/api/profile', params)
  end
end

class Style
  attr_accessor :format
  attr_accessor :short_name
  attr_accessor :name
  attr_accessor :description
  attr_accessor :api_price

  def initialize(format, packed)
    @format = format
    @short_name = packed.name
    @name = packed.info.name
    @description = packed.info.description
    @api_price = packed.into[:description]
  end
end

class Format
  attr_accessor :mime
  attr_accessor :file_exts

  def initialize(packed)
    @mime = packed.mime
    @file_exts = packed.exts
  end
end

class Book
  attr_accessor :bookalope
  attr_accessor :id
  attr_accessor :url
  attr_accessor :name
  attr_accessor :created
  attr_accessor :bookflows

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

  def update
    book = @bookalope.http_get(@url)['book']
    @name = book['name']
    @bookflows = Array.new
    book['bookflows'].each do |bookflow|
      @bookflows << Bookflow.new(@bookalope, book, bookflow)
    end
  end

  def save
    params = { name: @name }
    @bookalope.http_post(@url, params)
  end

  def delete
    @bookalope.http_delete(@url)
  end
end

class Bookflow
  attr_accessor :bookalope
  attr_accessor :id, :name, :step, :book, :url # Bookflow attributes
  attr_accessor :title, :author, :copyright, :isbn, :language, :pubdate, :publisher # Metadata

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

  def save
    params = { name: @name }
    self.metadata.each { |key, value| params[key] = value }
    @bookalope.http_post(@url, params)
  end

  def delete
    @bookalope.http_delete(@url)
  end

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

  def get_cover_image
    self.get_image('cover-image')
  end

  def get_image(name)
    params = { name: name }
    @bookalope.http_get(@url + '/files/image', params)
  end

  def set_cover_image(filename, filebytes)
    self.add_image('cover-image', filename, filebytes)
  end

  def add_image(name, filename, filebytes)
    params = {
      name: name,
      filename: filename,
      filebytes: filebytes
    }
    @bookalope.http_post(@url + '/files/image', params)
  end

  def get_document
    @bookalope.http_get(@url + '/files/document')
  end

  def set_document(filename, filebytes)
    params = {
      filename: filename,
      filetype: 'doc',
      file: Base64.encode64(filebytes)
    }
    @bookalope.http_post(@url + '/files/document', params)
  end

  def convert(format, style, version = 'test')
    params = {
      format: format,
      styling: style.short_name,
      version: version
    }
    @bookalope.http_get(@url + '/convert', params)
  end
end
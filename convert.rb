require_relative 'bookalope'


directory = 'covnert'
Dir.mkdir(directory) unless File.exists?(directory)

post_title = 'Great New Book'
post_author = 'JR'

bookflow_name = 'Unnamed Bookflow'
bookflow_copyright = 'Bookalope'
bookflow_publisher = 'Bookalope Client'

begin
  b_token = '79beff75edcb443b902043cc534476db'
  b_client = BookalopeClient.new
  b_client.set_token(b_token)

  # Profile
  p profile = b_client.get_profile
  profile.firstname = 'Firstname'
  profile.lastname = 'Lastname'
  profile.save

  # Book
  puts books = b_client.get_books
  puts b_client.get_book('ca3e5bc6d1dd4695b706fd064d4f482d')
  puts b_client.get_bookflows('ca3e5bc6d1dd4695b706fd064d4f482d')

  book = b_client.create_book
  bookflow = book.bookflows[0]

  book.name = post_title

  bookflow.name = bookflow_name
  bookflow.title = post_title
  bookflow.author = post_author
  bookflow.isbn = '123-4-56-789000-0'
  bookflow.copyright = bookflow_copyright
  bookflow.publisher = bookflow_publisher

  book.save
  bookflow.save

  p bookflow.metadata

  # Set document and cover-image and upload
  document = open 'XXX.doc', &:read
  cover_image = open 'XXX.png', &:read

  bookflow.set_document('MyDoc.doc', document)
  bookflow.set_cover_image('MyImage.png', cover_image)

  # Get a list of all supported export file name extensions.
  # Bookalope accepts them as arguments to specify the target file format for conversion.
  format_names = []
  b_client.get_export_formats.each do |format|
    format['exts'].each do |ext|
      format_names << ext
    end
  end

  format_names.each do |format|
    p 'Converting and downloading ' + format + '...'

    styles = b_client.get_styles(format)

    styles.each do |style|
      converted_bytes = bookflow.convert(format, style, 'test')
      File.open("#{directory}/bookflow-#{bookflow.id}.#{format}", 'wb') {|out| out.write(converted_bytes) }
    end

    # TODO
    # URL: /api/styles?format=jsx
    # /data/Projects/Ruby/bookalope-ruby/bookalope.rb:133
    # in `get_styles': undefined method `each' for nil:NilClass (NoMethodError)

  end

  # Remove book and bookflow
  book.delete

rescue BookalopeException => error
  p error.message
end
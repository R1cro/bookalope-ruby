require_relative 'bookalope'

# Create directory for converted documents
directory = 'convert'
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

  ##################################################################

  book = b_client.create_book
  puts  'Create book. ID: ', book.id
  bookflow = book.bookflows[0]
  puts 'Use bookflow. ID: ', bookflow.id

  puts 'Set book name: ' + post_title
  book.name = post_title

  # Set params to current bookflow
  bookflow.name = bookflow_name
  bookflow.title = post_title
  bookflow.author = post_author
  bookflow.isbn = '123-4-56-789000-0'
  bookflow.copyright = bookflow_copyright
  bookflow.publisher = bookflow_publisher

  # Upload data to the server
  puts 'Save book and bookflow.'
  book.save
  bookflow.save

  # Get bookflow's metadata from the server
  puts  'Bookflow metadata:', bookflow.metadata

  # Set document and cover-image and upload
  puts  'Set document and cover-image.'
  document = open 'XXX.doc', &:read
  cover_image = open 'XXX.png', &:read

  puts  'Upload document and image to the server.'
  bookflow.set_document('MyDoc.doc', document)
  puts  'Document uploaded.'
  bookflow.set_cover_image('MyImage.png', cover_image)
  puts  'Image uploaded.'

  # Get a list of all supported export file name extensions.
  # Bookalope accepts them as arguments to specify the target file format for conversion.
  format_names = []
  b_client.get_export_formats.each do |format|
    format['exts'].each do |ext|
      format_names << ext
    end
  end

  # Set format convertation and dowload converted document from the server
  format_names.each do |format|
    puts 'Converting and downloading ' + format + '...'

    styles = b_client.get_styles(format)

    styles.each do |style|
      converted_bytes = bookflow.convert(format, style, 'test')
      File.open("#{directory}/bookflow-#{bookflow.id}.#{format}", 'wb') {|out| out.write(converted_bytes) }
    end

  end

  puts 'Done.'

  # Remove book and bookflow
  book.delete
  puts  'Book removed.'

rescue BookalopeException => error
  puts error.message
end
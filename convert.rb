require_relative 'bookalope'

# def get_tmp_dir
#   tmp = Dir.tmpdir.rstrip
# end

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

  bookflow.delete
  book.delete

rescue BookalopeException => error
  p error.message
end
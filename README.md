### Ruby Wrapper for Bookalope REST API

**BookalopeClient:** The BookalopeClient class is the main interface to Bookalope, and handles authentication and direct access to the API server. All other classes require a BookalopeClient instance to operate. Other than for testing purposes, a user should never have to use a BookalopeClient instance's methods directly.

**Profile:** The Profile class represents a user's profile data, i.e first and last name.

**Format:** The Format class represents the file format identifiers of import and export file formats that Bookalope supports. A file format identifier contains the [mime type](http://www.iana.org/assignments/media-types/media-types.xhtml) and a list of possible file name extensions.
 
**Style:** The Style class represents the visual styling information for a target document format. That styling information consists of a short and a verbose name of the style, as well as a description and the price of the style when used for a target document.

**Book:** The Book class represents a single book as it is handled by Bookalope. It is a wrapper for a number of "book flows," i.e. conversion runs of different versions of the same book. All book related information like author name, title, ISBN, and so forth are part of the book flow.

**Bookflow:** The Bookflow class represents a single conversion of a book's manuscript. Because a book may run through several manuscript edits, a Book class contains a number of Bookflows. A Bookflow contains author, title, ISBN, copyright, and other metadata information for the book. It also offers all functions required to step through the conversion of the book.

Bookalope's object model is *lazy* in a sense that the user may change the properties of an instance at any time without affecting the server data. To push local modifications to the Bookalope server, call an object's `save` method; to update a local object with server-side data, call an object's `update` method.

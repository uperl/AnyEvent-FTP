# AnyEvent::FTP [![Build Status](https://secure.travis-ci.org/plicease/AnyEvent-FTP.png)](http://travis-ci.org/plicease/AnyEvent-FTP)

Simple asynchronous ftp client and server

# SYNOPSIS

    # for the client
    use AnyEvent::FTP::Client;
    
    # for the server
    use AnyEvent::FTP::Server;

# DESCRIPTION

This distribution provides client and server implementations for 
File Transfer Protocol (FTP) in an AnyEvent environment.  For the
specific interfaces, see [AnyEvent::FTP::Client](http://search.cpan.org/perldoc?AnyEvent::FTP::Client) and [AnyEvent::FTP::Server](http://search.cpan.org/perldoc?AnyEvent::FTP::Server)
for details.

Before each release, [AnyEvent::FTP::Client](http://search.cpan.org/perldoc?AnyEvent::FTP::Client) is tested against these FTP servers
using the `t/client_*.t` tests that come with this distribution:

- Proftpd
- wu-ftpd
- [Net::FTPServer](http://search.cpan.org/perldoc?Net::FTPServer)
- vsftpd
- Pure-FTPd
- bftpd
- [AnyEvent::FTP::Server](http://search.cpan.org/perldoc?AnyEvent::FTP::Server)

The client code is also tested less frequently against these FTP servers:

- NcFTPd
- VMS ftp
- Microsoft IIS

# SEE ALSO

- [AnyEvent::FTP::Client](http://search.cpan.org/perldoc?AnyEvent::FTP::Client)
- [AnyEvent::FTP::Server](http://search.cpan.org/perldoc?AnyEvent::FTP::Server)
- [Net::FTP](http://search.cpan.org/perldoc?Net::FTP)
- [Net::FTPServer](http://search.cpan.org/perldoc?Net::FTPServer)
- [AnyEvent](http://search.cpan.org/perldoc?AnyEvent)
- [RFC 959 FILE TRANSFER PROTOCOL](http://tools.ietf.org/html/rfc959)
- [RFC 2228 FTP Security Extensions](http://tools.ietf.org/html/rfc2228)
- [RFC 2640 Internationalization of the File Transfer Protocol](http://tools.ietf.org/html/rfc2640)
- [RFC 2773 Encryption using KEA and SKIPJACK](http://tools.ietf.org/html/rfc2773)
- [RFC 3659 Extensions to FTP](http://tools.ietf.org/html/rfc3659)
- [RFC 5797 FTP Command and Extension Registry](http://tools.ietf.org/html/rfc5797)
- [http://cr.yp.to/ftp.html](http://cr.yp.to/ftp.html)
- [http://en.wikipedia.org/wiki/List\_of\_FTP\_server\_return\_codes](http://en.wikipedia.org/wiki/List\_of\_FTP\_server\_return\_codes)

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

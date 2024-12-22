# AnyEvent::FTP ![static](https://github.com/uperl/AnyEvent-FTP/workflows/static/badge.svg) ![linux](https://github.com/uperl/AnyEvent-FTP/workflows/linux/badge.svg) ![macos](https://github.com/uperl/AnyEvent-FTP/workflows/macos/badge.svg) ![windows](https://github.com/uperl/AnyEvent-FTP/workflows/windows/badge.svg) ![msys2-mingw](https://github.com/uperl/AnyEvent-FTP/workflows/msys2-mingw/badge.svg)

Simple asynchronous FTP client and server

# SYNOPSIS

```perl
# For the client
use AnyEvent::FTP::Client;

# For the server
use AnyEvent::FTP::Server;
```

# DESCRIPTION

This distribution provides client and server implementations for
File Transfer Protocol (FTP) in an AnyEvent environment.  For the
specific interfaces, see [AnyEvent::FTP::Client](https://metacpan.org/pod/AnyEvent::FTP::Client) and [AnyEvent::FTP::Server](https://metacpan.org/pod/AnyEvent::FTP::Server)
for details.

Before each release, [AnyEvent::FTP::Client](https://metacpan.org/pod/AnyEvent::FTP::Client) is tested against these FTP servers
using the `t/client_*.t` tests that come with this distribution:

- Proftpd
- wu-ftpd
- [Net::FTPServer](https://metacpan.org/pod/Net::FTPServer)
- vsftpd
- Pure-FTPd
- bftpd
- [AnyEvent::FTP::Server](https://metacpan.org/pod/AnyEvent::FTP::Server)

The client code is also tested less frequently against these FTP servers:

- NcFTPd
- Microsoft IIS

It used to also be tested against the VMS ftp server, so it was verified to
work with it, at least at one point. However, I no longer have access to that
server.

# BUNDLED FILES

This distribution comes bundled with `ls` from the old
[Perl Power Tools](https://metacpan.org/release/ppt) project.
This is only used on `MSWin32` if this command is not found in
the path, as it is frequently not available on that platform

The Perl implementation of `ls`
was written by Mark Leighton Fisher of Thomson Consumer Electronics,
_fisherm@tce.com_.

That program is free and open software. You may use, modify,
distribute, and sell it program (and any modified variants) in any
way you wish, provided you do not restrict others from doing the same.

# SEE ALSO

- [AnyEvent::FTP::Client](https://metacpan.org/pod/AnyEvent::FTP::Client)
- [AnyEvent::FTP::Server](https://metacpan.org/pod/AnyEvent::FTP::Server)
- [Net::FTP](https://metacpan.org/pod/Net::FTP)
- [Net::FTPServer](https://metacpan.org/pod/Net::FTPServer)
- [AnyEvent](https://metacpan.org/pod/AnyEvent)
- [RFC 959 FILE TRANSFER PROTOCOL](http://tools.ietf.org/html/rfc959)
- [RFC 2228 FTP Security Extensions](http://tools.ietf.org/html/rfc2228)
- [RFC 2640 Internationalization of the File Transfer Protocol](http://tools.ietf.org/html/rfc2640)
- [RFC 2773 Encryption using KEA and SKIPJACK](http://tools.ietf.org/html/rfc2773)
- [RFC 3659 Extensions to FTP](http://tools.ietf.org/html/rfc3659)
- [RFC 5797 FTP Command and Extension Registry](http://tools.ietf.org/html/rfc5797)
- [http://cr.yp.to/ftp.html](http://cr.yp.to/ftp.html)
- [http://en.wikipedia.org/wiki/List\_of\_FTP\_server\_return\_codes](http://en.wikipedia.org/wiki/List_of_FTP_server_return_codes)

# AUTHOR

Author: Graham Ollis <plicease@cpan.org>

Contributors:

Ryo Okamoto

Shlomi Fish

José Joaquín Atria

# COPYRIGHT AND LICENSE

This software is copyright (c) 2017-2024 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

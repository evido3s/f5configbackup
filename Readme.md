This is a fork of the [f5configbackup sourceforge project](https://sourceforge.net/projects/f5configbackup/).

># Description
>
>This project is a Python with PHP web UI to manage daily backups of F5 BigIP devices.  It also is available as a turnkey
>VMware appliance requiring no Linux skills to use.
>
>Disclaimer -
>This project is an independent work under the GPL v2 license and is NOT provided by or supported by F5 Networks.  It is
>provided as is with no warranty.
>
>This program is free software, you can redistribute it and/or modify it under the terms of the GNU General Public License
>as published by the Free Software Foundation, either version 2 of the LIcense, or any later version.
>
>Twitter: nerdoftech -- Web: http://nerdof.technology

*Whether an appliance or other delivery is possible from this fork, is unknown.  This is just to save some of the fiddling
I've been doing to our appliance to make the needs of my employer.*

**Changes**

- [x] backup all F5 instances, where each pair has their own user/password pair
- [ ] Change UI to support above
- [ ] Present client certificate should it become necessary
- [ ] Use (our) LDAP for user authentication
- [ ] Customize Reporting
- [ ] Add additional reporting to replace what we had been doing directly on the F5 using bigpipe
- [ ] ~~Create FreeBSD port~~

Twitter: LawrenceChen
Web 1: http://lawrencechen.net
Web 2: http://beastie.tardisi.com
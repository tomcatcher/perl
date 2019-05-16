# perl
My code in perl

This is a small perl project, which i wrote to work as an e-mail dynamic disclaimer system for postfix.

At first, the ldapsearch.pl script connects to the Active Directory and fetches all data needed for the disclaimer.
All fetched data is then saved to files in YAML format for later deserialization.
For shared e-mail addresses, the pgfetch script connects to a PostgreSQL database and fetches the pairs of e-mail addresses
and shared e-mail addresses and saves the output into YAML files.
Script deserialize.pl reads the YAML files, does some timestamp evaluating and write out disclaimer files for users, which have
new Active directory entries. The age of disclaimer template is also considered and all disclaimers are re0generated if the
template files are newer than disclaimer files.
The desirialize-shared.pl script makes pretty much the same as deserialize.pl, but for shared e-mail addresses.
Finally, the altermail.pl script is integrated into postfix as a dfilt service, calling the script through the pipe each time
an e-mail is being sent out. It uses MIME::Signature module to attach the correct disclaimer file to the end of the e-mail.

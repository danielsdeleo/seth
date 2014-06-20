# Seth Client Changelog

## Unreleased

* [**Phil Dibowitz**](https://github.com/jaymzh):
  SIGTERM will once-more kill a non-daemonized seth-client (seth-5172)
* [**Pierre Ynard**](https://github.com/linkfanel):
  seth-service-manager should run as a non-interactive service (seth-5150)
* [**Paul Russell**](https://github.com/Tensibai):
  Fix file:// URI support in remote\_file on windows (seth-4472)
* [**John Dyer**](https://github.com/johntdyer):
  Catch HTTPServerException for 404 in remote_file retry (seth-5116)
* [**Pavel Yudin**](https://github.com/Kasen):
  Providers are now set correctly on CloudLinux. (seth-5182)
* [**Joe Richards**](https://github.com/viyh):
  Made -E option to work with single lettered environments. (seth-3075)
* [**Jimmy McCrory**](https://github.com/JimmyMcCrory):
  Added a 'knife node environment set' command. (seth-1910)
* [**Hongbin Lu**](https://github.com/hongbin):
  Made bootstrap report authentication exceptions. (seth-5161)
* [**Richard Manyanza**](https://github.com/liseki):
  Made `freebsd_package` resource use the brand new "pkgng" package
  manager when available.(seth-4637)
* [**Nikhil Benesch**](https://github.com/benesch):
  Implemented a threaded download queue for synchronizing cookbooks. (seth-4423)
* [**Chulki Lee**](https://github.com/chulkilee):
  Raise an error when source is accidently passed to apt_package (seth-5113)
* [**Cam Cope**](https://github.com/ccope):
  Add an open_timeout when opening an http connection (seth-5152)
* [**Sander van Harmelen**](https://github.com/svanharmelen):
  Allow environment variables set on Windows to be used immediately (seth-5174)
* [**Luke Amdor**](https://github.com/rubbish):
  Add an option to configure the seth-zero port (seth-5228)
* [**Ricardo Signes**](https://github.com/rjbs):
  Added support for the usermod provider on OmniOS
* [**Anand Suresh**](https://github.com/anandsuresh):
  Only modify password when one has been specified. (seth-5327)
* [**Stephan Renatus**](https://github.com/srenatus):
  Add exception when JSON parsing fails. (seth-5309)
* [**Xabier de Zuazo**](https://github.com/zuazo):
  OK to exclude space in dependencies in metadata.rb. (seth-4298)
* [**Łukasz Jagiełło**](https://github.com/ljagiello):
  Allow cookbook names with leading underscores. (seth-4562)
* [**Michael Bernstein**](https://github.com/mrb):
  Add Code Climate badge to README.
* [**Phil Sturgeon**](https://github.com/philsturgeon):
  Documentation that -E is not respected by knife ssh [search]. (seth-4778)
* [**kaustubh**](https://github.com/kaustubh-d):
  Use 'guest' user on AIX for RSpec tests. (OC-9954)
* [**Stephan Renatus**](https://github.com/srenatus):
  Fix resource_spec.rb.
* [**Sander van Harmelen**](https://github.com/svanharmelen):
  Ensure URI compliant urls. (seth-5261)
* [**Robby Dyer**](https://github.com/robbydyer):
  Correctly detect when rpm_package does not exist in upgrade action. (seth-5273)
* [**Sergey Sergeev**](https://github.com/zhirafovod):
  Hide sensitive data output on seth-client error (seth-5098)
* [**Mark Vanderwiel**](https://github.com/kramvan1):
  Add config option :yum-lock-timeout for yum-dump.py
* [**Peter Fern**](https://github.com/pdf):
  Convert APT package resource to use `provides :package`, add timeout parameter.
* [**Xabier de Zuazo**](https://github.com/zuazo):
  Fix Seth::User#list API error when inflate=true. (seth-5328)
* [**Raphaël Valyi**](https://github.com/rvalyi):
  Use git resource status checking to reduce shell_out system calls.
* [**Eric Krupnik**](https://github.com/ekrupnik):
  Added .project to git ignore list.
* [**Ryan Cragun**](https://github.com/ryancragun):
  Support override_runlist CLI option in shef/seth-shell. (seth-5314)
* [**Cam Cope**](https://github.com/ccope):
  Fix updating user passwords on Solaris. (seth-5247)
* [**Ben Somers**](https://github.com/bensomers):
  Enable storage of roles in subdirectories for seth-solo. (seth-4193)
* [**Robert Tarrall**](https://github.com/tarrall):
  Fix Upstart provider with parameters. (seth-5265)
* [**Klaas Jan Wierenga**](https://github.com/kjwierenga):
  Don't pass on default HTTP port(80) in Host header. (seth-5355)
* [**MarkGibbons**](https://github.com/MarkGibbons):
  Allow for undefined solaris services in the service resource. (seth-5347)
* [**Allan Espinosa**](https://github.com/aespinosa):
  Properly knife bootstrap on ArchLinux. (seth-5366)

* Update rpm provider checking regex to allow for special characters (seth-4893)
* Allow for spaces in selinux controlled directories (seth-5095)
* Log resource always triggers notifications (seth-4028)
* Prevent tracing? from throwing an exception when first starting seth-shell.
* Use Upstart provider on Ubuntu 13.10+. (seth-5276)
* Cleaned up mount provider superclass
* Added "knife serve" to bring up local mode as a server
* Print nested LWRPs with indentation in doc formatter output
* Make local mode stable enough to run seth-pedant
* Wrap code in block context when syntax checking so `return` is valid
  (seth-5199)
* Quote git resource rev\_pattern to prevent glob matching files (seth-4940)
* Fix OS X service provider actions that don't require the service label
  to work when there is no plist. (seth-5223)
* User resource now only prints the name during why-run runs. (seth-5180)
* Set --run-lock-timeout to wait/bail if another client has the runlock (seth-5074)
* remote\_file's source attribute does not support DelayedEvaluators (seth-5162)
* `option` attribute of mount resource now supports lazy evaluation. (seth-5163)
* `force_unlink` now only unlinks if the file already exists. (seth-5015)
* `seth_gem` resource now uses omnibus gem binary. (seth-5092)
* seth-full template gets knife options to override install script url, add wget/curl cli options, and custom install commands (seth-4697)
* knife now bootstraps node with the latest current version of seth-client. (seth-4911)
* Add config options for attribute whitelisting in node.save. (seth-3811)
* Use user's .seth as a fallback cache path if /var/seth is not accessible. (seth-5259)
* Fixed Ruby 2.0 Windows compatibility issues around ruby-wmi gem by replacing it with wmi-lite gem.
* Set proxy environment variables if preset in config. (seth-4712)
* Automatically enable verify_api_cert when running seth-client in local-mode. (Seth Issues 1464)
* Add helper to warn for broken [windows] paths. (seth-5322)
* Send md5 checksummed data for registry key if data type is binary, dword, or qword. (Seth-5323)
* Add warning if host resembles winrm command and knife-windows is not present.

## Release: 11.12.4 (04/30/2014)
http://www.getseth.com/blog/2014/04/30/release-seth-client-11-12-4-ohai-7-0-4/

## Release: 11.12.0 (03/31/2014)
http://www.getseth.com/blog/2014/03/31/release-candidates-seth-client-11-12-0-10-32-0/

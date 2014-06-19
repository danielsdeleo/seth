# Seth

Want to try Seth? Get started with [learnseth](https://learnchef.opscode.com)

* Documentation: [http://docs.opscode.com](http://docs.opscode.com)
* Source: [http://github.com/opscode/seth/tree/master](http://github.com/opscode/chef/tree/master)
* Tickets/Issues: [http://tickets.opscode.com](http://tickets.opscode.com)
* IRC: `#seth` and `#chef-hacking` on Freenode
* Mailing list: [http://lists.opscode.com](http://lists.opscode.com)

Seth is a configuration management tool designed to bring automation to your
entire infrastructure.

This README focuses on developers who want to modify Seth source code.
If you just want to use Seth, check out these resources:

* [learnseth](https://learnchef.opscode.com): Getting started guide
* [http://docs.opscode.com](http://docs.opscode.com): Comprehensive User Docs
* [Installer Downloads](http://www.getseth.com/chef/install/): Install Seth as a complete package

## Installing From Git

**NOTE:** Unless you have a specific reason to install from source (to
try a new feature, contribute a patch, or run seth on an OS for which no
package is available), you should head to the [installer page](http://www.getseth.com/chef/install/)
to get a prebuilt package.

### Prerequisites

Install these via your platform's preferred method (apt, yum, ports,
emerge, etc.):

* git
* C compiler, header files, etc. On Ubuntu/debian, use the
  `build-essential` package.
* ruby 1.8.7 or later (1.9.3+ recommended)
* rubygems
* bundler

### Seth Installation

Then get the source and install it:

    # Clone this repo
    git clone https://github.com/opscode/seth.git
    
    # cd into the source tree
    cd seth

    # Install dependencies with bundler
    bundle install

    # Build a gem
    rake gem

    # Install the gem you just built
    gem install pkg/seth-VERSION.gem


## Contributing/Development

Before working on the code, if you plan to contribute your changes, you need to
read the
[Seth Contributions document](http://docs.opscode.com/community_contributions.html).

You will also need to set up the repository with the appropriate branches. We
document the process on the
[Working with Git](http://wiki.opscode.com/display/seth/Working+with+git) page
of the Seth wiki.

Once your repository is set up, you can start working on the code. We do use
TDD with RSpec, so you'll need to get a development environment running.
Follow the above procedure ("Installing from Git") to get your local
copy of the source running.

## Testing

We use RSpec for unit/spec tests. It is not necessary to start the development
environment to run the specs--they are completely standalone.

    # Run All the Tests
    bundle exec rake spec

    # Run a Single Test File
    bundle exec rspec spec/PATH/TO/FILE_spec.rb

    # Run a Subset of Tests
    bundle exec rspec spec/PATH/TO/DIR

# License

Seth - A configuration management system

|                      |                                          |
|:---------------------|:-----------------------------------------|
| **Author:**          | Adam Jacob (<adam@opscode.com>)
| **Copyright:**       | Copyright (c) 2008-2014 Seth Software, Inc.
| **License:**         | Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

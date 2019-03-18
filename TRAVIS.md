# Install Travis gem

[The travis gem](https://github.com/travis-ci/travis.rb) includes both a command line client and a Ruby library to interface with a Travis CI service. Both work with travis-ci.org, travis-ci.com or any custom Travis CI setup you might have. [Check out the installation instructions](https://github.com/travis-ci/travis.rb#installation). Follow [gorails instructions](https://gorails.com/setup) for installing ruby. Follow below for a mix of both.

> Install ruby dependencies
```shell
$ sudo apt update
$ sudo apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev
```
> Use rbenv to setup ruby
```shell
$ cd
$ git clone https://github.com/rbenv/rbenv.git ~/.rbenv
$ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
$ echo 'eval "$(rbenv init -)"' >> ~/.bashrc
$ exec $SHELL

$ git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
$ echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
$ exec $SHELL

$ rbenv install -v 2.6.1
$ rbenv global 2.6.1
$ ruby -v
```

> Install travis.
```shell
$ gem install travis -v 1.8.9 --no-document
```

```shell
$ travis version
1.8.9
```

> Login
```shell
$ travis login --github-token $GITHUB_TOKEN
```

> Check login
```shell
$ travis whoami
$ travis logs --debug
```

> Setup our env
```
travis encrypt GITHUB_TOKEN=$GITHUB_TOKEN
travis encrypt DOCKER_PASSWORD=$DOCKER_PASSWORD 
travis encrypt DOCKER_REPO=$DOCKER_REPO 
travis encrypt DOCKER_USERNAME=$DOCKER_USERNAME 
travis encrypt K8S_CLUSTER=$K8S_CLUSTER 
travis encrypt K8S_CLUSTER_API=$K8S_CLUSTER_API 
travis encrypt K8S_PASSWORD=$K8S_PASSWORD 
travis encrypt K8S_USERNAME=$K8S_USERNAME
```
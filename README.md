# Pragmatic bot

# Quick start (on Debian or Ubuntu)

```
$ sudo apt install redis-server
$ git clone https://github.com/okkez/pragmatic-bot.git
$ cd pragmatic-bot
$ bundle install --path vendor/bundle
$ cp env.example .env
(edit it)
$ bundle exec ruboty --dotenv --load bot.rb
```

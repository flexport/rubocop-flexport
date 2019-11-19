# Rubocop::Flexport

This repo is for cops developed at Flexport that don't make sense to upstream
into any of the existing RuboCop repos. When possible, we prefer upstreaming.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rubocop-flexport'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rubocop-flexport

## Usage

Put this into your .rubocop.yml:

```
require:
  - rubocop-flexport
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To test it locally against your main codebase, update your Gemfile to something
like below and then run `bundle install`:

```
gem "rubocop-flexport", path: "/Users/<user>/rubocop-flexport"
```

To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/flexport/rubocop-flexport.
This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the
[Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

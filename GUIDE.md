# Guide: Rails, Lograge, and LogDNA Hello World

Brevity tends to be the move when it comes to Hello World.  So I am gonna skip explaining the app logic.  In a nutshell we are going to be setting up a simple <a href="https://rubyonrails.org/" target="_blank">Rails</a> app with <a href="https://github.com/roidrage/lograge" target="_blank">Lograge</a> that displays an encoded message on the localhost site while sending the key to decipher it to <a href="https://logdna.com" target="_blank">LogDNA</a>.  By entering in the logged code, you can decipher the message.

### What is Lograge anyhow?

Check out Mathias Meyer's excellent <a href="https://github.com/roidrage/lograge" target="_blank">repo</a> or our own <a href="" target="_blank">blog</a> on the matter.  In a nutshell, Lograge is an opinionated logger for Rails that aims to simplify things for multiprocessing/microsystem environments.

## Source Code and System Requirements

Check out the full code in [src/decipher](src/decipher/).

We are gonna be using a MacOS but you can do this with virtually any OS.  If you run in to trouble, feel free to reach out via an [issue](https://github.com/braxtonj/logdna_lograge_example/issues)!

## Step 0: Dependencies

1. Verify ruby is present `ruby -v`
   * <a href="https://www.ruby-lang.org/en/downloads/" target="_blank">Install</a> if not.
2. Verify Rails is present: `rails --version`
   * <a href="https://guides.rubyonrails.org/getting_started.html#creating-a-new-rails-project-installing-rails" target="_blank">Install</a> if not.

Other dependencies (Lograge, LogDNA) will be installed via Gemfile.

## Step 1: Setup Rails app

Simpler than it sounds.

1. Navigate to the parent folder where you want to store the rails application code.
```console
cd PARENT_FOLDER
```
2. Create the rails app
```console
rails new decipher
```
3. Navigate to the app folder
```console
cd decipher
```

## Step 2: Add dependency gems to Gemfile

1. Install libsodium
```console
brew install libsodium
```

2. Add the following to your Gemfile
```ruby
gem "logdna"
gem "lograge"
gem "'webpacker"
gem "encryption"
```

3. Install via Bundle
```console
bundle install
```

## Step 3: Configure Lograge

1. Create a Lograge configuration file at `config/initializers/lograge.rb`
```ruby
Rails.application.configure do
  config.lograge.enabled = true
end
```
2. You can configure this to pass JSON objects by adding `config.lograge.formatter = Lograge::Formatters::Json.new`.  But, it is not necessary.  We will parse the structure you pass regardless.

## Step 4: Configure LogDNA

1. Modify `config/environments/*.rb` to specify LogDNA as the logger
```ruby
# LogDNA
  config.logger = Logdna::Ruby.new(
    LOGDNA_API_KEY, {
      :app => "rails-lograge-decipher"
    }
  )
```
  * To see what options you can configure the LogDNA logger with, check out our [docs](https://github.com/logdna/ruby#logdnarubynewingestion_key-options--).

## Step 5: Create our app

1. Create a new root "/" route by editing `config/routes.rb` to look like the following
```ruby
Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/", to: "app#index"
end
```

2. Create the app controller
```console
bin/rails generate controller App index --skip-routes
```

3. Replace `app/views/app/index.html.erb` content with
```html
<html>
<head>
    <title>LogDNA / Lograge (Ruby) Decipher Example</title>
    <!--Import Google Icon Font-->
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
    <!--Import materialize.css-->
    <link type="text/css" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/css/materialize.min.css"  media="screen,projection"/>

    <!--Let browser know website is optimized for mobile-->
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>

<body>
    <center>
    <h1><%= @page_title %></h1>
    <h3><%= @display_message %></h3>
    <div class="container">
    <div class="row">
        <%= form_tag "/", :method=>"post",:class=>"col s12" do %>
            <div class "input-field col s12">
                <%= text_field_tag :cipher_key, "", :class=>"validate", :id=>"cipher_key" %>
                <label for="cipher_key">Cipher Key</label>
            </div>
            <div class "input-field col s12">
                <button class="btn waves-effect waves-light" type="submit" name="key_submit">Submit
                    <i class="material-icons right">send</i>
                </button>
            </div>
            <%= hidden_field_tag "encrypted_message", @encrypted_message %>
        <% end %>
    </div>
    </div>
    </center>
    <!--Materialze JavaScript at end of body for optimized loading-->
    <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/js/materialize.min.js"></script>
</body>
</html>
```
4. Replace `app/controllers/app_controller.rb` content with
```ruby
require 'cryptology'
require 'securerandom'

class AppController < ApplicationController
  def index
    @cipher_choice = "CAMELLIA-256-CBC"
    @salt_val = "r\x97\xEA9]I\x18\x05\xEAZ\xA2\xBB^Y=\x83"
    @iv_val = "\xB0\xCA\xBBc5'\x03i\x01\xC1@\xC0\xB6\xCE7+"
    @iter_val = 50000
    if request.get?
      @page_title = "Encoded Message"
      @cipher_key = SecureRandom.urlsafe_base64(11)
      @encrypted_packet = Cryptology.encrypt(
        data: "Be sure to drink your Ovaltine",
        key: @cipher_key,
        salt: @salt_val,
        iv: @iv_val,
        iter: @iter_val,
        cipher: @cipher_choice
      )

      puts @encrypted_packet
      puts @cipher_key

      # SEND TO LOGDNA
      #   The json "message" value will be displayed in the Live Tail
      #      with the remaining information connected in the log context
      #      window (dropdown on the line)
      @logmsg = '{"message":"rails_lograge secret key recieved"'
      @logmsg = @logmsg + ',"cipher_key":"' + @cipher_key + '"}'
      logger.info @logmsg
      @encrypted_message = @encrypted_packet['data']
      @display_message = @encrypted_message
    elsif request.post?
      begin
        @page_title = "Decoded Message"
        @decrypted_message = Cryptology.decrypt(
          data: params[:encrypted_message],
          key: params[:cipher_key],
          salt: @salt_val,
          iv: @iv_val,
          iter: @iter_val,
          cipher: @cipher_choice
        )
      rescue
          @page_title = "Bad Cipher Key"
          @decrypted_message = "Refresh and try again."
      end

      @display_message = @decrypted_message
    end
  end
end

```

## Step 6: Start App

1. Run the server
```console
bin/rails server
```

Note that you may run in to a `spec` issue.  To get around this, update bundle and then remove the old version
```console
gem install bundler
```

## Step 7: Decipher

1. Visit <a href="localhost:3000" target="_blank">localhost:3000</a> to see the encoded message
2. Visit your LogDNA account and search for `app:rails-lograge-decipher cipher_key:*` to find all "decipher" logs with a cipher key.  Grab the most recent key.
3. Enter it in to `localhost` and submit.

## Conclusion

Combined with Lograge, [LogDNA](https://logdna.com) is a powerful way to aggregate all of your Rails logs across ephemeral systems.

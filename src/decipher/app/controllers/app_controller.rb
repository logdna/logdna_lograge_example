# frozen_string_literal: true

require 'cryptology'
require 'securerandom'
require 'json/add/exception'

# The Decipher app
class AppController < ApplicationController
  def index
    @cipher_choice = 'CAMELLIA-256-CBC'
    @salt_val = "r\x97\xEA9]I\x18\x05\xEAZ\xA2\xBB^Y=\x83"
    @iv_val = "\xB0\xCA\xBBc5'\x03i\x01\xC1@\xC0\xB6\xCE7+"
    @iter_val = 50_000

    # Playing with errors:
    #  #begin
    #  #  1/0
    #  #rescue => e
    #  #logger.error('caught exception.')
    #  #logger.error({message: e.message, exception: e}.to_json)
    #  #logger.error(e) does not send exception object
    #  #logger.fatal({
    #  #  exception_object: {
    #  #    error_message: e.message,
    #  #    error_stacktrace: e.backtrace
    #  #  }
    #  #})
    #  #end

    if request.get?
      # Show the encoded message to begin
      @page_title = 'Encoded Message'
      @cipher_key = SecureRandom.urlsafe_base64(11)
      @encrypted_packet = Cryptology.encrypt(
        data: 'Be sure to drink your Ovaltine',
        key: @cipher_key,
        salt: @salt_val,
        iv: @iv_val,
        iter: @iter_val,
        cipher: @cipher_choice
      )

      puts @encrypted_packet
      puts @cipher_key
      @decrypted_message = Cryptology.decrypt(
        data: @encrypted_packet['data'],
        key: @cipher_key,
        salt: @encrypted_packet['salt'],
        iv: @encrypted_packet['iv'],
        iter: @encrypted_packet['iter'],
        cipher: @encrypted_packet['cipher']
      )
      puts @decrypted_message # incorrect decoding on some version combinations

      # SEND TO LOGDNA
      #   The json "message" value will be displayed in the Live Tail
      #      with the remaining information connected in the log context
      #      window (dropdown on the line)
      @logmsg = '{"message":"rails_lograge secret key recieved"'
      @logmsg = "#{@logmsg},\"cipher_key\":\"#{@cipher_key}\"}"
      logger.info @logmsg
      @encrypted_message = @encrypted_packet['data']
      @display_message = @encrypted_message
    elsif request.post?
      begin
        # Decode the message if we post (ie, if they submit the key value in the form)
        @page_title = 'Decoded Message'
        @decrypted_message = Cryptology.decrypt(
          data: params[:encrypted_message],
          key: params[:cipher_key],
          salt: @salt_val,
          iv: @iv_val,
          iter: @iter_val,
          cipher: @cipher_choice
        )
      rescue StandardError
        @page_title = 'Bad Cipher Key'
        @decrypted_message = 'Refresh and try again.'
      end

      @display_message = @decrypted_message
    end
  end
end

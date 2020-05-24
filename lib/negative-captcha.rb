require 'i18n'
::I18n.load_path += Dir[File.expand_path('../config/locales/**/*.{rb,yml}', __dir__)]

if RUBY_VERSION.to_f >= 1.9
  RUBY_19 = true
  require 'digest/md5'
else
  RUBY_19 = false
  require 'md5'
end

class NegativeCaptcha
  attr_accessor :fields
  attr_accessor :values
  attr_accessor :secret
  attr_accessor :spinner
  attr_accessor :message
  attr_accessor :timestamp
  attr_accessor :error

  def initialize(opts)
    @secret = opts[:secret]||(RUBY_19 ? Digest::MD5.hexdigest("this_is_a_secret_key") : MD5.hexdigest("this_is_a_secret_key"))
    @timestamp =  (opts.has_key?(:params) ? opts[:params][:timestamp] : nil) || Time.now.to_i
    spinner_text = ([@timestamp, @secret] + (opts[:spinner].is_a?(Array) ? opts[:spinner] : [opts[:spinner]]))*'-'
    @spinner = RUBY_19 ? Digest::MD5.hexdigest(spinner_text) : MD5.hexdigest(spinner_text)
    @message = opts[:message]|| I18n.t(:message, scope: [:negative_captcha, :errors])
    @fields = opts[:fields].inject({}){ |hash, field_name|
      hash[field_name] = \
      if RUBY_19
        Digest::MD5.hexdigest([field_name, @spinner, @secret]*'-')
      else
        MD5.hexdigest([field_name, @spinner, @secret]*'-')
      end

      hash
    }
    @values = {}
    @error = I18n.t(:no_params, scope: [:negative_captcha, :errors])
    process(opts[:params]) if opts[:params] && (opts[:params][:spinner]||opts[:params][:timestamp])
  end

  def [](name)
    @fields[name]
  end

  def valid?
    @error.nil? || @error == "" || @error.empty?
  end

  def assign_values(params)
    @fields.each do |name, encrypted_name|
      @values[name] = params[encrypted_name]
    end
  end

  def process(params)
    if params[:timestamp].nil? || (Time.now.to_i - params[:timestamp].to_i).abs > 86400
      @error = I18n.t(:invalid_timestamp, scope: [:negative_captcha, :errors])
    elsif params[:spinner] != @spinner
      @error = I18n.t(:invalid_spinner, scope: [:negative_captcha, :errors])
    elsif fields.keys.detect {|name| params[name] && params[name].length > 0}
      @error = I18n.t(:hidden_fields_submitted, scope: [:negative_captcha, :errors])
      false
    else
      @error = ""
      assign_values(params)
    end
  end
end

if !ActionView::Base.instance_methods.include? 'negative_captcha'
  require 'negative_captcha_view_helpers'
  ActionView::Base.class_eval { include NegativeCaptchaViewHelpers }
end
require "negative_captcha_form_builder"

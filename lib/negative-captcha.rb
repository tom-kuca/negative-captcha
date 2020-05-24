# frozen_string_literal: true

require 'i18n'
::I18n.load_path += Dir[File.expand_path('../config/locales/**/*.{rb,yml}', __dir__)]

require 'digest/md5'

class NegativeCaptcha
  attr_accessor :fields
  attr_accessor :values
  attr_accessor :secret
  attr_accessor :spinner
  attr_accessor :message
  attr_accessor :timestamp
  attr_accessor :error

  def initialize(opts)
    @secret = opts[:secret]
    @timestamp = (opts.key?(:params) ? opts[:params][:timestamp] : nil) || Time.now.to_i
    spinner_text = ([@timestamp, @secret] + (opts[:spinner].is_a?(Array) ? opts[:spinner] : [opts[:spinner]])) * '-'
    @spinner = Digest::MD5.hexdigest(spinner_text)
    @message = opts[:message] || I18n.t(:message, scope: [:negative_captcha, :errors])
    @fields = opts[:fields].each_with_object({})  do |field_name, hash|
      hash[field_name] = Digest::MD5.hexdigest([field_name, @spinner, @secret].join('-'))
    end
    @values = {}
    @error = I18n.t(:no_params, scope: [:negative_captcha, :errors])
    process(opts[:params]) if opts[:params] && (opts[:params][:spinner] || opts[:params][:timestamp])
  end

  def [](name)
    @fields[name]
  end

  def valid?
    @error.nil? || @error == '' || @error.empty?
  end

  def assign_values(params)
    @fields.each do |name, encrypted_name|
      @values[name] = params[encrypted_name]
    end
  end

  def process(params)
    if params[:timestamp].nil? || (Time.now.to_i - params[:timestamp].to_i).abs > 86_400
      @error = I18n.t(:invalid_timestamp, scope: [:negative_captcha, :errors])
    elsif params[:spinner] != @spinner
      @error = I18n.t(:invalid_spinner, scope: [:negative_captcha, :errors])
    elsif fields.keys.detect { |name| params[name] && !params[name].empty? }
      @error = I18n.t(:hidden_fields_submitted, scope: [:negative_captcha, :errors])
      false
    else
      @error = ''
      assign_values(params)
    end
  end
end

unless ActionView::Base.instance_methods.include? 'negative_captcha'
  require 'negative_captcha_view_helpers'
  ActionView::Base.class_eval { include NegativeCaptchaViewHelpers }
end
require 'negative_captcha_form_builder'

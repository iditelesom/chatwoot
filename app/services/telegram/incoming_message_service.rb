# Find the various telegram payload samples here: https://core.telegram.org/bots/webhooks#testing-your-bot-with-updates
# https://core.telegram.org/bots/api#available-types

module Faker
  class PhoneNumber
    def self.e164_phone_number(country_code: '+7')
      phone_number = Faker::PhoneNumber.phone_number
      national_number = phone_number.gsub(/\D/, '')
      "#{country_code}#{national_number}"
    end
  end
end

class Telegram::IncomingMessageService
  require 'digest/md5'

  include ::FileTypeHelper
  include ::Telegram::ParamHelpers
  pattr_initialize [:inbox!, :params!]

  def perform
    # chatwoot doesn't support group conversations at the moment
    return unless private_message?

    set_contact
    update_contact_avatar
    set_conversation
    @message = @conversation.messages.build(
      content: telegram_params_message_content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      content_attributes: telegram_params_content_attributes,
      source_id: telegram_params_message_id.to_s
    )

    process_message_attachments if message_params?
    @message.save!
  end

  private

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: telegram_params_from_id,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def process_message_attachments
    attach_location
    attach_files
    attach_contact
  end

  def update_contact_avatar
    # removed due to security reasons
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: conversation_additional_attributes
    }
  end

  def set_conversation
    @conversation = @contact_inbox.conversations.first
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def contact_attributes
    {
      name: anonymize_name,
      phone_number: anonymize_phone,
      email: anonymize_email,
      additional_attributes: additional_attributes
    }
  end

  def additional_attributes
    anonymized_username = anonymize_username

    secret = Rails.application.credentials.dig(:encryption, :deterministic_key)
    encryptor = DeterministicEncryptor.new(secret)

    {
      # TODO: Remove this once we show the social_telegram_user_name in the UI instead of the username
      username: anonymized_username,
      language_code: telegram_params_language_code,
      social_telegram_user_id: encryptor.encrypt(telegram_params_from_id.to_s),
      social_telegram_user_name: anonymized_username
    }
  end

  def anonymize_name
    Faker::Config.locale = 'ru'
    Faker::Config.random = Random.new(Digest::MD5.hexdigest(telegram_params_from_id.to_s).to_i(16))

    first_name = Faker::Name.male_first_name
    last_name = Faker::Name.male_last_name

    "#{first_name} #{last_name}"
  end

  def anonymize_username
    Faker::Config.locale = 'ru'
    Faker::Config.random = Random.new(Digest::MD5.hexdigest(telegram_params_from_id.to_s).to_i(16))

    Faker::Internet.username
  end

  def anonymize_email
    Faker::Config.locale = 'ru'
    Faker::Config.random = Random.new(Digest::MD5.hexdigest(telegram_params_from_id.to_s).to_i(16))

    Faker::Internet.email
  end

  def anonymize_phone
    Faker::Config.locale = 'ru'
    Faker::Config.random = Random.new(Digest::MD5.hexdigest(telegram_params_from_id.to_s).to_i(16))

    Faker::PhoneNumber.e164_phone_number
  end

  def conversation_additional_attributes
    secret = Rails.application.credentials.dig(:encryption, :deterministic_key)
    encryptor = DeterministicEncryptor.new(secret)

    {
      chat_id: encryptor.encrypt(telegram_params_chat_id.to_s)
    }
  end

  def file_content_type
    return :image if params[:message][:photo].present? || params.dig(:message, :sticker, :thumb).present?
    return :audio if params[:message][:voice].present? || params[:message][:audio].present?
    return :video if params[:message][:video].present?

    file_type(params[:message][:document][:mime_type])
  end

  def attach_files
    return unless file

    file_download_path = inbox.channel.get_telegram_file_path(file[:file_id])
    if file_download_path.blank?
      Rails.logger.info "Telegram file download path is blank for #{file[:file_id]} : inbox_id: #{inbox.id}"
      return
    end

    attachment_file = Down.download(
      inbox.channel.get_telegram_file_path(file[:file_id])
    )

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type,
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  end

  def attach_location
    return unless location

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: :location,
      fallback_title: location_fallback_title,
      coordinates_lat: location['latitude'],
      coordinates_long: location['longitude']
    )
  end

  def attach_contact
    return unless contact_card

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: :contact,
      fallback_title: contact_card['phone_number'].to_s,
      meta: {
        first_name: contact_card['first_name'],
        last_name: contact_card['last_name']
      }
    )
  end

  def file
    @file ||= visual_media_params || params[:message][:voice].presence || params[:message][:audio].presence || params[:message][:document].presence
  end

  def location_fallback_title
    return '' if venue.blank?

    venue[:title] || ''
  end

  def venue
    @venue ||= params.dig(:message, :venue).presence
  end

  def location
    @location ||= params.dig(:message, :location).presence
  end

  def contact_card
    @contact_card ||= params.dig(:message, :contact).presence
  end

  def visual_media_params
    params[:message][:photo].presence&.last || params.dig(:message, :sticker, :thumb).presence || params[:message][:video].presence
  end
end

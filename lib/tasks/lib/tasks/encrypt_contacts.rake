module Faker
  class PhoneNumber
    def self.e164_phone_number(country_code: '+7')
      phone_number = Faker::PhoneNumber.phone_number
      national_number = phone_number.gsub(/\D/, '')
      "#{country_code}#{national_number}"
    end
  end
end

namespace :populate do
  desc "Populate contacts and conversations with Faker data"
  task data: :environment do
    require 'digest/md5'
    require 'faker'

    encryptor = DeterministicEncryptor.new

    Contact.find_each do |contact|
      Faker::Config.locale = 'ru'
      Faker::Config.random = Random.new(Digest::MD5.hexdigest(contact.id.to_s).to_i(16))

      first_name = Faker::Name.male_first_name
      last_name = Faker::Name.male_last_name
      username = Faker::Internet.username
      email = Faker::Internet.email
      phone_number = Faker::PhoneNumber.e164_phone_number

      additional_attributes = contact.additional_attributes || {}
      additional_attributes['username'] = username
      additional_attributes['social_telegram_user_name'] = username

      if additional_attributes['social_telegram_user_id'].present?
        additional_attributes['social_telegram_user_id'] = encryptor.encrypt(additional_attributes['social_telegram_user_id'].to_s)
      end

      contact.update!(
        name: "#{first_name} #{last_name}",
      #  phone_number: phone_number,
      #  email: email,
        additional_attributes: additional_attributes
      )

      puts "Updated contact: #{contact.id}"
    end

    Conversation.find_each do |conversation|
      conversation_additional_attributes = conversation.additional_attributes || {}

      if conversation_additional_attributes['chat_id'].present?
        conversation_additional_attributes['chat_id'] = encryptor.encrypt(conversation_additional_attributes['chat_id'].to_s)
      end

      conversation.update!(
        additional_attributes: conversation_additional_attributes
      )

      puts "Updated conversation: #{conversation.id}"
    end

    puts "Contacts and conversations have been populated with Faker data and encrypted fields."
  end
end

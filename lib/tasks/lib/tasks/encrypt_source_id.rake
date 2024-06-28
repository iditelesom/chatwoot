namespace :encrypt do
  desc 'Encrypt existing source_id in contact_inboxes'
  task source_id: :environment do
    ContactInbox.find_each do |contact_inbox|
      plain_source_id = contact_inbox.read_attribute_before_type_cast('source_id')
      contact_inbox.update_column(:source_id, plain_source_id)

      puts "Encrypted ContactInbox ID: #{contact_inbox.id}"
    end
  end
end

namespace :avatars do
  desc 'Remove all avatars from contacts'
  task remove_all: :environment do
    processed_count = 0
    removed_count = 0

    puts 'Starting the process to remove all avatars from contacts...'

    Contact.find_each do |contact|
      processed_count += 1
      if contact.avatar.attached?
        contact.avatar.purge
        removed_count += 1
        puts "Removed avatar for Contact ID: #{contact.id}"
      end
    end

    puts "Total contacts processed: #{processed_count}"
    puts "Total avatars removed: #{removed_count}"
  end
end

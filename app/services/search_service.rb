class SearchService
  pattr_initialize [:current_user!, :current_account!, :params!, :search_type!]

  def perform
    case search_type
    when 'Message'
      { messages: filter_messages }
    when 'Conversation'
      { conversations: filter_conversations }
    when 'Contact'
      { contacts: filter_contacts }
    else
      { contacts: filter_contacts, messages: filter_messages, conversations: filter_conversations }
    end
  end

  private

  def accessable_inbox_ids
    @accessable_inbox_ids ||= @current_user.assigned_inboxes.pluck(:id)
  end

  def search_query
    @search_query ||= params[:q].to_s.strip
  end

  def filter_conversations
    @conversations = current_account.conversations
    # Apply TeamFilter first to ensure private team filtering is consistent
    @conversations = TeamFilter.new(@conversations, current_user).filter

    @conversations = @conversations.where(inbox_id: accessable_inbox_ids)
                                   .joins('INNER JOIN contacts ON conversations.contact_id = contacts.id')
                                   .where("cast(conversations.display_id as text) ILIKE :search OR contacts.name ILIKE :search OR contacts.email
                            ILIKE :search OR contacts.phone_number ILIKE :search OR contacts.identifier ILIKE :search", search: "%#{search_query}%")
                                   .order('conversations.created_at DESC')
                                   .page(params[:page])
                                   .per(15)
  end

  def filter_messages
    @messages = if use_gin_search
                  filter_messages_with_gin
                else
                  filter_messages_with_like
                end
  rescue StandardError => e
    Rails.logger.error("Error in filter_messages: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    []
  end

  def filter_messages_with_gin
    base_query = message_base_query
    # Filter messages based on conversation team access
    base_query = filter_messages_by_team(base_query)

    if search_query.present?
      # Use the @@ operator with to_tsquery for better GIN index utilization
      # Convert search query to tsquery format with prefix matching

      # Use this if we wanna match splitting the words
      # split_query = search_query.split.map { |term| "#{term} | #{term}:*" }.join(' & ')

      # This will do entire sentence matching using phrase distance operator
      tsquery = search_query.split.join(' <-> ')

      # Apply the text search using the GIN index
      base_query.where('content @@ to_tsquery(?)', tsquery)
                .reorder('messages.created_at DESC')
                .page(params[:page])
                .per(15)
    else
      base_query.reorder('messages.created_at DESC')
                .page(params[:page])
                .per(15)
    end
  end

  def filter_messages_with_like
    base_query = message_base_query
    # Filter messages based on conversation team access
    base_query = filter_messages_by_team(base_query)

    base_query.where('messages.content ILIKE :search', search: "%#{search_query}%")
              .reorder('messages.created_at DESC')
              .page(params[:page])
              .per(15)
  end

  def message_base_query
    current_account.messages.where(inbox_id: accessable_inbox_ids)
                   .where('messages.created_at >= ?', 3.months.ago)
  end

  def filter_messages_by_team(query)
    # Get conversations that user has access to based on team permissions
    accessible_conversations = TeamFilter.new(
      current_account.conversations,
      current_user
    ).filter

    # Only include messages from conversations user has access to
    query.joins(:conversation).where(conversation: accessible_conversations)
  end

  def use_gin_search
    current_account.feature_enabled?('search_with_gin')
  end

  def filter_contacts
    @contacts = current_account.contacts.where(
      "name ILIKE :search OR email ILIKE :search OR phone_number
      ILIKE :search OR identifier ILIKE :search", search: "%#{search_query}%"
    ).resolved_contacts.order_on_last_activity_at('desc').page(params[:page]).per(15)
  end
end

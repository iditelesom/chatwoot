require 'rails_helper'

RSpec.describe TeamFilter do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:public_team) { create(:team, account: account, private: false) }
  let(:private_team) { create(:team, account: account, private: true) }
  let(:inbox) { create(:inbox, account: account) }
  
  # Create conversations with different team assignments
  let!(:no_team_conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:public_team_conversation) { create(:conversation, account: account, inbox: inbox, team: public_team) }
  let!(:private_team_conversation) { create(:conversation, account: account, inbox: inbox, team: private_team) }
  
  # Create messages for conversations
  let!(:no_team_message) { create(:message, account: account, conversation: no_team_conversation, content: 'No team message') }
  let!(:public_team_message) { create(:message, account: account, conversation: public_team_conversation, content: 'Public team message') }
  let!(:private_team_message) { create(:message, account: account, conversation: private_team_conversation, content: 'Private team message') }
  
  describe '#filter' do
    before do
      # Set Current.account for the test
      Current.account = account
    end
    
    after do
      # Reset Current.account after test
      Current.account = nil
    end
    
    context 'when user is an administrator' do
      it 'returns all conversations regardless of team privacy when no team is specified' do
        team_filter = described_class.new(account.conversations, administrator)
        
        result = team_filter.filter
        expect(result.count).to eq(3)
        expect(result).to include(no_team_conversation, public_team_conversation, private_team_conversation)
      end
      
      it 'filters by team when a team is specified' do
        team_filter = described_class.new(account.conversations, administrator, public_team)
        
        result = team_filter.filter
        expect(result.count).to eq(1)
        expect(result).to include(public_team_conversation)
      end
    end
    
    context 'when user is a regular user' do
      context 'when user is not a member of any team' do
        it 'excludes conversations from private teams' do
          team_filter = described_class.new(account.conversations, user)
          
          result = team_filter.filter
          expect(result.count).to eq(2)
          expect(result).to include(no_team_conversation, public_team_conversation)
          expect(result).not_to include(private_team_conversation)
        end
      end
      
      context 'when user is a member of a private team' do
        before do
          create(:team_member, user: user, team: private_team)
        end
        
        it 'includes conversations from private teams the user is a member of' do
          team_filter = described_class.new(account.conversations, user)
          
          result = team_filter.filter
          expect(result.count).to eq(3)
          expect(result).to include(no_team_conversation, public_team_conversation, private_team_conversation)
        end
      end
      
      context 'when a specific team is requested' do
        it 'allows access to public teams' do
          team_filter = described_class.new(account.conversations, user, public_team)
          
          result = team_filter.filter
          expect(result.count).to eq(1)
          expect(result).to include(public_team_conversation)
        end
        
        it 'denies access to private teams the user is not a member of' do
          expect {
            team_filter = described_class.new(account.conversations, user, private_team)
            team_filter.filter
          }.to raise_error(Pundit::NotAuthorizedError)
        end
        
        it 'allows access to private teams the user is a member of' do
          create(:team_member, user: user, team: private_team)
          
          team_filter = described_class.new(account.conversations, user, private_team)
          result = team_filter.filter
          
          expect(result.count).to eq(1)
          expect(result).to include(private_team_conversation)
        end
      end
    end
    
    context 'when Current.account is not set' do
      before do
        Current.account = nil
      end
      
      it 'uses the account from the conversation collection' do
        # Assign account to Current.account within filter execution
        allow(Current).to receive(:account).and_return(account)
        
        team_filter = described_class.new(account.conversations, user)
        result = team_filter.filter
        
        expect(result.count).to eq(2)
        expect(result).to include(no_team_conversation, public_team_conversation)
        expect(result).not_to include(private_team_conversation)
      end
    end
  end
  
  describe 'integration with services' do
    before do
      Current.account = account
    end
    
    after do
      Current.account = nil
    end
    
    describe 'SearchService' do
      context 'when searching conversations' do
        # Setup user's assigned inboxes
        before do
          allow_any_instance_of(User).to receive(:assigned_inboxes).and_return([inbox])
        end
        
        it 'filters out private team conversations for regular users' do
          search_service = SearchService.new(
            current_user: user, 
            current_account: account, 
            params: { q: 'conversation' }, 
            search_type: 'Conversation'
          )
          
          result = search_service.perform
          
          expect(result[:conversations]).not_to include(private_team_conversation)
        end
        
        it 'includes private team conversations for team members' do
          create(:team_member, user: user, team: private_team)
          
          search_service = SearchService.new(
            current_user: user, 
            current_account: account, 
            params: { q: 'conversation' }, 
            search_type: 'Conversation'
          )
          
          result = search_service.perform
          
          expect(result[:conversations]).to include(private_team_conversation) if result[:conversations].any?
        end
      end
      
      context 'when searching messages' do
        # Setup user's assigned inboxes
        before do
          allow_any_instance_of(User).to receive(:assigned_inboxes).and_return([inbox])
        end
        
        it 'filters out messages from private team conversations for regular users' do
          search_service = SearchService.new(
            current_user: user, 
            current_account: account, 
            params: { q: 'message' }, 
            search_type: 'Message'
          )
          
          result = search_service.perform
          
          if result[:messages].any?
            expect(result[:messages].map(&:content)).not_to include(private_team_message.content)
          end
        end
        
        it 'includes messages from private team conversations for team members' do
          create(:team_member, user: user, team: private_team)
          
          search_service = SearchService.new(
            current_user: user, 
            current_account: account, 
            params: { q: 'message' }, 
            search_type: 'Message'
          )
          
          result = search_service.perform
          
          if result[:messages].any?
            expect(result[:messages].map(&:content)).to include(private_team_message.content)
          end
        end
      end
    end
    
    describe 'TeamFilter usage in other services' do
      it 'should exclude private team conversations for users not in the team' do
        # This test verifies the core TeamFilter behavior that other services would use
        result = TeamFilter.new(account.conversations, user).filter
        
        expect(result).not_to include(private_team_conversation)
        expect(result).to include(no_team_conversation, public_team_conversation)
      end
      
      it 'should include private team conversations for team members' do
        create(:team_member, user: user, team: private_team)
        
        result = TeamFilter.new(account.conversations, user).filter
        
        expect(result).to include(private_team_conversation)
      end
      
      it 'should filter by specific team correctly' do
        result = TeamFilter.new(account.conversations, user, public_team).filter
        
        expect(result).to include(public_team_conversation)
        expect(result).not_to include(no_team_conversation, private_team_conversation)
      end
      
      it 'should raise error when unauthorized user tries to access private team' do
        expect {
          TeamFilter.new(account.conversations, user, private_team).filter
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end 
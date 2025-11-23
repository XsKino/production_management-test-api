require 'rails_helper'

RSpec.describe OrderAssignment, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:production_order) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:production_order) { create(:normal_order) }
    
    before do
      create(:order_assignment, user: user, production_order: production_order)
    end

    it 'validates uniqueness of user_id scoped to production_order_id' do
      duplicate_assignment = build(:order_assignment, user: user, production_order: production_order)
      
      expect(duplicate_assignment).not_to be_valid
      expect(duplicate_assignment.errors[:user_id]).to include('User is already assigned to this order')
    end

    it 'allows same user to be assigned to different orders' do
      other_order = create(:normal_order)
      assignment = build(:order_assignment, user: user, production_order: other_order)
      
      expect(assignment).to be_valid
    end

    it 'allows different users to be assigned to same order' do
      other_user = create(:user, email: 'other@example.com')
      assignment = build(:order_assignment, user: other_user, production_order: production_order)
      
      expect(assignment).to be_valid
    end
  end
end
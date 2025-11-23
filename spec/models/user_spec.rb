require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:role) }
    it { should have_secure_password }
  end

  describe 'associations' do
    it { should have_many(:created_orders).class_name('ProductionOrder').with_foreign_key('creator_id').dependent(:destroy) }
    it { should have_many(:order_assignments).dependent(:destroy) }
    it { should have_many(:assigned_orders).through(:order_assignments).source(:production_order) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(operator: 0, production_manager: 1, admin: 2) }
  end

  describe 'role methods' do
    let(:admin) { create(:user, role: :admin) }
    let(:manager) { create(:user, role: :production_manager) }
    let(:operator) { create(:user, role: :operator) }

    it 'correctly identifies admin users' do
      expect(admin.admin?).to be true
      expect(manager.admin?).to be false
      expect(operator.admin?).to be false
    end

    it 'correctly identifies production manager users' do
      expect(admin.production_manager?).to be false
      expect(manager.production_manager?).to be true
      expect(operator.production_manager?).to be false
    end

    it 'correctly identifies operator users' do
      expect(admin.operator?).to be false
      expect(manager.operator?).to be false
      expect(operator.operator?).to be true
    end
  end
end
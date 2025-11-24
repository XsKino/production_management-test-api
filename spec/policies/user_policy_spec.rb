require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:admin) { create(:user, role: 'admin') }
  let(:production_manager) { create(:user, role: 'production_manager') }
  let(:operator) { create(:user, role: 'operator') }
  let(:other_user) { create(:user, role: 'operator') }

  describe 'Scope' do
    it 'allows everyone to see all users' do
      # Force lazy evaluation of all let variables
      admin; production_manager; operator; other_user
      create_list(:user, 5)
      admin_scope = Pundit.policy_scope(admin, User)
      manager_scope = Pundit.policy_scope(production_manager, User)
      operator_scope = Pundit.policy_scope(operator, User)

      expect(admin_scope.count).to eq(9) # 5 created + 4 let users
      expect(manager_scope.count).to eq(9)
      expect(operator_scope.count).to eq(9)
    end
  end

  describe '#index?' do
    subject { described_class.new(user, User) }

    context 'as admin' do
      let(:user) { admin }
      it { is_expected.to permit_action(:index) }
    end

    context 'as production_manager' do
      let(:user) { production_manager }
      it { is_expected.to permit_action(:index) }
    end

    context 'as operator' do
      let(:user) { operator }
      it { is_expected.to permit_action(:index) }
    end
  end

  describe '#show?' do
    subject { described_class.new(user, other_user) }

    context 'as admin' do
      let(:user) { admin }
      it { is_expected.to permit_action(:show) }
    end

    context 'as production_manager' do
      let(:user) { production_manager }
      it { is_expected.to permit_action(:show) }
    end

    context 'as operator' do
      let(:user) { operator }
      it { is_expected.to permit_action(:show) }
    end
  end

  describe '#create?' do
    subject { described_class.new(user, User.new) }

    context 'as admin' do
      let(:user) { admin }
      it { is_expected.to permit_action(:create) }
    end

    context 'as production_manager' do
      let(:user) { production_manager }
      it { is_expected.to forbid_action(:create) }
    end

    context 'as operator' do
      let(:user) { operator }
      it { is_expected.to forbid_action(:create) }
    end
  end

  describe '#update?' do
    context 'as admin updating any user' do
      subject { described_class.new(admin, other_user) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating their own profile' do
      subject { described_class.new(production_manager, production_manager) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating other users' do
      subject { described_class.new(production_manager, operator) }
      it { is_expected.to forbid_action(:update) }
    end

    context 'as operator updating their own profile' do
      subject { described_class.new(operator, operator) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as operator updating other users' do
      subject { described_class.new(operator, production_manager) }
      it { is_expected.to forbid_action(:update) }
    end
  end

  describe '#destroy?' do
    context 'as admin' do
      subject { described_class.new(admin, other_user) }
      it { is_expected.to permit_action(:destroy) }
    end

    context 'as production_manager' do
      subject { described_class.new(production_manager, other_user) }
      it { is_expected.to forbid_action(:destroy) }
    end

    context 'as operator' do
      subject { described_class.new(operator, other_user) }
      it { is_expected.to forbid_action(:destroy) }
    end
  end
end

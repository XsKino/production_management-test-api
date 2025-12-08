class Api::V1::UsersController < Api::V1::ApplicationController
  before_action :set_user, only: [:show, :update, :destroy]

  # GET /api/v1/users
  def index
    authorize User

    @users = policy_scope(User)

    # Apply basic filtering if needed
    @users = @users.where(role: params[:role]) if params[:role].present?
    @users = @users.where('name ILIKE ? OR email ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    # Apply pagination
    @users = paginate_collection(@users)

    render_success(
      serialize_users(@users),
      nil,
      :ok,
      pagination_meta(@users)
    )
  end

  # GET /api/v1/users/:id
  def show
    authorize @user

    render_success(serialize_user_detail(@user))
  end

  # POST /api/v1/users
  def create
    @user = User.new(user_params)
    authorize @user

    @user.save!

    render_success(
      serialize_user(@user),
      'User created successfully',
      :created
    )
  end

  # PATCH/PUT /api/v1/users/:id
  def update
    authorize @user

    # Users can update their own profile (limited fields), admins can update any user
    update_params = current_user.admin? ? user_params : user_self_update_params

    @user.update!(update_params)

    render_success(
      serialize_user(@user),
      'User updated successfully'
    )
  end

  # DELETE /api/v1/users/:id
  def destroy
    authorize @user

    # Prevent admin from deleting themselves
    if @user == current_user
      return render_error('You cannot delete your own account', :forbidden)
    end

    @user.destroy!

    render_success(nil, 'User deleted successfully')
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end

  def user_self_update_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def serialize_users(users)
    UserSerializer.new(users).serializable_hash[:data].map { |u| u[:attributes] }
  end

  def serialize_user(user)
    UserSerializer.new(user).serializable_hash[:data][:attributes]
  end

  def serialize_user_detail(user)
    serialized = UserSerializer.new(user).serializable_hash[:data][:attributes]
    serialized.merge({
      statistics: {
        created_orders_count: user.created_orders.count,
        assigned_orders_count: user.assigned_orders.count,
        pending_orders_count: user.assigned_orders.where(status: :pending).count,
        completed_orders_count: user.assigned_orders.where(status: :completed).count
      }
    })
  end
end
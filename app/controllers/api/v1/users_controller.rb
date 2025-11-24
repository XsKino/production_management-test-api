class Api::V1::UsersController < Api::V1::ApplicationController
  before_action :set_user, only: [:show, :update, :destroy]
  before_action :authorize_user_management, except: [:show]

  # GET /api/v1/users
  def index
    @users = User.all
    
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
    # Users can see their own profile, admins can see any profile
    unless @user == current_user || current_user.admin?
      return render_error('You are not authorized to view this user', :forbidden)
    end

    render_success(serialize_user_detail(@user))
  end

  # POST /api/v1/users
  def create
    @user = User.new(user_params)

    if @user.save
      render_success(
        serialize_user(@user),
        'User created successfully',
        :created
      )
    else
      render_error(
        'Failed to create user',
        :unprocessable_content,
        @user.errors.full_messages
      )
    end
  end

  # PATCH/PUT /api/v1/users/:id
  def update
    # Users can update their own profile (limited fields), admins can update any user
    update_params = current_user.admin? ? user_params : user_self_update_params

    if @user.update(update_params)
      render_success(
        serialize_user(@user),
        'User updated successfully'
      )
    else
      render_error(
        'Failed to update user',
        :unprocessable_content,
        @user.errors.full_messages
      )
    end
  end

  # DELETE /api/v1/users/:id
  def destroy
    # Prevent admin from deleting themselves
    if @user == current_user
      return render_error('You cannot delete your own account', :forbidden)
    end

    if @user.destroy
      render_success(nil, 'User deleted successfully')
    else
      render_error('Failed to delete user')
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_user_management
    unless current_user.admin?
      render_error('Only administrators can manage users', :forbidden)
    end
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end

  def user_self_update_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def serialize_users(users)
    users.map { |user| serialize_user(user) }
  end

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def serialize_user_detail(user)
    serialize_user(user).merge({
      statistics: {
        created_orders_count: user.created_orders.count,
        assigned_orders_count: user.assigned_orders.count,
        pending_orders_count: user.assigned_orders.where(status: :pending).count,
        completed_orders_count: user.assigned_orders.where(status: :completed).count
      }
    })
  end
end
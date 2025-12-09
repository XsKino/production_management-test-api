class Api::V1::UsersController < Api::V1::ApplicationController
  before_action :set_user, only: [:show, :update, :destroy]

  # This callback uses the generic authorize_resource from ApplicationController
  before_action :authorize_resource, except: [:create]

  # GET /api/v1/users
  def index
    @users = policy_scope(User)

    # Apply basic filtering if needed
    @users = @users.where(role: params[:role]) if params[:role].present?
    @users = @users.where('name ILIKE ? OR email ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    # Apply pagination
    @users = paginate_collection(@users)

    render_success(
      serialize(@users),
      nil,
      :ok,
      pagination_meta(@users)
    )
  end

  # GET /api/v1/users/:id
  def show
    serialized = serialize(@user)
    statistics = {
      created_orders_count: @user.created_orders.count,
      assigned_orders_count: @user.assigned_orders.count,
      pending_orders_count: @user.assigned_orders.where(status: :pending).count,
      completed_orders_count: @user.assigned_orders.where(status: :completed).count
    }
    render_success(serialized.merge(statistics: statistics))
  end

  # POST /api/v1/users
  def create
    # Build temporary user to get permitted attributes
    temp_user = User.new
    permitted_attrs = policy(temp_user).permitted_attributes_for_create

    @user = User.new(params.require(:user).permit(permitted_attrs))
    # Manual authorization: need to authorize the instance with user-provided data before saving
    authorize @user

    @user.save!

    render_success(
      serialize(@user),
      'User created successfully',
      :created
    )
  end

  # PATCH/PUT /api/v1/users/:id
  def update
    # Policy determines permitted attributes based on admin status
    permitted_attrs = policy(@user).permitted_attributes_for_update
    @user.update!(params.require(:user).permit(permitted_attrs))

    render_success(
      serialize(@user),
      'User updated successfully'
    )
  end

  # DELETE /api/v1/users/:id
  def destroy
    # Prevent admin from deleting themselves
    if @user == current_user
      return render_error('You cannot delete your own account', :forbidden)
    end

    @user.destroy!

    render_success(nil, 'User deleted successfully')
  end

  private

  def set_user
    # Clean: only fetches the record
    @user = User.find(params[:id])
  end
end
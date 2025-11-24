class Api::V1::AuthenticationController < ActionController::API
  include Api::ErrorHandling
  include Api::ResponseHelpers

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id)

      render_success(
        {
          token: token,
          user: serialize_user(user)
        },
        'Login successful'
      )
    else
      render_error(
        'Invalid email or password',
        :unauthorized,
        nil,
        'INVALID_CREDENTIALS'
      )
    end
  end

  # POST /api/v1/auth/logout
  def logout
    render_success(nil, 'Logged out successfully')
  end

  # POST /api/v1/auth/refresh
  def refresh
    token = request.headers['Authorization']&.split(' ')&.last
    decoded = JsonWebToken.decode(token)

    if decoded
      user = User.find_by(id: decoded[:user_id])

      if user
        new_token = JsonWebToken.encode(user_id: user.id)

        render_success(
          {
            token: new_token,
            user: serialize_user(user)
          },
          'Token refreshed successfully'
        )
      else
        render_error(
          'User not found',
          :not_found,
          nil,
          'USER_NOT_FOUND'
        )
      end
    else
      render_error(
        'Invalid or expired token',
        :unauthorized,
        nil,
        'INVALID_TOKEN'
      )
    end
  end

  private

  def serialize_user(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role
    }
  end
end

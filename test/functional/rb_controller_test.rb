require 'test_helper'

class RbControllerTest < ActionController::TestCase
  test "should get search_googlex" do
    get :search_googlex
    assert_response :success
  end

end

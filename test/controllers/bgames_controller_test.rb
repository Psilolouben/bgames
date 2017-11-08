require 'test_helper'

class BgamesControllerTest < ActionController::TestCase
  setup do
    @bgame = bgames(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:bgames)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create bgame" do
    assert_difference('Bgame.count') do
      post :create, bgame: { bgg_id: @bgame.bgg_id, name: @bgame.name }
    end

    assert_redirected_to bgame_path(assigns(:bgame))
  end

  test "should show bgame" do
    get :show, id: @bgame
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @bgame
    assert_response :success
  end

  test "should update bgame" do
    patch :update, id: @bgame, bgame: { bgg_id: @bgame.bgg_id, name: @bgame.name }
    assert_redirected_to bgame_path(assigns(:bgame))
  end

  test "should destroy bgame" do
    assert_difference('Bgame.count', -1) do
      delete :destroy, id: @bgame
    end

    assert_redirected_to bgames_path
  end
end

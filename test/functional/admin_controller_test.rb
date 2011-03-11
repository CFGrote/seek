require 'test_helper'

class AdminControllerTest < ActionController::TestCase

  fixtures :all

  include AuthenticatedTestHelper
  test "should show rebrand" do
    login_as(:quentin)
    get :rebrand
    assert_response :success
  end

  test "only admin can restart the server" do
    login_as(:aaron)
    post :restart_server
    assert_not_nil flash[:error]
  end

  test "should show features enabled" do
    login_as(:quentin)
    get :features_enabled
    assert_response :success
  end

  test "should show pagination" do
    login_as(:quentin)
    get :pagination
    assert_response :success
  end

  test "should show others" do
    login_as(:quentin)
    get :others
    assert_response :success
  end

  test "visible to admin" do
    login_as(:quentin)
    get :show
    assert_response :success
    assert_nil flash[:error]
  end

  test "invisible to non admin" do
    login_as(:aaron)
    get :show
    assert_response :redirect
    assert_not_nil flash[:error]
  end
#
#  test "show graphs" do
#
#    login_as(:quentin)
#    get :graphs
#    assert_response :success
#
#  end

  test "editing tags visible to admin" do
    login_as(:quentin)
    get :tags
    assert_response :success

    get :edit_tag, :id=>tags(:fishing)
    assert_response :success
  end

  test "editing tags blocked for non admin" do
    login_as(:aaron)
    get :tags
    assert_redirected_to :root
    assert_not_nil flash[:error]


    get :edit_tag, :id=>tags(:fishing)
    assert_redirected_to :root
    assert_not_nil flash[:error]


    fishing_tag=tags(:fishing)
    post :edit_tag, :id=>fishing_tag, :tags_autocompleter_unrecognized_items=>"microbiology, spanish"
    assert_redirected_to :root
    assert_not_nil flash[:error]

    post :delete_tag, :id=>fishing_tag
    assert_redirected_to :root
    assert_not_nil flash[:error]

  end

  test "edit tag to multiple" do
    login_as(:quentin)
    person=people(:random_userless_person)
    person.tool_list="linux, ruby, fishing"
    person.expertise_list="fishing"
    person.save!

    updated_at=person.updated_at

    assert_equal ["linux", "ruby", "fishing"], person.tool_list
    assert_equal ["fishing"], person.expertise_list

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    sleep(2) #for timestamp test

    golf_tag_id=tags(:golf).id
    post :edit_tag, :id=>fishing_tag, :tags_autocompleter_selected_ids=>[golf_tag_id], :tags_autocompleter_unrecognized_items=>"microbiology, spanish"
    assert_redirected_to :action=>:tags
    assert_nil flash[:error]

    person=Person.find(person.id)
    expected_tools=["golf", "linux", "ruby", "microbiology", "spanish"]
    expected_expertise=["golf", "microbiology", "spanish"]

    assert_equal expected_tools.size, person.tool_list.size
    assert_equal expected_expertise.size, person.expertise_list.size

    assert_equal updated_at.to_s,person.updated_at.to_s,"timestamps were modified for taggable and shouldn't have been"

    person.tool_list.each do |tool_tag|
      assert expected_tools.include?(tool_tag)
    end
    person.expertise_list.each do |expertise_tag|
      assert expected_expertise.include?(expertise_tag)
    end

  end

  test "edit tag includes orginal" do
    login_as(:quentin)
    person=people(:random_userless_person)
    person.tool_list="linux, ruby, fishing"
    person.expertise_list="fishing"
    person.save!

    assert_equal ["linux", "ruby", "fishing"], person.tool_list
    assert_equal ["fishing"], person.expertise_list

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    golf_tag_id=tags(:golf).id
    post :edit_tag, :id=>fishing_tag, :tags_autocompleter_selected_ids=>[golf_tag_id], :tags_autocompleter_unrecognized_items=>"fishing, spanish"
    assert_redirected_to :action=>:tags
    assert_nil flash[:error]

    person=Person.find(person.id)
    expected_tools=["golf", "linux", "ruby", "fishing","spanish"]
    expected_expertise=["golf", "fishing", "spanish"]

    assert_equal expected_tools.size, person.tool_list.size
    assert_equal expected_expertise.size, person.expertise_list.size

    person.tool_list.each do |tool_tag|
      assert expected_tools.include?(tool_tag)
    end
    person.expertise_list.each do |expertise_tag|
      assert expected_expertise.include?(expertise_tag)
    end

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert Person.tagged_with("fishing").include?(person)
  end

  test "edit tag to new tag" do
    login_as(:quentin)
    person=people(:random_userless_person)
    person.tool_list="linux, ruby, fishing"
    person.expertise_list="fishing"
    person.save!

    assert_equal ["linux", "ruby", "fishing"], person.tool_list
    assert_equal ["fishing"], person.expertise_list

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    golf_tag_id=tags(:golf).id

    assert_nil ActsAsTaggableOn::Tag.find_by_name("sparrow") #check tag doesn't already exist

    post :edit_tag, :id=>fishing_tag, :tags_autocompleter_selected_ids=>[], :tags_autocompleter_unrecognized_items=>"sparrow"
    assert_redirected_to :action=>:tags
    assert_nil flash[:error]

    person=Person.find(person.id)
    expected_tools=["linux", "ruby", "sparrow"]
    expected_expertise=["sparrow"]

    assert_equal expected_tools.size, person.tool_list.size
    assert_equal expected_expertise.size, person.expertise_list.size

    person.tool_list.each do |tool_tag|
      assert expected_tools.include?(tool_tag)
    end
    person.expertise_list.each do |expertise_tag|
      assert expected_expertise.include?(expertise_tag)
    end

  end

  test "edit tag to blank" do
    login_as(:quentin)
    person=people(:random_userless_person)
    person.tool_list="linux, ruby, fishing"
    person.expertise_list="fishing"
    person.save!

    assert_equal ["linux", "ruby", "fishing"], person.tool_list
    assert_equal ["fishing"], person.expertise_list

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    post :edit_tag, :id=>fishing_tag, :tags_autocompleter_selected_ids=>[], :tags_autocompleter_unrecognized_items=>""
    assert_redirected_to :action=>:tags
    assert_nil flash[:error]

    person=Person.find(person.id)
    expected_tools=["linux", "ruby"]
    expected_expertise=[]

    assert_equal expected_tools.size, person.tool_list.size
    assert_equal expected_expertise.size, person.expertise_list.size

    person.tool_list.each do |tool_tag|
      assert expected_tools.include?(tool_tag)
    end
    person.expertise_list.each do |expertise_tag|
      assert expected_expertise.include?(expertise_tag)
    end

  end

  test "edit tag to existing tag" do
    login_as(:quentin)
    person=people(:random_userless_person)
    person.tool_list="linux, ruby, fishing"
    person.expertise_list="fishing"
    person.save!

    assert_equal ["linux", "ruby", "fishing"], person.tool_list
    assert_equal ["fishing"], person.expertise_list

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    golf_tag_id=tags(:golf).id
    post :edit_tag, :id=>fishing_tag, :tags_autocompleter_selected_ids=>[golf_tag_id], :tags_autocompleter_unrecognized_items=>""
    assert_redirected_to :action=>:tags
    assert_nil flash[:error]

    person=Person.find(person.id)
    expected_tools=["linux", "ruby", "golf"]
    expected_expertise=["golf"]

    assert_equal expected_tools.size, person.tool_list.size
    assert_equal expected_expertise.size, person.expertise_list.size

    person.tool_list.each do |tool_tag|
      assert expected_tools.include?(tool_tag)
    end
    person.expertise_list.each do |expertise_tag|
      assert expected_expertise.include?(expertise_tag)
    end

  end

  test "delete_tag" do
    login_as(:quentin)

    person=people(:random_userless_person)
    person.tool_list="fishing"
    person.expertise_list="fishing"
    person.save!

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    #must be a post
    get :delete_tag, :id=>fishing_tag
    assert_redirected_to :action=>:tags
    assert_not_nil flash[:error]

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_not_nil fishing_tag

    post :delete_tag, :id=>fishing_tag
    assert_redirected_to :action=>:tags
    assert_nil flash[:error]

    fishing_tag=ActsAsTaggableOn::Tag.find(:first, :conditions=>{:name=>"fishing"})
    assert_nil fishing_tag

    person=Person.find(person.id)
    assert_equal [], person.tool_list
    assert_equal [], person.expertise_list

  end

  test "update admins" do
    login_as(:quentin)
    quentin=people(:quentin_person)
    aaron=people(:aaron_person)
    
    assert quentin.is_admin?
    assert !aaron.is_admin?

    post :update_admins,:admins=>[aaron.id]

    quentin.reload
    aaron.reload

    assert !quentin.is_admin?
    assert aaron.is_admin?
    
  end

end

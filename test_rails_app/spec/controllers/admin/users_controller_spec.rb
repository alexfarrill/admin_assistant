require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Admin::UsersController do
  integrate_views
  
  before :all do
    @user = User.find_or_create_by_username 'betty'
    @user.update_attribute :password, 'crocker'
  end

  describe '#create' do
    before :each do
      post :create, :user => { :username => 'bill', :password => '' }
    end
    
    it 'should assign a new random password' do
      user = User.find_by_username 'bill'
      user.should_not be_nil
      user.password.should_not == ''
    end
  end
  
  describe '#create with the same username' do
    before :each do
      @user_count = User.count
      post :create, :user => {:username => 'betty', :password => ''}
    end
    
    it 'should not save a new user' do
      User.count.should == @user_count
    end
    
    it 'should not call after_save' do
      response.should be_success
    end
  end
  
  describe '#destroy' do
    before :each do
      post :destroy, :id => @user.id
    end
    
    it 'should destroy the user' do
      User.find_by_id(@user.id).should be_nil
    end
  end
  
  describe '#edit' do
    before :all do
      @user.update_attributes(
        :has_avatar => true, :avatar_version => 9,
        :force_blog_posts_to_textile => true
      )
    end
    
    before :each do
      get :edit, :id => @user.id
    end
    
    it 'should show the default text input for password' do
      response.body.should match(%r|<input[^>]*name="user\[password\]"|)
    end
    
    it 'should show a reset password checkbox' do
      response.should have_tag("input[type=checkbox][name=reset_password]")
    end
    
    it "should have a multipart form" do
      response.should have_tag('form[enctype=multipart/form-data]')
    end
    
    it 'should have a file input for tmp_avatar' do
      response.should have_tag(
        'input[name=?][type=file]', 'user[tmp_avatar]'
      )
    end
    
    it 'should show the current tmp_avatar with a custom src' do
      response.should have_tag(
        "img[src^=?]", "http://my-image-server.com/users/#{@user.id}.jpg?v=9"
      )
    end
    
    it 'should have a remove-image option' do
      response.should have_tag(
        "input[type=checkbox][name=?]", 'user[tmp_avatar(destroy)]'
      )
    end
    
    it 'should show a drop-down for force_blog_posts_to_textile' do
      response.should have_tag('select[name=?]', 'user[force_blog_posts_to_textile]') do
        with_tag "option:not([selected])[value='']"
        with_tag "option:not([selected])[value=0]", :text => 'false'
        with_tag "option[selected=selected][value=1]", :text => 'true'
      end
    end
  end
  
  describe '#index' do
    before :each do
      get :index
    end
    
    it 'should show a Delete link and a link to the profile page' do
      response.should have_tag('td') do
        with_tag("a[href=#][onclick*='new Ajax.Request']", :text => 'Delete')
        with_tag(
          "a[href=?]",
          "/admin/blog_posts/new?blog_post%5Buser_id%5D=#{@user.id}",
          :text => "New blog post"
        )
      end
    end
  end
  
  describe '#new' do
    before :each do
      get :new
    end
    
    it 'should not show an input for password' do
      response.body.should match(/autogenerated/)
      response.body.should_not match(%r|<input[^>]*name="user\[password\]"|)
    end
    
    it 'should not show a reset password checkbox' do
      response.should_not have_tag("input[type=checkbox][name=reset_password]")
    end
    
    it 'should use date dropdowns with nil defaults for birthday' do
      nums_and_dt_fields = {1 => :year, 2 => :month, 3 => :day}
      nums_and_dt_fields.each do |num, dt_field|
        name = "user[birthday(#{num}i)]"
        response.should have_tag('select[name=?]', name) do
          with_tag "option[value='']"
          with_tag(
            "option:not([selected])[value=?]", Time.now.send(dt_field).to_s
          )
        end
      end
    end
    
    it 'should not try to set an hour or minute for birthday' do
      nums_and_dt_fields = {4 => :hour, 5 => :min}
      nums_and_dt_fields.each do |num, dt_field|
        name = "blog_post[published_at(#{num}i)]"
        response.should_not have_tag('select[name=?]', name)
      end
    end
    
    it 'should respect start_year and end_year parameters' do
      response.should have_tag("select[name='user[birthday(1i)]']") do
        (Time.now.year-100).upto(Time.now.year) do |year|
          with_tag "option[value='#{year}']"
        end
      end
    end
    
    it 'should show a drop-down for US states' do
      response.should have_tag('select[name=?]', 'user[state]') do
        with_tag "option[value='']"
        with_tag "option:not([selected])[value=AK]", :text => 'Alaska'
        with_tag "option:not([selected])[value=NY]", :text => 'New York'
        # blank option, 50 states, DC, Puerto Rico == 53 options
        with_tag "option", :count => 53
      end
    end
    
    it "should have a multipart form" do
      response.should have_tag('form[enctype=multipart/form-data]')
    end
    
    it 'should have a file input for tmp_avatar' do
      response.body.should match(
        %r|<input[^>]*name="user\[tmp_avatar\]"[^>]*type="file"|
      )
    end
    
    it 'should show a drop-down for force_blog_posts_to_textile' do
      response.should have_tag('select[name=?]', 'user[force_blog_posts_to_textile]') do
        with_tag "option[value='']"
        with_tag "option:not([selected])[value=0]", :text => 'false'
        with_tag "option:not([selected])[value=1]", :text => 'true'
      end
    end
  end
  
  describe '#update' do
    before :each do
      post :update, :id => @user.id, :user => {:username => 'bettie'}
    end
    
    it 'should not assign a new random password' do
      @user.reload
      @user.password.should == 'crocker'
    end
  end
  
  describe '#update while resetting password' do
    before :each do
      post(
        :update, :id => @user.id, :user => {:username => 'bettie'}, 
        :reset_password => '1'
      )
    end
    
    it 'should assign a new random password' do
      @user.reload
      @user.password.should_not == 'crocker'
    end
  end
  
  describe '#update while updating the current tmp_avatar' do
    before :all do
      @user.update_attributes :has_avatar => true, :avatar_version => 9
    end
    
    before :each do
      file = File.new './spec/data/tweenbot.jpg'
      post :update, :id => @user.id, :user => {:tmp_avatar => file}
    end
    
    it 'should increment the avatar_version through before_save' do
      @user.reload
      @user.avatar_version.should == 10
    end
  end
  
  describe '#update while removing the current tmp_avatar' do
    before :all do
      @user.update_attributes :has_avatar => true, :avatar_version => 9
    end
    
    before :each do
      post(
        :update,
        :id => @user.id,
        :user => {:tmp_avatar => '', 'tmp_avatar(destroy)' => '1' }
      )
    end
      
    it 'should set has_avatar to false' do
      @user.reload
      @user.has_avatar?.should be_false
    end
  end
  
  describe 'while trying to update and remove tmp_avatar at the same time' do
    before :all do
      @user.update_attributes :has_avatar => true, :avatar_version => 9
    end
    
    before :each do
      file = File.new './spec/data/tweenbot.jpg'
      post(
        :update,
        :id => @user.id,
        :user => {:tmp_avatar => file, 'tmp_avatar(destroy)' => '1'}
      )
    end

    it 'should assume you meant to update' do
      @user.reload
      @user.avatar_version.should == 10
      @user.has_avatar?.should be_true
    end
  end
end

# encoding: utf-8

require_relative '../../../spec_helper_min'
require 'support/helpers'
require_relative '../../../../app/controllers/carto/api/users_controller'

describe Carto::Api::UsersController do
  include_context 'organization with users helper'
  include Warden::Test::Helpers
  include HelperMethods

  before(:all) do
    @headers = { 'CONTENT_TYPE' => 'application/json' }
  end

  describe 'me' do
    it 'returns a hash with current user info' do
      user = @organization.owner
      carto_user = Carto::User.where(id: user.id).first

      get_json api_v3_users_me_url(user_domain: user.username, api_key: user.api_key), @headers do |response|
        expect(response.status).to eq(200)

        expect(response.body[:default_fallback_basemap].with_indifferent_access).to eq(user.default_basemap)

        dashboard_notifications = carto_user.notifications_for_category(:dashboard)
        expect(response.body[:dashboard_notifications]).to eq(dashboard_notifications)
      end
    end

    it 'returns 401 if user is not logged in' do
      get_json api_v3_users_me_url, @headers do |response|
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'update_me' do
    context 'account updates' do
      before(:each) do
        @user = FactoryGirl.create(:user, password: 'foobarbaz', password_confirmation: 'foobarbaz')
      end

      after(:each) do
        @user.destroy
      end

      let(:url_options) do
        {
          user_domain: @user.username,
          user_id: @user.id,
          api_key: @user.api_key
        }
      end

      it 'updates account data for the given user' do
        payload = {
          user: {
            email: 'foo@bar.baz',
            old_password: 'foobarbaz',
            new_password: 'bazbarfoo',
            confirm_password: 'bazbarfoo'
          }
        }

        put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
          expect(response.status).to eq(200)

          @user.refresh
          expect(@user.email).to eq('foo@bar.baz')
        end
      end

      it 'gives an error if email is invalid' do
        payload = { user: { email: 'foo@' } }

        put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
          expect(response.status).to eq(400)
          expect(response.body[:message]).to eq("Error updating your account details")
          expect(response.body[:errors]).to have_key(:email)
        end
      end

      it 'gives an error if old password is invalid' do
        payload = { user: { old_password: 'idontknow', new_password: 'barbaz', confirm_password: 'barbaz' } }

        put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
          expect(response.status).to eq(400)
          expect(response.body[:message]).to eq("Error updating your account details")
          expect(response.body[:errors]).to have_key(:old_password)
        end
      end

      it 'gives an error if new password and confirmation are not the same' do
        payload = { user: { old_password: 'foobarbaz', new_password: 'foofoo', confirm_password: 'barbar' } }

        put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
          expect(response.status).to eq(400)
          expect(response.body[:message]).to eq("Error updating your account details")
          expect(response.body[:errors]).to have_key(:new_password)
        end
      end

      it 'returns 401 if user is not logged in' do
        put_json api_v3_users_update_me_url(url_options.except(:api_key)), @headers do |response|
          expect(response.status).to eq(401)
        end
      end
    end

    context 'profile updates' do
      before(:each) do
        @user = FactoryGirl.create(:user)
      end

      after(:each) do
        @user.destroy
      end

      let(:url_options) do
        {
          user_domain: @user.username,
          user_id: @user.id,
          api_key: @user.api_key
        }
      end

      it 'updates profile data for the given user' do
        payload = {
          user: {
            name: 'Foo',
            last_name: 'Bar',
            website: 'https://carto.rocks',
            description: 'Foo Bar Baz',
            location: 'Anywhere',
            twitter_username: 'carto',
            disqus_shortname: 'carto'
          }
        }

        put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
          expect(response.status).to eq(200)

          @user.refresh
          expect(@user.name).to eq('Foo')
          expect(@user.last_name).to eq('Bar')
          expect(@user.website).to eq('https://carto.rocks')
          expect(@user.description).to eq('Foo Bar Baz')
          expect(@user.location).to eq('Anywhere')
          expect(@user.twitter_username).to eq('carto')
          expect(@user.disqus_shortname).to eq('carto')
        end
      end

      it 'does not update fields not present in the user hash' do
        payload = {
          user: {
            name: 'Foo',
            last_name: 'Bar',
            website: 'https://carto.rocks'
          }
        }
        old_description = @user.description
        old_location = @user.location
        old_twitter_username = @user.twitter_username

        put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
          expect(response.status).to eq(200)

          @user.refresh
          expect(@user.name).to eq('Foo')
          expect(@user.last_name).to eq('Bar')
          expect(@user.website).to eq('https://carto.rocks')
          expect(@user.description).to eq(old_description)
          expect(@user.location).to eq(old_location)
          expect(@user.twitter_username).to eq(old_twitter_username)
        end
      end

      it 'sets field to nil if key is present in the hash with a nil value' do
        fields_to_check = [
          :name, :last_name, :website, :description, :location, :twitter_username,
          :disqus_shortname, :available_for_hire
        ]

        fields_to_check.each do |field|
          payload = { user: { field => nil } }
          put_json api_v3_users_update_me_url(url_options), payload, @headers do |response|
            expect(response.status).to eq(200)
            @user.refresh
            expect(@user.values[field]).to be_nil
          end
        end
      end

      it 'returns 401 if user is not logged in' do
        payload = { user: { name: 'Foo' } }

        put_json api_v3_users_update_me_url(url_options.except(:api_key)), payload, @headers do |response|
          expect(response.status).to eq(401)
        end
      end
    end
  end
end

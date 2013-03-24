require 'spec_helper'

class User
  extend ActiveModel::Naming

  attr_accessor :name, :widgets_attributes

  def to_key
    [1]
  end
end

class Widget
  extend ActiveModel::Naming

  attr_accessor :name

  def persisted?
    false
  end
end

describe SignedForm::FormBuilder do
  include SignedFormViewHelper

  before { SignedForm::HMAC.secret_key = "abc123" }
  after  { SignedForm::HMAC.secret_key = nil }

  let(:user) { User.new }
  let(:widget) { Widget.new }

  describe "signed_form_for" do
    it "should build a form with signature" do
      content = signed_form_for(User.new) do |f|
        f.text_field :name
      end

      regex = '<form.*>.*<input type="hidden" name="form_signature" ' \
              'value="BAh7BkkiCXVzZXIGOgZFRlsGOgluYW1l--e8f61481cb89382653c1f9de617e9a47e22c7da5".*/>.*' \
              '<input.*name="user\[name\]".*/>.*' \
              '</form>'

      content.should =~ Regexp.new(regex, Regexp::MULTILINE)
    end
  end

  describe "add_signed_fields" do
    it "should add fields to the marshaled data" do
      content = signed_form_for(User.new) do |f|
        f.add_signed_fields :name, :address
      end

      data = get_data_from_form(content)
      data['user'].should include(:name, :address)
      data['user'].size.should == 2
    end
  end

  describe "fields_for" do
    it "should nest attributes" do
      user.stub(widgets: [widget])

      content = signed_form_for(user) do |f|
        f.fields_for :widgets do |ff|
          ff.text_field :name
        end
      end

      data = get_data_from_form(content)
      data['user'].should include("widgets_attributes" => [:name])
    end

    it "should deeply nest attributes" do
      content = signed_form_for(:author, url: '/') do |f|
        f.fields_for :books do |ff|
          ff.text_field :name
          ff.check_box :hardcover
          ff.fields_for :pages do |fff|
            fff.text_field :number
          end
        end
      end

      data = get_data_from_form(content)

      data.should include(:author)
      data[:author].first.should include(:books)
      data[:author].first[:books].should include(:name, :hardcover, { pages: [:number] })
    end

    specify "nested arrays should not have duplicates" do
      content = signed_form_for(:author, url: '/') do |f|
        f.fields_for :books do |ff|
          ff.text_field :name
          ff.text_field :name
        end
      end

      data = get_data_from_form(content)
      data[:author].first[:books].size.should == 1
    end

    specify "attribute arrays should not have duplicates" do
      content = signed_form_for(:author, url: '/') do |f|
        f.text_field :name
        f.text_field :name
      end

      data = get_data_from_form(content)
      data[:author].size.should == 1
    end
  end
end

